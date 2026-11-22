import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api.dart';
import '../brand.dart';
import '../map_utils.dart';
import '../marker_icons.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'device_screen.dart';
import 'geofences_screen.dart';
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
  GoogleMapController? _map;
  bool _centered = false;
  List<Geofence> _zones = [];
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    api.addListener(_onData);
    _loadZones();
  }

  @override
  void dispose() {
    api.removeListener(_onData);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final z = await api.geofences();
      if (mounted) setState(() => _zones = z);
    } catch (_) {}
  }

  void _onData() => _centerAll();

  Future<void> _centerAll({bool force = false}) async {
    final c = _map;
    if ((_centered && !force) || c == null) return;
    final pts = api.positions.values.map((p) => p.latLng).toList();
    if (pts.isEmpty) return;
    _centered = true;
    await fitPoints(c, pts, padding: 80);
  }

  void _showVehicle(Device d) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _VehicleSheet(deviceId: d.id),
    );
  }

  Future<void> _openZones() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const GeofencesScreen()));
    _loadZones();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding;
    final bottom = navBarSpace(context);
    final zoneColor = Theme.of(context).colorScheme.secondary;
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final list = api.devices.values.toList();
        final markers = <Marker>{
          for (final d in list)
            if (api.positions[d.id] != null)
              Marker(
                markerId: MarkerId('d${d.id}'),
                position: api.positions[d.id]!.latLng,
                icon: MarkerIcons.vehicle(api.positions[d.id]!, d.online),
                rotation: MarkerIcons.rotation(api.positions[d.id]!),
                anchor: const Offset(0.5, 0.5),
                flat: true,
                onTap: () => _showVehicle(d),
              ),
        };
        return Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition:
                    const CameraPosition(target: kDefaultCenter, zoom: 11),
                onMapCreated: (c) {
                  _map = c;
                  _centerAll();
                },
                markers: markers,
                circles: geofenceCircles(_zones, zoneColor),
                polygons: geofencePolygons(_zones, zoneColor),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                rotateGesturesEnabled: false,
                padding: EdgeInsets.only(top: pad.top + 70, bottom: bottom + 64),
                onTap: (_) {
                  if (_menuOpen) setState(() => _menuOpen = false);
                },
              ),
            ),
            // Barra superior: nombre de la persona + estado de conexión.
            Positioned(
              top: pad.top + 12,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _TopPill(vehicles: list.length),
              ),
            ),
            // Botón desplegable abajo a la derecha, sobre la barra de menú.
            Positioned(
              right: 12,
              bottom: bottom + 4,
              child: _MapMenu(
                open: _menuOpen,
                onToggle: () => setState(() => _menuOpen = !_menuOpen),
                actions: [
                  _MenuAction(
                    icon: Icons.center_focus_strong,
                    label: 'Ver todos',
                    onTap: () {
                      setState(() => _menuOpen = false);
                      _centerAll(force: true);
                    },
                  ),
                  _MenuAction(
                    icon: Icons.fence,
                    label: 'Zonas',
                    onTap: () {
                      setState(() => _menuOpen = false);
                      _openZones();
                    },
                  ),
                ],
              ),
            ),
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
      borderRadius: BorderRadius.circular(kRadiusCard),
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
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width - 110),
                  child: Text(
                      api.userName.isNotEmpty
                          ? api.userName
                          : (api.userEmail.isNotEmpty ? api.userEmail : 'Mi cuenta'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
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

class _MenuAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuAction({required this.icon, required this.label, required this.onTap});
}

/// Botón redondo que al tocarlo despliega hacia arriba las opciones del mapa.
class _MapMenu extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final List<_MenuAction> actions;
  const _MapMenu({required this.open, required this.onToggle, required this.actions});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.bottomRight,
          child: !open
              ? const SizedBox(width: 0, height: 0)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final a in actions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: t.colorScheme.surface,
                          elevation: 3,
                          borderRadius: BorderRadius.circular(kRadiusButton),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(kRadiusButton),
                            onTap: a.onTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(a.label,
                                      style: t.textTheme.labelLarge
                                          ?.copyWith(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 10),
                                  Icon(a.icon, size: 20, color: t.colorScheme.primary),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Material(
          color: open ? t.colorScheme.primary : t.colorScheme.surface,
          elevation: 4,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusCard),
            onTap: onToggle,
            child: SizedBox(
              width: 52,
              height: 52,
              child: AnimatedRotation(
                turns: open ? 0.125 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  open ? Icons.add : Icons.layers_outlined,
                  color: open ? t.colorScheme.onPrimary : t.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
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
