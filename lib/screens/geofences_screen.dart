import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api.dart';
import '../brand.dart';
import '../map_utils.dart';
import '../marker_icons.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

/// Lista de zonas (geocercas) del usuario.
class GeofencesScreen extends StatefulWidget {
  const GeofencesScreen({super.key});

  @override
  State<GeofencesScreen> createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends State<GeofencesScreen> {
  bool _loading = true;
  String? _error;
  List<Geofence> _zones = [];

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
      _zones = await api.geofences();
      _zones.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Geofence? g]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => GeofenceEditorScreen(geofence: g)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Geofence g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Borrar zona'),
        content: Text('¿Borrar "${g.name}"? Dejarás de recibir alertas de esta zona.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await api.deleteGeofence(g.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = CenteredMessage(
          icon: Icons.error_outline, text: _error!, actionLabel: 'Reintentar', onAction: _load);
    } else if (_zones.isEmpty) {
      body = CenteredMessage(
        icon: Icons.fence,
        text: 'Aún no tienes zonas. Crea una para saber cuándo tu vehículo entra o sale de un lugar, como tu casa o el trabajo.',
        actionLabel: 'Crear zona',
        onAction: () => _edit(),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _zones.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final g = _zones[i];
          final circle = g.shape == GeofenceShape.circle;
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(circle ? Icons.radio_button_unchecked : Icons.pentagon_outlined),
              title: Text(g.name),
              subtitle: Text(circle
                  ? 'Círculo de ${(g.radius ?? 0).round()} m'
                  : 'Polígono de ${g.points.length} puntos'),
              onTap: () => _edit(g),
              trailing: IconButton(
                tooltip: 'Borrar',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(g),
              ),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Zonas')),
      body: body,
      floatingActionButton: _zones.isEmpty && !_loading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva zona'),
            ),
    );
  }
}

/// Crear o editar una zona dibujándola en el mapa.
class GeofenceEditorScreen extends StatefulWidget {
  final Geofence? geofence;
  const GeofenceEditorScreen({super.key, this.geofence});

  @override
  State<GeofenceEditorScreen> createState() => _GeofenceEditorScreenState();
}

class _GeofenceEditorScreenState extends State<GeofenceEditorScreen> {
  GoogleMapController? _map;
  final _name = TextEditingController();
  GeofenceShape _shape = GeofenceShape.circle;
  LatLng? _center;
  double _radius = 200;
  final List<LatLng> _points = [];
  final Set<int> _devices = {};
  Set<int> _originalDevices = {};
  bool _saving = false;
  bool _loadingLinks = false;

  bool get _editing => widget.geofence != null;

  @override
  void initState() {
    super.initState();
    final g = widget.geofence;
    if (g != null) {
      _name.text = g.name;
      _shape = g.shape ?? GeofenceShape.circle;
      _center = g.center;
      _radius = (g.radius ?? 200).clamp(50, 5000).toDouble();
      _points.addAll(g.points);
      _loadLinks(g.id);
    } else {
      _devices.addAll(api.devices.keys); // por defecto, todos los vehículos
    }
  }

  Future<void> _loadLinks(int geofenceId) async {
    setState(() => _loadingLinks = true);
    for (final d in api.devices.keys) {
      try {
        final list = await api.geofences(deviceId: d);
        if (list.any((x) => x.id == geofenceId)) _devices.add(d);
      } catch (_) {}
    }
    _originalDevices = {..._devices};
    if (mounted) setState(() => _loadingLinks = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _onTap(LatLng p) {
    setState(() {
      if (_shape == GeofenceShape.circle) {
        _center = p;
      } else {
        _points.add(p);
      }
    });
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      (_shape == GeofenceShape.circle ? _center != null : _points.length >= 3) &&
      _devices.isNotEmpty;

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _saving = true);
    try {
      final area = _shape == GeofenceShape.circle
          ? Geofence.circleWkt(_center!, _radius)
          : Geofence.polygonWkt(_points);
      final g = await api.saveGeofence(
          id: widget.geofence?.id, name: _name.text.trim(), area: area);
      for (final d in _devices.difference(_originalDevices)) {
        await api.linkDevice('geofenceId', g.id, d, true);
      }
      for (final d in _originalDevices.difference(_devices)) {
        await api.linkDevice('geofenceId', g.id, d, false);
      }
      if (!mounted) return;
      showMessage(context, 'Zona guardada. Activa las alertas de entrada y salida en Perfil → Notificaciones.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = t.colorScheme.secondary;
    final start = _center ??
        (_points.isNotEmpty ? _points.first : null) ??
        (api.positions.values.isNotEmpty ? api.positions.values.first.latLng : kDefaultCenter);

    final circles = <Circle>{
      if (_shape == GeofenceShape.circle && _center != null)
        Circle(
          circleId: const CircleId('zona'),
          center: _center!,
          radius: _radius,
          strokeWidth: 2,
          strokeColor: color,
          fillColor: color.withValues(alpha: 0.2),
        ),
    };
    final polygons = <Polygon>{
      if (_shape == GeofenceShape.polygon && _points.length >= 3)
        Polygon(
          polygonId: const PolygonId('zona'),
          points: _points,
          strokeWidth: 2,
          strokeColor: color,
          fillColor: color.withValues(alpha: 0.2),
        ),
    };
    final polylines = <Polyline>{
      if (_shape == GeofenceShape.polygon && _points.length == 2)
        Polyline(polylineId: const PolylineId('borde'), points: _points, color: color, width: 2),
    };
    final markers = <Marker>{
      if (_shape == GeofenceShape.polygon)
        for (var i = 0; i < _points.length; i++)
          Marker(
            markerId: MarkerId('v$i'),
            position: _points[i],
            icon: MarkerIcons.vertex,
            anchor: const Offset(0.5, 0.5),
          ),
      for (final p in api.positions.values)
        Marker(
          markerId: MarkerId('d${p.deviceId}'),
          position: p.latLng,
          icon: MarkerIcons.vehicle(p, api.devices[p.deviceId]?.online ?? false),
          anchor: const Offset(0.5, 0.5),
          flat: true,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar zona' : 'Nueva zona'),
        actions: [
          TextButton(
            onPressed: _valid && !_saving ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: start, zoom: 15),
                  onMapCreated: (c) => _map = c,
                  onTap: _onTap,
                  circles: circles,
                  polygons: polygons,
                  polylines: polylines,
                  markers: markers,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  rotateGesturesEnabled: false,
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Material(
                    color: t.colorScheme.surface,
                    elevation: 3,
                    borderRadius: BorderRadius.circular(kRadiusCard),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        _shape == GeofenceShape.circle
                            ? 'Toca el mapa para ubicar el centro de la zona.'
                            : 'Toca el mapa para agregar cada esquina (mínimo 3).',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la zona',
                      hintText: 'Ej. Casa, Trabajo',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<GeofenceShape>(
                    segments: const [
                      ButtonSegment(
                          value: GeofenceShape.circle,
                          icon: Icon(Icons.radio_button_unchecked),
                          label: Text('Círculo')),
                      ButtonSegment(
                          value: GeofenceShape.polygon,
                          icon: Icon(Icons.pentagon_outlined),
                          label: Text('Polígono')),
                    ],
                    selected: {_shape},
                    onSelectionChanged: (s) => setState(() => _shape = s.first),
                  ),
                  const SizedBox(height: 6),
                  if (_shape == GeofenceShape.circle)
                    Row(children: [
                      const Text('Radio'),
                      Expanded(
                        child: Slider(
                          min: 50,
                          max: 5000,
                          divisions: 99,
                          value: _radius,
                          label: '${_radius.round()} m',
                          onChanged: (v) => setState(() => _radius = v),
                        ),
                      ),
                      SizedBox(width: 64, child: Text('${_radius.round()} m', textAlign: TextAlign.end)),
                    ])
                  else
                    Row(children: [
                      Text('${_points.length} puntos'),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.undo),
                        label: const Text('Deshacer'),
                        onPressed: _points.isEmpty ? null : () => setState(_points.removeLast),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('Limpiar'),
                        onPressed: _points.isEmpty ? null : () => setState(_points.clear),
                      ),
                    ]),
                  if (api.devices.length > 1) ...[
                    const SizedBox(height: 4),
                    Text('Vehículos que vigila esta zona', style: t.textTheme.labelLarge),
                    if (_loadingLinks)
                      const LinearProgressIndicator()
                    else
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final d in api.devices.values)
                            FilterChip(
                              label: Text(d.name),
                              selected: _devices.contains(d.id),
                              onSelected: (v) => setState(() {
                                v ? _devices.add(d.id) : _devices.remove(d.id);
                              }),
                            ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
