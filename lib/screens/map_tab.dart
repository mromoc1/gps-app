import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../brand.dart';
import '../config.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'device_screen.dart';
import 'history_screen.dart';

/// Pestaña Mapa: todos los vehículos sobre un mapa a pantalla completa.
class MapTab extends StatefulWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const MapTab({
    super.key,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final MapController _map = MapController();
  bool _mapReady = false;
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    api.addListener(_onData);
  }

  @override
  void dispose() {
    api.removeListener(_onData);
    super.dispose();
  }

  void _onData() => _centerAll();

  void _centerAll({bool force = false}) {
    if ((_centered && !force) || !_mapReady) return;
    final pts = api.positions.values.map((p) => p.latLng).toList();
    if (pts.isEmpty) return;
    _centered = true;
    if (pts.length == 1) {
      _map.move(pts.first, 15);
    } else {
      final pad = MediaQuery.of(context).padding;
      _map.fitCamera(CameraFit.coordinates(
        coordinates: pts,
        padding: EdgeInsets.fromLTRB(
            48, pad.top + 90, 48, navBarSpace(context) + 40),
        maxZoom: 16,
      ));
    }
  }

  void _showVehicle(Device d) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _VehicleSheet(deviceId: d.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = navBarSpace(context);
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final list = api.devices.values.toList();
        final markers = <Marker>[
          for (final d in list)
            if (api.positions[d.id] != null)
              vehicleMarker(api.positions[d.id]!, d.online,
                  onTap: () => _showVehicle(d)),
        ];
        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: const LatLng(-33.4489, -70.6693),
                  initialZoom: 11,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    _mapReady = true;
                    _centerAll();
                  },
                ),
                children: [
                  ...baseMapLayers(),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
            // Barra superior: marca + estado de conexión.
            Positioned(
              top: top + 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  _TopPill(vehicles: list.length),
                  const Spacer(),
                  MapButton(
                    icon: Icons.center_focus_strong,
                    tooltip: 'Ver todos',
                    onPressed: () => _centerAll(force: true),
                  ),
                ],
              ),
            ),
            Positioned(left: 8, bottom: bottom + 4, child: const MapCredit()),
            if (widget.loading && list.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (!widget.loading && widget.error != null && list.isEmpty)
              Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: CenteredMessage(
                    icon: Icons.error_outline,
                    text: widget.error!,
                    actionLabel: 'Reintentar',
                    onAction: widget.onRetry,
                  ),
                ),
              ),
            if (!widget.loading && widget.error == null && list.isEmpty)
              const Center(
                child: Card(
                  margin: EdgeInsets.all(24),
                  child: CenteredMessage(
                    icon: Icons.directions_car_outlined,
                    text: 'Todavía no tienes vehículos asociados a tu cuenta.',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TopPill extends StatelessWidget {
  final int vehicles;
  const _TopPill({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final live = api.socketConnected;
    return Material(
      color: t.colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 30),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kAppName,
                    style: t.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: live
                            ? Colors.green.shade600
                            : Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      live
                          ? 'En vivo · $vehicles ${vehicles == 1 ? 'vehículo' : 'vehículos'}'
                          : 'Reconectando…',
                      style: t.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumen de un vehículo al tocar su marcador.
class _VehicleSheet extends StatelessWidget {
  final int deviceId;
  const _VehicleSheet({required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final d = api.devices[deviceId];
        final p = api.positions[deviceId];
        if (d == null) return const SizedBox(height: 120);
        final t = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(d.name,
                    style: t.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Row(children: [
                  StatusDot(status: d.status),
                  const SizedBox(width: 6),
                  Text('${statusLabel(d.status)} · ${timeAgo(d.lastUpdate)}',
                      style: t.textTheme.bodySmall),
                ]),
                const SizedBox(height: 14),
                InfoGrid(children: [
                  InfoTile(
                    icon: Icons.speed,
                    label: 'Velocidad',
                    value: p == null ? '—' : '${p.speedKmh.round()} km/h',
                  ),
                  InfoTile(
                    icon: p?.ignition == true ? Icons.key : Icons.key_off,
                    label: 'Motor',
                    value: p?.ignition == null
                        ? '—'
                        : (p!.ignition! ? 'Encendido' : 'Apagado'),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.route),
                      label: const Text('Historial'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => HistoryScreen(device: d)));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.open_in_full),
                      label: const Text('Ver detalle'),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => DeviceScreen(deviceId: d.id)));
                      },
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    );
  }
}
