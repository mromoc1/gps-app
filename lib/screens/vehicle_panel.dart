import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'history_screen.dart';

/// Alto del panel del vehículo, como fracción de la pantalla.
const double kVehiclePanelHeight = 0.5;

/// Alto de la barrita para arrastrar que va sobre el panel (en píxeles).
const double kVehiclePanelHandle = 48;

/// Abre el panel del vehículo sobre el mapa principal. Tiene alto fijo:
/// no se despliega a pantalla completa; se cierra deslizándolo hacia abajo
/// o tocando el mapa.
Future<void> showVehiclePanel(BuildContext context, int deviceId) {
  final h = MediaQuery.of(context).size.height;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    barrierColor: Colors.transparent, // el mapa se sigue viendo
    builder: (_) => SizedBox(
      height: h * kVehiclePanelHeight,
      child: VehiclePanel(deviceId: deviceId),
    ),
  );
}

/// Panel de un vehículo. Arriba, fijos: nombre, estado y botones
/// (Detalles, Eventos, Historial). Abajo, fijo: corte de motor.
/// En el medio se ven los detalles o los eventos, según el botón elegido.
class VehiclePanel extends StatefulWidget {
  final int deviceId;
  const VehiclePanel({super.key, required this.deviceId});

  @override
  State<VehiclePanel> createState() => _VehiclePanelState();
}

class _VehiclePanelState extends State<VehiclePanel> {
  static const int _eventDays = 7;
  bool _sending = false;
  bool _marking = false;
  bool _showEvents = false;
  bool _eventsLoading = false;
  bool _eventsLoaded = false;
  String? _eventsError;
  List<TEvent> _events = [];
  StreamSubscription<TEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _eventsSub = api.eventStream.listen((e) {
      if (e.deviceId != widget.deviceId || !mounted) return;
      if (_eventsLoaded) setState(() => _events.insert(0, e));
      if (e.type == 'commandResult') {
        final result = e.attributes['result']?.toString() ?? '';
        showMessage(context, 'El equipo respondió: $result');
      } else if (e.type == 'alarm') {
        showMessage(context, eventLabel(e));
      }
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _eventsLoading = true;
      _eventsError = null;
    });
    try {
      final now = DateTime.now();
      _events = await api.events(
        widget.deviceId,
        now.subtract(const Duration(days: _eventDays)),
        now.add(const Duration(minutes: 1)),
      );
      _eventsLoaded = true;
    } on ApiException catch (e) {
      _eventsError = e.message;
    }
    if (mounted) setState(() => _eventsLoading = false);
  }

  void _openEvents() {
    setState(() => _showEvents = true);
    if (!_eventsLoaded && !_eventsLoading) _loadEvents();
  }

  /// Marca el vehículo como comprometido o, si ya lo está, como recuperado.
  Future<void> _toggleCompromised(Device d) async {
    final mark = !d.compromised;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(mark ? Icons.warning_amber_rounded : Icons.verified_outlined,
            color: mark ? kCompromisedColor : Colors.green.shade700),
        title: Text(mark ? '¿Marcar como vehículo comprometido?' : '¿Marcar como recuperado?'),
        content: Text(mark
            ? '${d.name} quedará en rojo en el mapa y en la lista de vehículos, '
                'en todos los celulares que lo siguen.'
            : '${d.name} volverá a su color normal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: mark ? kCompromisedColor : Colors.green.shade700),
            onPressed: () => Navigator.pop(c, true),
            child: Text(mark ? 'Sí, marcar' : 'Sí, recuperado'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _marking = true);
    try {
      await api.setCompromised(d.id, mark);
      if (mounted) {
        showMessage(context,
            mark ? '${d.name} quedó marcado como comprometido.' : '${d.name} quedó marcado como recuperado.');
      }
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  Future<void> _engine(Device d, Position? p, bool stop) async {
    final moving = (p?.speedKmh ?? 0) > 5;
    final first = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(stop ? Icons.power_settings_new : Icons.play_circle_outline,
            color: stop ? Colors.red.shade700 : Colors.green.shade700),
        title: Text(stop ? 'Cortar motor' : 'Reactivar motor'),
        content: Text(stop
            ? 'Se cortará el paso de bencina y el motor de ${d.name} se detendrá.'
                '\n\nÚsalo con el vehículo detenido o en caso de robo.'
                '${moving ? '\n\nAtención: el vehículo va a ${p!.speedKmh.round()} km/h.' : ''}'
            : 'Se volverá a habilitar el paso de bencina de ${d.name} '
                'para que el motor pueda encender.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continuar')),
        ],
      ),
    );
    if (first != true || !mounted) return;

    if (stop) {
      final second = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Confirmas el corte?'),
          content: Text('Esta acción detendrá el motor de ${d.name}.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('No')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sí, cortar motor'),
            ),
          ],
        ),
      );
      if (second != true || !mounted) return;
    }

    setState(() => _sending = true);
    try {
      final sent =
          await api.sendCommand(d.id, stop ? 'engineStop' : 'engineResume');
      if (!mounted) return;
      showMessage(
        context,
        sent
            ? 'Comando enviado. El estado del corte se actualizará en unos segundos.'
            : 'El equipo está desconectado: el comando quedó en cola y se enviará al reconectar.',
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final d = api.devices[widget.deviceId];
        final p = api.positions[widget.deviceId];
        if (d == null) {
          return const CenteredMessage(
            icon: Icons.directions_car_outlined,
            text: 'Este vehículo ya no está disponible.',
          );
        }
        // Mensajes (por ejemplo, del corte de motor) visibles dentro del panel.
        return ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildPanel(d, p),
          ),
        );
      },
    );
  }

  Widget _buildPanel(Device d, Position? p) {
    final t = Theme.of(context);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fijo arriba: nombre, estado y botones.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nombre y estado a la izquierda; botón de alerta a la derecha.
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        _StatusHeader(device: d, position: p),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CompromisedButton(
                    compromised: d.compromised,
                    busy: _marking,
                    onPressed: api.canEditDevices ? () => _toggleCompromised(d) : null,
                  ),
                ],
              ),
              if (d.compromised) ...[
                const SizedBox(height: 8),
                _CompromisedBanner(device: d),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _PanelButton(
                      icon: Icons.info_outline,
                      label: 'Detalles',
                      selected: !_showEvents,
                      onTap: () => setState(() => _showEvents = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PanelButton(
                      icon: Icons.notifications_none,
                      label: 'Eventos',
                      selected: _showEvents,
                      onTap: _openEvents,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PanelButton(
                      icon: Icons.route,
                      label: 'Historial',
                      selected: false,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => HistoryScreen(device: d)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        const Divider(height: 1),
        // En el medio, con su propio desplazamiento: detalles o eventos.
        Expanded(
          child: _showEvents
              ? _buildEvents()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  children: [_buildInfo(p)],
                ),
        ),
        const Divider(height: 1),
        // Fijo abajo: corte de motor.
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
          child: _sending
              ? const SizedBox(
                  height: 44, child: Center(child: CircularProgressIndicator()))
              : Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.power_settings_new),
                        label: const Text('Cortar motor'),
                        onPressed: () => _engine(d, p, true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          minimumSize: const Size.fromHeight(44),
                        ),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Reactivar'),
                        onPressed: () => _engine(d, p, false),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEvents() {
    if (_eventsLoading && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_eventsError != null && _events.isEmpty) {
      return CenteredMessage(
        icon: Icons.error_outline,
        text: _eventsError!,
        actionLabel: 'Reintentar',
        onAction: _loadEvents,
      );
    }
    if (_events.isEmpty) {
      return const CenteredMessage(
        icon: Icons.notifications_none,
        text: 'Sin eventos en los últimos $_eventDays días.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _events.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (_, i) {
          final e = _events[i];
          final c = eventColor(e.type);
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: c.withValues(alpha: 0.12),
              child: Icon(eventIcon(e.type), color: c, size: 20),
            ),
            title: Text(eventLabel(e)),
            subtitle: Text(fmtDateTime(e.eventTime)),
          );
        },
      ),
    );
  }

  Widget _buildInfo(Position? p) {
    final ign = p?.ignition;
    final cut = p?.cutActive;
    final rssi = p?.rssi;
    return InfoGrid(children: [
      InfoTile(
        icon: Icons.speed,
        label: 'Velocidad',
        value: p == null ? '—' : '${p.speedKmh.round()} km/h',
      ),
      InfoTile(
        icon: ign == true ? Icons.key : Icons.key_off,
        label: 'Motor',
        value: ign == null ? '—' : (ign ? 'Encendido' : 'Apagado'),
        color: ign == true ? Colors.green.shade700 : null,
      ),
      InfoTile(
        icon: Icons.car_repair,
        label: 'Batería del auto',
        value: fmtNum(p?.power, unit: 'V'),
      ),
      InfoTile(
        icon: Icons.battery_charging_full,
        label: 'Batería del GPS',
        value: fmtNum(p?.battery, decimals: 2, unit: 'V'),
      ),
      InfoTile(
        icon: Icons.satellite_alt,
        label: 'Satélites',
        value: p?.satellites?.toString() ?? '—',
      ),
      InfoTile(
        icon: Icons.signal_cellular_alt,
        label: 'Señal celular',
        value: rssi == null ? '—' : '$rssi de 5',
      ),
      InfoTile(
        icon: Icons.block,
        label: 'Corte de motor',
        value: cut == null ? '—' : (cut ? 'Activo' : 'Desactivado'),
        color: cut == true ? Colors.red.shade700 : null,
      ),
      InfoTile(
        icon: Icons.add_road,
        label: 'Odómetro GPS',
        value: fmtNum(p?.totalDistanceKm, decimals: 0, unit: 'km'),
      ),
    ]);
  }
}

class _StatusHeader extends StatelessWidget {
  final Device device;
  final Position? position;
  const _StatusHeader({required this.device, required this.position});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor(device.status).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statusLabel(device.status),
              style: TextStyle(
                  color: statusColor(device.status),
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Última posición: ${fmtDateTime(position?.fixTime)}',
            style: t.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Botón con ícono de alerta, a la derecha del título del panel.
/// Sin marcar: contorno rojo. Marcado: relleno rojo.
class _CompromisedButton extends StatelessWidget {
  final bool compromised;
  final bool busy;
  final VoidCallback? onPressed;
  const _CompromisedButton({
    required this.compromised,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }
    final tooltip = onPressed == null
        ? 'Tu cuenta no puede marcar vehículos'
        : compromised
            ? 'Marcar como recuperado'
            : 'Marcar como vehículo comprometido';
    return compromised
        ? IconButton.filled(
            tooltip: tooltip,
            style: IconButton.styleFrom(
              backgroundColor: kCompromisedColor,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.warning_amber_rounded),
            onPressed: onPressed,
          )
        : IconButton.outlined(
            tooltip: tooltip,
            style: IconButton.styleFrom(
              foregroundColor: kCompromisedColor,
              side: BorderSide(color: kCompromisedColor.withValues(alpha: 0.6)),
            ),
            icon: const Icon(Icons.warning_amber_rounded),
            onPressed: onPressed,
          );
  }
}

/// Aviso rojo bajo el título: desde cuándo y quién lo marcó.
class _CompromisedBanner extends StatelessWidget {
  final Device device;
  const _CompromisedBanner({required this.device});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final since = device.compromisedSince;
    final by = device.compromisedBy;
    final parts = [
      if (since != null) 'desde ${fmtDateTime(since)}',
      if (by.isNotEmpty) 'por $by',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kCompromisedColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: kCompromisedColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Comprometido${parts.isEmpty ? '' : ' ${parts.join(' ')}'}',
              style: t.textTheme.bodySmall?.copyWith(
                  color: kCompromisedColor, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón del panel del vehículo; resalta el que está elegido.
class _PanelButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PanelButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(42),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      visualDensity: VisualDensity.compact,
    );
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
    return selected
        ? FilledButton.tonal(style: style, onPressed: onTap, child: child)
        : OutlinedButton(style: style, onPressed: onTap, child: child);
  }
}
