import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api.dart';
import '../brand.dart';
import '../map_utils.dart';
import '../marker_icons.dart';
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
  GoogleMapController? _map;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  late DateTime _day;
  bool _loading = true;
  String? _error;
  List<Position> _points = const [];
  List<Trip> _trips = const [];
  int? _selected; // índice del viaje elegido; null = todo el día

  /// Puntos que se dibujan: los del viaje elegido o los de todo el día.
  List<Position> get _shown {
    final i = _selected;
    if (i == null || i >= _trips.length) return _points;
    final tr = _trips[i];
    if (tr.start == null || tr.end == null) return _points;
    final from = tr.start!.subtract(const Duration(seconds: 5));
    final to = tr.end!.add(const Duration(seconds: 5));
    return _points
        .where((p) => p.fixTime != null && !p.fixTime!.isBefore(from) && !p.fixTime!.isAfter(to))
        .toList();
  }

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
      _selected = null;
      try {
        _trips = await api.trips(
          widget.device.id,
          _day,
          _day.add(const Duration(days: 1)),
        );
      } catch (_) {
        _trips = const [];
      }
    } on ApiException catch (e) {
      _error = e.message;
      _points = const [];
      _trips = const [];
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _fit();
  }

  void _fit() {
    final c = _map;
    final pts = _shown;
    if (c == null || pts.isEmpty) return;
    fitPoints(c, pts.map((p) => p.latLng).toList(),
        padding: 48, singleZoom: 16);
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
    final coords = _shown.map((p) => p.latLng).toList();
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
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: api.positions[widget.device.id]?.latLng ?? kDefaultCenter,
                    zoom: 13,
                  ),
                  onMapCreated: (c) {
                    _map = c;
                    _fit();
                  },
                  polylines: {
                    if (coords.length >= 2)
                      Polyline(
                        polylineId: const PolylineId('ruta'),
                        points: coords,
                        width: 5,
                        color: t.colorScheme.primary,
                      ),
                  },
                  markers: {
                    if (coords.isNotEmpty)
                      Marker(
                        markerId: const MarkerId('inicio'),
                        position: coords.first,
                        icon: MarkerIcons.start,
                        anchor: const Offset(0.5, 0.5),
                      ),
                    if (coords.length >= 2)
                      Marker(
                        markerId: const MarkerId('fin'),
                        position: coords.last,
                        icon: MarkerIcons.end,
                        anchor: const Offset(0.5, 0.5),
                      ),
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  rotateGesturesEnabled: false,
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
          _Summary(
            points: _shown,
            loading: _loading,
            error: _error,
            title: _selected == null ? null : 'Viaje ${_selected! + 1}',
          ),
          if (!_loading && _error == null && _trips.isNotEmpty)
            _TripList(
              trips: _trips,
              selected: _selected,
              onSelect: (i) {
                setState(() => _selected = i);
                _fit();
              },
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final List<Position> points;
  final bool loading;
  final String? error;
  final String? title;

  const _Summary({
    required this.points,
    required this.loading,
    required this.error,
    this.title,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title!,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 6),
                child,
              ],
            ),
    );
  }
}

/// Lista horizontal de viajes del día. "Todo el día" muestra el recorrido completo.
class _TripList extends StatelessWidget {
  final List<Trip> trips;
  final int? selected;
  final ValueChanged<int?> onSelect;

  const _TripList({
    required this.trips,
    required this.selected,
    required this.onSelect,
  });

  String _dur(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    return h > 0 ? '$h h $m min' : '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget card({
      required bool active,
      required VoidCallback onTap,
      required String title,
      required String line1,
      required String line2,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: active ? t.colorScheme.primaryContainer : t.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: InkWell(
            borderRadius: BorderRadius.circular(kRadiusCard),
            onTap: onTap,
            child: Container(
              width: 150,
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(line1, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
                  Text(line2, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final totalKm = trips.fold<double>(0, (a, b) => a + b.distanceKm);
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(
              '${trips.length} ${trips.length == 1 ? 'viaje' : 'viajes'} este día',
              style: t.textTheme.labelLarge,
            ),
          ),
          SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 6, 0),
              children: [
                card(
                  active: selected == null,
                  onTap: () => onSelect(null),
                  title: 'Todo el día',
                  line1: '${fmtNum(totalKm, unit: 'km')} en total',
                  line2: 'Recorrido completo',
                ),
                for (var i = 0; i < trips.length; i++)
                  card(
                    active: selected == i,
                    onTap: () => onSelect(i),
                    title: '${fmtTime(trips[i].start)} – ${fmtTime(trips[i].end)}',
                    line1: '${fmtNum(trips[i].distanceKm, unit: 'km')} · ${_dur(trips[i].duration)}',
                    line2: 'Máx. ${trips[i].maxSpeedKmh.round()} km/h',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
