import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'brand.dart';
import 'config.dart';
import 'models.dart';
import 'util.dart';

/// Capa base del mapa (OpenStreetMap) con atribución.
List<Widget> baseMapLayers() => [
      TileLayer(
        urlTemplate: kTileUrl,
        userAgentPackageName: kUserAgentPackage,
        maxZoom: 19,
      ),
    ];

/// Atribución de OpenStreetMap, ubicada a mano para no quedar bajo la barra.
class MapCredit extends StatelessWidget {
  final String text;
  const MapCredit({super.key, this.text = '© OpenStreetMap'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 10, color: Colors.black87)),
    );
  }
}

/// Espacio que ocupa la barra de navegación flotante (para no tapar contenido).
double navBarSpace(BuildContext context) =>
    kNavBarHeight + 20 + MediaQuery.of(context).padding.bottom;

const double kNavBarHeight = 64;

/// Botón redondo que flota sobre el mapa.
class MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const MapButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: roundedShape(kRadiusCard),
      elevation: 3,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: scheme.primary),
        onPressed: onPressed,
      ),
    );
  }
}

/// Tarjeta de un vehículo para listas.
class DeviceCard extends StatelessWidget {
  final Device device;
  final Position? position;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.device,
    required this.position,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = position;
    final ignition = p?.ignition;
    final details = <String>[
      if (p != null) '${p.speedKmh.round()} km/h',
      if (ignition != null) ignition ? 'Motor encendido' : 'Motor apagado',
      if (p?.cutActive == true) 'Corte activo',
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusCard),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: t.colorScheme.primaryContainer,
                child: Icon(Icons.directions_car,
                    color: t.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name,
                        style: t.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusDot(status: device.status),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '${statusLabel(device.status)} · ${timeAgo(device.lastUpdate)}',
                            style: t.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(details.join(' · '),
                          style: t.textTheme.bodySmall?.copyWith(
                              color: p?.cutActive == true
                                  ? t.colorScheme.error
                                  : t.colorScheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusDot extends StatelessWidget {
  final String status;
  const StatusDot({super.key, required this.status});

  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: statusColor(status),
          shape: BoxShape.circle,
        ),
      );
}

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
