import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';

class HistoryScreen extends StatefulWidget {
  final Device device;
  const HistoryScreen({super.key, required this.device});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final MapController _map = MapController();
  bool _mapReady = false;
  late DateTime _day;
  bool _loading = true;
  String? _error;
  List<Position> _points = const [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    _load();
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pts = await api.route(
        widget.device.id,
        _day,
        _day.add(const Duration(days: 1)),
      );
      _points = pts.where((p) => p.valid).toList();
    } on ApiException catch (e) {
      _error = e.message;
      _points = const [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _fit();
  }

  void _fit() {
    if (!_mapReady || _points.isEmpty) return;
    final coords = _points.map((p) => p.latLng).toList();
    if (coords.length == 1) {
      _map.move(coords.first, 16);
    } else {
      _map.fitCamera(CameraFit.coordinates(
        coordinates: coords,
        padding: const EdgeInsets.all(40),
        maxZoom: 17,
      ));
    }
  }

  void _shift(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    _day = next;
    _load();
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: now.subtract(const Duration(days: 180)),
      lastDate: now,
    );
    if (picked == null) return;
    _day = DateTime(picked.year, picked.month, picked.day);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final coords = _points.map((p) => p.latLng).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Historial · ${widget.device.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(_isToday ? 'Hoy' : fmtDay(_day)),
                    onPressed: _pickDay,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isToday ? null : () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: api.positions[widget.device.id]?.latLng ??
                        const LatLng(-33.4489, -70.6693),
                    initialZoom: 13,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () {
                      _mapReady = true;
                      _fit();
                    },
                  ),
                  children: [
                    ...baseMapLayers(),
                    if (coords.length >= 2)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: coords,
                          strokeWidth: 5,
                          color: t.colorScheme.primary,
                        ),
                      ]),
                    if (coords.isNotEmpty)
                      MarkerLayer(markers: [
                        dotMarker(coords.first, Colors.green.shade600,
                            Icons.play_arrow),
                        if (coords.length >= 2)
                          dotMarker(coords.last, Colors.red.shade600,
                              Icons.flag),
                      ]),
                    mapAttribution(),
                  ],
                ),
                if (_loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55FFFFFF),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          _Summary(points: _points, loading: _loading, error: _error),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<Position> points;
  final bool loading;
  final String? error;

  const _Summary({
    required this.points,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (error != null) {
      child = Text(error!, textAlign: TextAlign.center);
    } else if (loading) {
      child = const Text('Cargando recorrido…', textAlign: TextAlign.center);
    } else if (points.isEmpty) {
      child = const Text('Sin recorrido registrado este día.',
          textAlign: TextAlign.center);
    } else {
      final maxSpeed =
          points.map((p) => p.speedKmh).reduce((a, b) => a > b ? a : b);
      child = InfoGrid(children: [
        InfoTile(
          icon: Icons.route,
          label: 'Distancia',
          value: fmtNum(routeKm(points), unit: 'km'),
        ),
        InfoTile(
          icon: Icons.speed,
          label: 'Velocidad máxima',
          value: '${maxSpeed.round()} km/h',
        ),
        InfoTile(
          icon: Icons.schedule,
          label: 'Primer registro',
          value: fmtTime(points.first.fixTime),
        ),
        InfoTile(
          icon: Icons.schedule,
          label: 'Último registro',
          value: fmtTime(points.last.fixTime),
        ),
      ]);
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}
