import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../config.dart';
import '../push.dart';
import '../util.dart';
import '../widgets.dart';
import 'geofences_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';

/// Pestaña Perfil: cuenta, versión de la app y cómo está construida.
class ProfileTab extends StatelessWidget {
  final VoidCallback onShowMap;
  const ProfileTab({super.key, required this.onShowMap});

  String get _versionText =>
      'Versión $kAppVersion (compilación $kAppBuild)';

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salir')),
        ],
      ),
    );
    if (ok != true) return;
    await Push.unregister();
    await api.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  /// Estado de la cuenta según la fecha de vencimiento del usuario.
  Widget _accountTile(BuildContext context) {
    final exp = api.userExpiration;
    final IconData icon;
    final Color color;
    final String title;
    final String subtitle;
    if (exp == null) {
      icon = Icons.all_inclusive;
      color = Colors.green.shade700;
      title = 'Cuenta activa';
      subtitle = 'Sin fecha de vencimiento';
    } else {
      final days = exp.difference(DateTime.now()).inDays;
      if (exp.isBefore(DateTime.now())) {
        icon = Icons.error_outline;
        color = Colors.red.shade700;
        title = 'Cuenta vencida';
        subtitle = 'Venció el ${fmtDay(exp)}. Contacta a soporte para renovarla.';
      } else if (days <= 15) {
        icon = Icons.schedule;
        color = Colors.orange.shade800;
        title = 'Vence pronto';
        subtitle = 'Vence el ${fmtDay(exp)} (${days == 0 ? 'hoy' : 'en $days días'})';
      } else {
        icon = Icons.verified_outlined;
        color = Colors.green.shade700;
        title = 'Cuenta activa';
        subtitle = 'Vigente hasta el ${fmtDay(exp)}';
      }
    }
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final host = Uri.parse(kServerUrl).host;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListenableBuilder(
        listenable: api,
        builder: (context, _) {
          final name = api.userName.isEmpty ? 'Mi cuenta' : api.userName;
          final initials = name
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, navBarSpace(context)),
            children: [
              // Cuenta
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: t.colorScheme.primary,
                        child: Text(initials.isEmpty ? '?' : initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: t.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            if (api.userEmail.isNotEmpty)
                              Text(api.userEmail,
                                  style: t.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                                '${api.devices.length} ${api.devices.length == 1 ? 'vehículo' : 'vehículos'}',
                                style: t.textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Section(title: 'Cuenta', children: [
                _accountTile(context),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificaciones'),
                  subtitle: const Text('Elige qué alertas llegan a tu celular'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, const NotificationsScreen()),
                ),
                ListTile(
                  leading: const Icon(Icons.fence),
                  title: const Text('Zonas'),
                  subtitle: const Text('Avisos al entrar o salir de un lugar'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, const GeofencesScreen()),
                ),
                ListTile(
                  leading: Icon(api.totpEnabled
                      ? Icons.verified_user
                      : Icons.shield_outlined),
                  title: const Text('Verificación en dos pasos'),
                  subtitle: Text(api.totpEnabled ? 'Activada' : 'Desactivada'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, const SecurityScreen()),
                ),
              ]),
              const SizedBox(height: 12),
              _Section(title: 'Conexión', children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text('Servidor'),
                  subtitle: Text(host),
                ),
                ListTile(
                  leading: Icon(
                    api.socketConnected ? Icons.wifi_tethering : Icons.wifi_off,
                    color: api.socketConnected
                        ? Colors.green.shade600
                        : Colors.orange.shade700,
                  ),
                  title: const Text('Datos en vivo'),
                  subtitle: Text(api.socketConnected
                      ? 'Conectado'
                      : 'Reconectando…'),
                  trailing: TextButton(
                    onPressed: onShowMap,
                    child: const Text('Ver mapa'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _Section(title: 'Aplicación', children: [
                ListTile(
                  leading: const BrandLogo(size: 36),
                  title: const Text(kAppName),
                  subtitle: Text(_versionText),
                ),
                if (kAppCommit.isNotEmpty || kAppBuildDate.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.tag),
                    title: const Text('Detalle de compilación'),
                    subtitle: Text([
                      if (kAppBuildDate.isNotEmpty) 'Fecha $kAppBuildDate',
                      if (kAppCommit.isNotEmpty) 'Código $kAppCommit',
                    ].join(' · ')),
                  ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Licencias de software'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: kAppName,
                    applicationVersion: _versionText,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.colorScheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
                onPressed: () => _logout(context),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
          child: Text(title,
              style: t.textTheme.labelLarge
                  ?.copyWith(color: t.colorScheme.primary)),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
