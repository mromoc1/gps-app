import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'events_screen.dart';
import 'history_screen.dart';

/// Panel de un vehículo: sube sobre el mapa principal al tocarlo.
/// Arrastrándolo hacia arriba muestra todo: datos, historial, eventos y
/// corte de motor.
class VehiclePanel extends StatefulWidget {
  final int deviceId;
  final ScrollController scrollController;
  const VehiclePanel({super.key, required this.deviceId, required this.scrollController});

  @override
  State<VehiclePanel> createState() => _VehiclePanelState();
}

class _VehiclePanelState extends State<VehiclePanel> {
  bool _sending = false;
  StreamSubscription<TEvent>? _eventsSub;

  @override
  void initState() {
    super.initState();
    _eventsSub = api.eventStream.listen((e) {
      if (e.deviceId != widget.deviceId || !mounted) return;
      if (e.type == 'commandResult') {
        final result = e.attributes['result']?.toString() ?? '';
        showMessage(context, 'El equipo respondió: $result');
      } else if (e.type == 'alarm') {
        showMessage(context, eventLabel(e));
      }
    });
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }

  Future<void> _engine(Device d, Position? p, bool stop) async {
    final moving = (p?.speedKmh ?? 0) > 5;
    final first = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(stop ? Icons.power_settings_new : Icons.play_circle_outline,
            color: stop ? Colors.red.shade700 : Colors.green.shade700),
        title: Text(stop ? 'Cortar motor' : 'Reactivar motor'),
        content: Text(stop
            ? 'Se cortará el paso de bencina y el motor de ${d.name} se detendrá.'
                '\n\nÚsalo con el vehículo detenido o en caso de robo.'
                '${moving ? '\n\nAtención: el vehículo va a ${p!.speedKmh.round()} km/h.' : ''}'
            : 'Se volverá a habilitar el paso de bencina de ${d.name} '
                'para que el motor pueda encender.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continuar')),
        ],
      ),
    );
    if (first != true || !mounted) return;

    if (stop) {
      final second = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('¿Confirmas el corte?'),
          content: Text('Esta acción detendrá el motor de ${d.name}.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('No')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Sí, cortar motor'),
            ),
          ],
        ),
      );
      if (second != true || !mounted) return;
    }

    setState(() => _sending = true);
    try {
      final sent =
          await api.sendCommand(d.id, stop ? 'engineStop' : 'engineResume');
      if (!mounted) return;
      showMessage(
        context,
        sent
            ? 'Comando enviado. El estado del corte se actualizará en unos segundos.'
            : 'El equipo está desconectado: el comando quedó en cola y se enviará al reconectar.',
      );
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final d = api.devices[widget.deviceId];
        final p = api.positions[widget.deviceId];
        if (d == null) {
          return ListView(
            controller: widget.scrollController,
            children: const [
              CenteredMessage(
                icon: Icons.directions_car_outlined,
                text: 'Este vehículo ya no está disponible.',
              ),
            ],
          );
        }
        // Mensajes (por ejemplo, del corte de motor) visibles dentro del panel.
        return ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: _buildSheet(d, p, widget.scrollController),
          ),
        );
      },
    );
  }

  Widget _buildSheet(Device d, Position? p, ScrollController scroll) {
    final t = Theme.of(context);
    return ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Text(d.name,
              style: t.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _StatusHeader(device: d, position: p),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.route),
                  label: const Text('Historial'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => HistoryScreen(device: d)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.notifications_none),
                  label: const Text('Eventos'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EventsScreen(device: d)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfo(p),
          const SizedBox(height: 22),
          Text('Corte de motor', style: t.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Cortar'),
                    onPressed: () => _engine(d, p, true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Reactivar'),
                    onPressed: () => _engine(d, p, false),
                  ),
                ),
              ],
            ),
        ],
    );
  }

  Widget _buildInfo(Position? p) {
    final ign = p?.ignition;
    final cut = p?.cutActive;
    final rssi = p?.rssi;
    return InfoGrid(children: [
      InfoTile(
        icon: Icons.speed,
        label: 'Velocidad',
        value: p == null ? '—' : '${p.speedKmh.round()} km/h',
      ),
      InfoTile(
        icon: ign == true ? Icons.key : Icons.key_off,
        label: 'Motor',
        value: ign == null ? '—' : (ign ? 'Encendido' : 'Apagado'),
        color: ign == true ? Colors.green.shade700 : null,
      ),
      InfoTile(
        icon: Icons.car_repair,
        label: 'Batería del auto',
        value: fmtNum(p?.power, unit: 'V'),
      ),
      InfoTile(
        icon: Icons.battery_charging_full,
        label: 'Batería del GPS',
        value: fmtNum(p?.battery, decimals: 2, unit: 'V'),
      ),
      InfoTile(
        icon: Icons.satellite_alt,
        label: 'Satélites',
        value: p?.satellites?.toString() ?? '—',
      ),
      InfoTile(
        icon: Icons.signal_cellular_alt,
        label: 'Señal celular',
        value: rssi == null ? '—' : '$rssi de 5',
      ),
      InfoTile(
        icon: Icons.block,
        label: 'Corte de motor',
        value: cut == null ? '—' : (cut ? 'Activo' : 'Desactivado'),
        color: cut == true ? Colors.red.shade700 : null,
      ),
      InfoTile(
        icon: Icons.add_road,
        label: 'Odómetro GPS',
        value: fmtNum(p?.totalDistanceKm, decimals: 0, unit: 'km'),
      ),
    ]);
  }
}

class _StatusHeader extends StatelessWidget {
  final Device device;
  final Position? position;
  const _StatusHeader({required this.device, required this.position});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor(device.status).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(statusLabel(device.status),
              style: TextStyle(
                  color: statusColor(device.status),
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Última posición: ${fmtDateTime(position?.fixTime)}',
            style: t.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
