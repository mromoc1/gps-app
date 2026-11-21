import 'package:latlong2/latlong.dart';

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

  Device({
    required this.id,
    required this.name,
    required this.uniqueId,
    required this.status,
    this.lastUpdate,
    this.model,
  });

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '').toString(),
        uniqueId: (j['uniqueId'] ?? '').toString(),
        status: (j['status'] ?? 'unknown').toString(),
        lastUpdate: _date(j['lastUpdate']),
        model: j['model']?.toString(),
      );

  bool get online => status == 'online';
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
