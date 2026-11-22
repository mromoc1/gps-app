import 'package:flutter/material.dart';

import 'brand.dart';
import 'models.dart';
import 'util.dart';

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
                backgroundColor: device.compromised
                    ? kCompromisedColor
                    : t.colorScheme.primaryContainer,
                child: Icon(
                    device.compromised ? Icons.warning_amber_rounded : Icons.directions_car,
                    color: device.compromised
                        ? Colors.white
                        : t.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (device.compromised) ...[
                          const SizedBox(width: 8),
                          const CompromisedTag(),
                        ],
                      ],
                    ),
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

/// Etiqueta roja "Comprometido".
class CompromisedTag extends StatelessWidget {
  const CompromisedTag({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: kCompromisedColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('Comprometido',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
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


/// Título de un panel que sube desde abajo.
class SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SheetHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Abre un panel que sube sobre el mapa, igual que al tocar un vehículo,
/// y que se puede arrastrar para agrandarlo o cerrarlo.
Future<void> showMapSheet(
  BuildContext context,
  Widget Function(ScrollController controller) builder, {
  double initialSize = 0.55,
  bool barrier = true,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Sin oscurecer el mapa cuando el panel es de un vehículo, para verlo moverse.
    barrierColor: barrier ? null : Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: initialSize,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: [initialSize],
      builder: (_, controller) => builder(controller),
    ),
  );
}

/// Vehículo que se debe mostrar en el mapa principal (por ejemplo, al
/// elegirlo en el panel Vehículos). El mapa lo centra y abre su panel.
final ValueNotifier<int?> mapFocus = ValueNotifier<int?>(null);
