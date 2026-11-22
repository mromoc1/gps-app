import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

DateTime? _date(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

double _double(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

double? _numOrNull(dynamic v) => v is num ? v.toDouble() : null;

bool? _boolOrNull(dynamic v) => v is bool ? v : null;

Map<String, dynamic> _attrs(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class Device {
  final int id;
  final String name;
  final String uniqueId;
  final String status;
  final DateTime? lastUpdate;
  final String? model;
  final int groupId;
  final Map<String, dynamic> attributes;

  /// Objeto completo tal como lo entrega Traccar (para guardarlo de vuelta).
  final Map<String, dynamic> raw;

  Device({
    required this.id,
    required this.name,
    required this.uniqueId,
    required this.status,
    this.lastUpdate,
    this.model,
    this.groupId = 0,
    this.attributes = const {},
    this.raw = const {},
  });

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        uniqueId: (j['uniqueId'] ?? '').toString(),
        status: (j['status'] ?? 'unknown').toString(),
        lastUpdate: _date(j['lastUpdate']),
        model: j['model']?.toString(),
        groupId: (j['groupId'] as num?)?.toInt() ?? 0,
        attributes: Map<String, dynamic>.from((j['attributes'] as Map?) ?? const {}),
        raw: j,
      );

  bool get online => status == 'online';

  // Vehículo comprometido (robado o en riesgo). Se guarda en los atributos
  // del dispositivo en Traccar para que se vea igual en todos los celulares.
  static const String kCompromised = 'comprometido';
  static const String kCompromisedSince = 'comprometidoDesde';
  static const String kCompromisedBy = 'comprometidoPor';

  bool get compromised {
    final v = attributes[kCompromised];
    return v == true || v?.toString().toLowerCase() == 'true';
  }

  DateTime? get compromisedSince => _date(attributes[kCompromisedSince]);
  String get compromisedBy => (attributes[kCompromisedBy] ?? '').toString();
}

class Position {
  final int id;
  final int deviceId;
  final double latitude;
  final double longitude;
  final double speedKnots;
  final double course;
  final DateTime? fixTime;
  final bool valid;
  final Map<String, dynamic> attributes;

  Position({
    required this.id,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    required this.speedKnots,
    required this.course,
    required this.fixTime,
    required this.valid,
    required this.attributes,
  });

  factory Position.fromJson(Map<String, dynamic> j) => Position(
        id: (j['id'] as num?)?.toInt() ?? 0,
        deviceId: (j['deviceId'] as num).toInt(),
        latitude: _double(j['latitude']),
        longitude: _double(j['longitude']),
        speedKnots: _double(j['speed']),
        course: _double(j['course']),
        fixTime: _date(j['fixTime']),
        valid: j['valid'] == true,
        attributes: _attrs(j['attributes']),
      );

  LatLng get latLng => LatLng(latitude, longitude);
  double get speedKmh => speedKnots * 1.852;
  bool? get ignition => _boolOrNull(attributes['ignition']);
  bool? get cutActive => _boolOrNull(attributes['out1']);
  double? get power => _numOrNull(attributes['power']);
  double? get battery => _numOrNull(attributes['battery']);
  int? get satellites => _numOrNull(attributes['sat'])?.toInt();
  int? get rssi => _numOrNull(attributes['rssi'])?.toInt();
  double? get totalDistanceKm {
    final m = _numOrNull(attributes['totalDistance']);
    return m == null ? null : m / 1000;
  }
}

class TEvent {
  final int id;
  final String type;
  final int deviceId;
  final DateTime? eventTime;
  final Map<String, dynamic> attributes;

  TEvent({
    required this.id,
    required this.type,
    required this.deviceId,
    required this.eventTime,
    required this.attributes,
  });

  factory TEvent.fromJson(Map<String, dynamic> j) => TEvent(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: (j['type'] ?? '').toString(),
        deviceId: (j['deviceId'] as num?)?.toInt() ?? 0,
        eventTime: _date(j['eventTime']),
        attributes: _attrs(j['attributes']),
      );

  String? get alarm => attributes['alarm']?.toString();
}

class DeviceGroup {
  final int id;
  final String name;

  DeviceGroup({required this.id, required this.name});

  factory DeviceGroup.fromJson(Map<String, dynamic> j) => DeviceGroup(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
      );
}

/// Tipo de forma de una geocerca.
enum GeofenceShape { circle, polygon }

/// Geocerca (zona) de Traccar. El área usa texto WKT con orden "lat lon":
///   CIRCLE (lat lon, radio)
///   POLYGON ((lat lon, lat lon, ...))
class Geofence {
  final int id;
  final String name;
  final String area;

  Geofence({required this.id, required this.name, required this.area});

  factory Geofence.fromJson(Map<String, dynamic> j) => Geofence(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        area: (j['area'] ?? '').toString(),
      );

  GeofenceShape? get shape {
    final a = area.trim().toUpperCase();
    if (a.startsWith('CIRCLE')) return GeofenceShape.circle;
    if (a.startsWith('POLYGON')) return GeofenceShape.polygon;
    return null;
  }

  static List<double> _numbers(String s) => RegExp(r'-?\d+(?:\.\d+)?')
      .allMatches(s)
      .map((m) => double.parse(m.group(0)!))
      .toList();

  /// Centro del círculo.
  LatLng? get center {
    if (shape != GeofenceShape.circle) return null;
    final n = _numbers(area);
    return n.length >= 3 ? LatLng(n[0], n[1]) : null;
  }

  /// Radio del círculo en metros.
  double? get radius {
    if (shape != GeofenceShape.circle) return null;
    final n = _numbers(area);
    return n.length >= 3 ? n[2] : null;
  }

  /// Vértices del polígono.
  List<LatLng> get points {
    if (shape != GeofenceShape.polygon) return const [];
    final n = _numbers(area);
    final out = <LatLng>[];
    for (var i = 0; i + 1 < n.length; i += 2) {
      out.add(LatLng(n[i], n[i + 1]));
    }
    // El WKT repite el primer punto al final para cerrar el polígono.
    if (out.length > 1 &&
        out.first.latitude == out.last.latitude &&
        out.first.longitude == out.last.longitude) {
      out.removeLast();
    }
    return out;
  }

  static String circleWkt(LatLng c, double radiusMeters) =>
      'CIRCLE (${c.latitude.toStringAsFixed(6)} ${c.longitude.toStringAsFixed(6)}, '
      '${radiusMeters.toStringAsFixed(0)})';

  static String polygonWkt(List<LatLng> pts) {
    final all = [...pts, pts.first];
    final body = all
        .map((p) =>
            '${p.latitude.toStringAsFixed(6)} ${p.longitude.toStringAsFixed(6)}')
        .join(', ');
    return 'POLYGON (($body))';
  }
}

/// Un viaje: desde que el vehículo parte hasta que se detiene
/// (Traccar lo calcula en /api/reports/trips).
class Trip {
  final DateTime? start;
  final DateTime? end;
  final double distanceKm;
  final double maxSpeedKmh;
  final String? startAddress;
  final String? endAddress;

  const Trip({
    required this.start,
    required this.end,
    required this.distanceKm,
    required this.maxSpeedKmh,
    this.startAddress,
    this.endAddress,
  });

  Duration get duration =>
      start == null || end == null ? Duration.zero : end!.difference(start!);

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
        start: _date(j['startTime']),
        end: _date(j['endTime']),
        distanceKm: _double(j['distance']) / 1000,
        maxSpeedKmh: _double(j['maxSpeed']) * 1.852, // nudos a km/h
        startAddress: j['startAddress']?.toString(),
        endAddress: j['endAddress']?.toString(),
      );
}
