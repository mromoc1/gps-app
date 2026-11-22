import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'models.dart';

const LatLng kDefaultCenter = LatLng(-33.4489, -70.6693); // Santiago

LatLngBounds boundsOf(List<LatLng> pts) {
  var minLat = pts.first.latitude, maxLat = pts.first.latitude;
  var minLng = pts.first.longitude, maxLng = pts.first.longitude;
  for (final p in pts) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

/// Centra el mapa para que se vean todos los puntos.
Future<void> fitPoints(GoogleMapController c, List<LatLng> pts,
    {double padding = 60, double singleZoom = 15}) async {
  if (pts.isEmpty) return;
  if (pts.length == 1) {
    await c.animateCamera(CameraUpdate.newLatLngZoom(pts.first, singleZoom));
    return;
  }
  try {
    await c.animateCamera(CameraUpdate.newLatLngBounds(boundsOf(pts), padding));
  } catch (_) {
    // El mapa aún no tiene tamaño; se intenta centrar en el primer punto.
    await c.moveCamera(CameraUpdate.newLatLngZoom(pts.first, singleZoom));
  }
}

/// Formas de las geocercas para dibujarlas en el mapa.
Set<Circle> geofenceCircles(List<Geofence> list, Color color) => {
      for (final g in list)
        if (g.shape == GeofenceShape.circle && g.center != null)
          Circle(
            circleId: CircleId('g${g.id}'),
            center: g.center!,
            radius: g.radius ?? 100,
            strokeWidth: 2,
            strokeColor: color.withValues(alpha: 0.8),
            fillColor: color.withValues(alpha: 0.2),
          ),
    };

Set<Polygon> geofencePolygons(List<Geofence> list, Color color) => {
      for (final g in list)
        if (g.shape == GeofenceShape.polygon && g.points.length >= 3)
          Polygon(
            polygonId: PolygonId('g${g.id}'),
            points: g.points,
            strokeWidth: 2,
            strokeColor: color.withValues(alpha: 0.8),
            fillColor: color.withValues(alpha: 0.2),
          ),
    };
