import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'brand.dart';
import 'models.dart';

/// Íconos de los marcadores de Google Maps, dibujados una vez al iniciar.
class MarkerIcons {
  static final Map<String, BitmapDescriptor> _cache = {};

  static const double _logical = 40; // tamaño en pantalla (dp)

  static Future<void> preload() async {
    final dpr = ui.PlatformDispatcher.instance.views.isNotEmpty
        ? ui.PlatformDispatcher.instance.views.first.devicePixelRatio
        : 3.0;
    for (final c in _vehicleColors.entries) {
      for (final moving in [true, false]) {
        _cache['${c.key}-$moving'] = await _circle(
          c.value,
          moving ? Icons.navigation : Icons.directions_car,
          dpr,
        );
      }
    }
    _cache['start'] = await _circle(Colors.green.shade600, Icons.play_arrow, dpr, size: 30);
    _cache['end'] = await _circle(Colors.red.shade600, Icons.flag, dpr, size: 30);
    _cache['vertex'] = await _circle(kBrandOrange, Icons.circle, dpr, size: 22);
  }

  static final Map<String, Color> _vehicleColors = {
    'offline': Colors.grey.shade600,
    'ignition': Colors.green.shade600,
    'online': kBrandNavy,
    'compromised': kCompromisedColor,
  };

  /// [compromised]: vehículo marcado como robado o en riesgo; va en rojo
  /// aunque esté desconectado.
  static BitmapDescriptor vehicle(Position p, bool online, {bool compromised = false}) {
    final key = compromised
        ? 'compromised'
        : !online
            ? 'offline'
            : (p.ignition == true ? 'ignition' : 'online');
    final moving = p.speedKmh > 3;
    return _cache['$key-$moving'] ?? BitmapDescriptor.defaultMarker;
  }

  /// La flecha solo se gira cuando el vehículo avanza.
  static double rotation(Position p) => p.speedKmh > 3 ? p.course : 0;

  static BitmapDescriptor get start =>
      _cache['start'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
  static BitmapDescriptor get end =>
      _cache['end'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
  static BitmapDescriptor get vertex =>
      _cache['vertex'] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);

  static Future<BitmapDescriptor> _circle(Color color, IconData icon, double dpr,
      {double size = _logical}) async {
    final px = size * dpr;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(px / 2, px / 2);
    final radius = px / 2 - 2 * dpr;

    canvas.drawCircle(center.translate(0, dpr), radius,
        Paint()..color = Colors.black.withValues(alpha: 0.25));
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    canvas.drawCircle(center, radius - 3 * dpr, Paint()..color = color);

    final tp = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: px * 0.5,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));

    final img = await recorder.endRecording().toImage(px.round(), px.round());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(data!.buffer.asUint8List(), width: size, height: size);
  }
}
