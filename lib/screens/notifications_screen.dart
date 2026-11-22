import 'package:flutter/material.dart';

import '../api.dart';
import '../push.dart';
import '../util.dart';
import '../widgets.dart';

class _AlertType {
  final String type;
  final String title;
  final String description;
  final IconData icon;
  const _AlertType(this.type, this.title, this.description, this.icon);
}

const List<_AlertType> _kTypes = [
  _AlertType('alarm', 'Alarmas', 'Grúa o remolque, choque, corte de energía, SOS',
      Icons.warning_amber_rounded),
  _AlertType('ignitionOn', 'Motor encendido', 'Cuando alguien enciende el vehículo',
      Icons.key),
  _AlertType('ignitionOff', 'Motor apagado', 'Cuando se apaga el vehículo', Icons.key_off),
  _AlertType('deviceOverspeed', 'Exceso de velocidad',
      'Al superar el límite configurado para el vehículo', Icons.speed),
  _AlertType('geofenceEnter', 'Entrada a una zona', 'Al entrar a una de tus zonas',
      Icons.login),
  _AlertType('geofenceExit', 'Salida de una zona', 'Al salir de una de tus zonas',
      Icons.logout),
  _AlertType('deviceMoving', 'Inicio de movimiento', 'Cuando el vehículo empieza a moverse',
      Icons.directions_car),
  _AlertType('deviceStopped', 'Vehículo detenido', 'Cuando el vehículo se detiene',
      Icons.local_parking),
  _AlertType('deviceOffline', 'Equipo desconectado',
      'Cuando el GPS deja de comunicarse', Icons.cloud_off_outlined),
  _AlertType('deviceOnline', 'Equipo conectado', 'Cuando el GPS vuelve a comunicarse',
      Icons.cloud_done_outlined),
  _AlertType('commandResult', 'Respuesta a comandos',
      'Confirmación del corte o reactivación del motor', Icons.settings_remote),
];

/// Elegir qué alertas llegan al celular.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  final Map<String, int> _active = {}; // tipo -> id de la notificación
  final Set<String> _busy = {};
  bool _permission = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await api.notifications();
      _active.clear();
      for (final n in list) {
        final type = (n['type'] ?? '').toString();
        final notifs = (n['notificators'] ?? '').toString();
        if (notifs.contains('firebase')) _active[type] = (n['id'] as num).toInt();
      }
      _permission = await Push.permissionGranted();
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(String type, bool on) async {
    setState(() => _busy.add(type));
    try {
      if (on) {
        await api.createNotification(type);
      } else {
        final id = _active[type];
        if (id != null) await api.deleteNotification(id);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(type));
    }
  }

  Future<void> _activatePhone() async {
    setState(() => _registering = true);
    final ok = await Push.register();
    _permission = await Push.permissionGranted();
    if (!mounted) return;
    setState(() => _registering = false);
    showMessage(
        context,
        ok
            ? 'Este celular quedó listo para recibir alertas.'
            : 'No se pudo activar. Revisa que la app tenga permiso de notificaciones en Ajustes.');
  }

  Future<void> _test() async {
    try {
      await api.sendTestNotification();
      if (mounted) showMessage(context, 'Prueba enviada. Debería llegar en unos segundos.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final registered = Push.registered;
    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = CenteredMessage(
          icon: Icons.error_outline,
          text: _error!,
          actionLabel: 'Reintentar',
          onAction: _load);
    } else {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(
                      registered && _permission
                          ? Icons.notifications_active
                          : Icons.notifications_off_outlined,
                      color: registered && _permission
                          ? Colors.green.shade700
                          : t.colorScheme.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        registered && _permission
                            ? 'Este celular recibe alertas'
                            : 'Este celular aún no recibe alertas',
                        style: t.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Las alertas llegan aunque la app esté cerrada. Elige abajo cuáles quieres recibir.',
                    style: t.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    if (!(registered && _permission))
                      Expanded(
                        child: FilledButton.icon(
                          icon: _registering
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.phonelink_ring),
                          label: const Text('Activar en este celular'),
                          onPressed: _registering ? null : _activatePhone,
                        ),
                      ),
                    if (registered && _permission)
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.send),
                          label: const Text('Enviar prueba'),
                          onPressed: _test,
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final a in _kTypes)
                  SwitchListTile(
                    secondary: Icon(a.icon),
                    title: Text(a.title),
                    subtitle: Text(a.description),
                    value: _active.containsKey(a.type),
                    onChanged: _busy.contains(a.type) || api.userReadonly
                        ? null
                        : (v) => _toggle(a.type, v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'El límite de velocidad y las zonas se configuran por vehículo. '
            'Las alertas aplican a todos tus vehículos.',
            style: t.textTheme.bodySmall
                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: body,
    );
  }
}
