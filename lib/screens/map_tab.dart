import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../brand.dart';
import '../config.dart';
import '../map_utils.dart';
import '../marker_icons.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'geofences_screen.dart';
import 'vehicle_panel.dart';

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
  int? _focused; // vehículo con su panel abierto: el mapa lo sigue

  @override
  void initState() {
    super.initState();
    api.addListener(_onData);
    mapFocus.addListener(_onFocus);
    _loadZones();
  }

  @override
  void dispose() {
    api.removeListener(_onData);
    mapFocus.removeListener(_onFocus);
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final z = await api.geofences();
      if (mounted) setState(() => _zones = z);
    } catch (_) {}
  }

  void _onData() {
    final id = _focused;
    if (id == null) {
      _centerAll();
      return;
    }
    final p = api.positions[id];
    if (p != null) _map?.animateCamera(CameraUpdate.newLatLng(p.latLng));
  }

  void _onFocus() {
    final id = mapFocus.value;
    if (id == null) return;
    mapFocus.value = null;
    final d = api.devices[id];
    if (d != null) _showVehicle(d);
  }

  Future<void> _centerAll({bool force = false}) async {
    final c = _map;
    if ((_centered && !force) || c == null) return;
    final pts = api.positions.values.map((p) => p.latLng).toList();
    if (pts.isEmpty) return;
    _centered = true;
    await fitPoints(c, pts, padding: 80);
  }

  Future<void> _showVehicle(Device d) async {
    setState(() {
      _focused = d.id;
      _menuOpen = false;
    });
    final panel = showVehiclePanel(context, d.id);
    // Se espera a que el mapa aplique el nuevo margen inferior (el alto del
    // panel); así el auto queda al centro de la parte del mapa que se ve.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final p = api.positions[d.id];
    if (p != null && mounted && _focused == d.id) {
      await _map?.animateCamera(CameraUpdate.newLatLngZoom(p.latLng, 16));
    }
    await panel;
    if (mounted) setState(() => _focused = null);
  }

  /// Abre WhatsApp con un mensaje ya escrito para soporte. El número está
  /// en el servidor de Traccar (atributos soporteWhatsapp y soporteNombre).
  Future<void> _contactSupport() async {
    try {
      final c = await api.supportContact();
      if (!mounted) return;
      if (c == null) {
        showMessage(context, 'El contacto de soporte todavía no está configurado.');
        return;
      }
      final who = api.userName.isNotEmpty ? api.userName : api.userEmail;
      final hello = c.name.isNotEmpty ? 'Hola ${c.name}' : 'Hola';
      final text = '$hello, necesito ayuda con $kAppName.'
          '${who.isNotEmpty ? ' Mi cuenta: $who.' : ''}';
      final uri = Uri.https('wa.me', '/${c.phone}', {'text': text});
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) showMessage(context, 'No se pudo abrir WhatsApp.');
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, 'No se pudo abrir WhatsApp.');
    }
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
                icon: MarkerIcons.vehicle(api.positions[d.id]!, d.online,
                    compromised: d.compromised),
                // Los comprometidos quedan encima de los demás.
                zIndexInt: d.compromised ? 1 : 0,
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
                // Con un panel abierto, el vehículo queda visible sobre él.
                padding: EdgeInsets.only(
                  top: pad.top + 70,
                  bottom: _focused != null
                      ? MediaQuery.of(context).size.height * kVehiclePanelHeight +
                          kVehiclePanelHandle
                      : bottom + 64,
                ),
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
                  _MenuAction(
                    icon: Icons.support_agent,
                    label: 'Soporte',
                    onTap: () {
                      setState(() => _menuOpen = false);
                      _contactSupport();
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
      color: kBrandBlue,
      elevation: 3,
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo sobre un cuadrado blanco para que no se pierda en el azul.
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const BrandLogo(size: 28),
            ),
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
                          ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
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
                            ? Colors.greenAccent.shade400
                            : Colors.orange.shade300,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      live
                          ? 'En vivo · $vehicles ${vehicles == 1 ? 'vehículo' : 'vehículos'}'
                          : 'Reconectando…',
                      style: t.textTheme.labelSmall?.copyWith(color: kOnBlueMuted),
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
