import 'package:flutter/material.dart';

import '../api.dart';
import '../brand.dart';
import '../config.dart';
import '../widgets.dart';
import 'login_screen.dart';
import 'maps_lab_screen.dart';

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
    await api.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
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
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('Probar mapas'),
                  subtitle: const Text('Ver cada proveedor de mapas con tus vehículos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openMapsLab(context),
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
              const SizedBox(height: 12),
              const _Section(title: 'Construida con', children: [
                ListTile(
                  leading: Icon(Icons.flutter_dash),
                  title: Text('Flutter y Dart'),
                  subtitle: Text('Un solo código para Android y iPhone'),
                ),
                ListTile(
                  leading: Icon(Icons.map_outlined),
                  title: Text('OpenStreetMap'),
                  subtitle: Text('Mapas con flutter_map'),
                ),
                ListTile(
                  leading: Icon(Icons.satellite_alt),
                  title: Text('Traccar'),
                  subtitle: Text('Servidor que recibe los GPS (API y tiempo real)'),
                ),
                ListTile(
                  leading: Icon(Icons.router_outlined),
                  title: Text('Teltonika FMC920'),
                  subtitle: Text('Equipo GPS 4G instalado en el vehículo'),
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
