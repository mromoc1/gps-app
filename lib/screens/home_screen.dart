import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'device_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _map = MapController();
  bool _mapReady = false;
  bool _centered = false;
  bool _loading = true;
  String? _error;

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
      await api.loadAll();
      api.startLive();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'No se pudieron cargar los vehículos.';
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _centerIfNeeded();
  }

  void _centerIfNeeded({bool force = false}) {
    if ((_centered && !force) || !_mapReady) return;
    final pts = api.positions.values.map((p) => p.latLng).toList();
    if (pts.isEmpty) return;
    _centered = true;
    if (pts.length == 1) {
      _map.move(pts.first, 15);
    } else {
      _map.fitCamera(CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ));
    }
  }

  Future<void> _logout() async {
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
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _open(Device d) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DeviceScreen(deviceId: d.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis vehículos'),
        actions: [
          ListenableBuilder(
            listenable: api,
            builder: (context, _) => Tooltip(
              message: api.socketConnected
                  ? 'Recibiendo datos en vivo'
                  : 'Reconectando…',
              child: Icon(
                api.socketConnected ? Icons.wifi_tethering : Icons.wifi_off,
                color: api.socketConnected
                    ? Colors.green.shade600
                    : Colors.orange.shade700,
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(api.userEmail.isEmpty ? 'Mi cuenta' : api.userEmail),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: api,
        builder: (context, _) {
          if (_loading && api.devices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null && api.devices.isEmpty) {
            return CenteredMessage(
              icon: Icons.error_outline,
              text: _error!,
              actionLabel: 'Reintentar',
              onAction: _load,
            );
          }
          if (api.devices.isEmpty) {
            return CenteredMessage(
              icon: Icons.directions_car_outlined,
              text: 'Todavía no tienes vehículos asociados a tu cuenta.',
              actionLabel: 'Actualizar',
              onAction: _load,
            );
          }
          final list = api.devices.values.toList()
            ..sort((a, b) => a.name.compareTo(b.name));
          final mapHeight = MediaQuery.of(context).size.height * 0.42;
          return Column(
            children: [
              SizedBox(height: mapHeight, child: _buildMap(list)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    try {
                      await api.loadAll();
                    } on ApiException catch (e) {
                      if (context.mounted) showMessage(context, e.message);
                    }
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _DeviceCard(
                      device: list[i],
                      position: api.positions[list[i].id],
                      onTap: () => _open(list[i]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMap(List<Device> list) {
    final markers = <Marker>[
      for (final d in list)
        if (api.positions[d.id] != null)
          vehicleMarker(api.positions[d.id]!, d.online, onTap: () => _open(d)),
    ];
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(-33.4489, -70.6693),
            initialZoom: 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onMapReady: () {
              _mapReady = true;
              _centerIfNeeded();
            },
          ),
          children: [
            ...baseMapLayers(),
            MarkerLayer(markers: markers),
            mapAttribution(),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'center-all',
            onPressed: () => _centerIfNeeded(force: true),
            child: const Icon(Icons.center_focus_strong),
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final Position? position;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.device,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = position;
    final ignition = p?.ignition;
    final details = <String>[
      if (p != null) '${p.speedKmh.round()} km/h',
      if (ignition != null) ignition ? 'Motor encendido' : 'Motor apagado',
      if (p?.cutActive == true) 'Corte activo',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: t.colorScheme.primaryContainer,
                child: Icon(Icons.directions_car,
                    color: t.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        style: t.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor(device.status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${statusLabel(device.status)} · ${timeAgo(device.lastUpdate)}',
                            style: t.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(details.join(' · '),
                          style: t.textTheme.bodySmall?.copyWith(
                              color: p?.cutActive == true
                                  ? t.colorScheme.error
                                  : t.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
