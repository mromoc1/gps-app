import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';
import 'models.dart';

/// Capa base del mapa (OpenStreetMap) con atribución.
List<Widget> baseMapLayers() => [
      TileLayer(
        urlTemplate: kTileUrl,
        userAgentPackageName: kUserAgentPackage,
        maxZoom: 19,
      ),
    ];

Widget mapAttribution() => RichAttributionWidget(
      attributions: [TextSourceAttribution('OpenStreetMap contributors')],
    );

/// Ícono del vehículo en el mapa: flecha si se mueve, auto si está detenido.
class VehicleMarker extends StatelessWidget {
  final Position position;
  final bool online;

  const VehicleMarker({super.key, required this.position, required this.online});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    if (!online) {
      color = Colors.grey.shade600;
    } else if (position.ignition == true) {
      color = Colors.green.shade600;
    } else {
      color = scheme.primary;
    }
    final moving = position.speedKmh > 3;
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(blurRadius: 6, color: Colors.black26, offset: Offset(0, 2)),
        ],
      ),
      alignment: Alignment.center,
      child: moving
          ? Transform.rotate(
              angle: position.course * math.pi / 180,
              child: const Icon(Icons.navigation, color: Colors.white, size: 20),
            )
          : const Icon(Icons.directions_car, color: Colors.white, size: 20),
    );
  }
}

Marker vehicleMarker(Position p, bool online, {VoidCallback? onTap}) => Marker(
      point: p.latLng,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: onTap,
        child: VehicleMarker(position: p, online: online),
      ),
    );

Marker dotMarker(LatLng point, Color color, IconData icon) => Marker(
      point: point,
      width: 32,
      height: 32,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );

/// Recuadro con un dato (ej. Velocidad: 42 km/h).
class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const InfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? t.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: t.textTheme.labelSmall
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grilla de dos columnas para [InfoTile].
class InfoGrid extends StatelessWidget {
  final List<Widget> children;
  const InfoGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const CenteredMessage({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
