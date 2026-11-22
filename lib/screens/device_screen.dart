import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api.dart';
import '../brand.dart';
import '../marker_icons.dart';
import '../models.dart';
import '../util.dart';
import '../widgets.dart';
import 'events_screen.dart';
import 'history_screen.dart';

class DeviceScreen extends StatefulWidget {
  final int deviceId;
  const DeviceScreen({super.key, required this.deviceId});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  GoogleMapController? _map;
  bool _follow = true;
  int? _lastPositionId;
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
    _map?.dispose();
    super.dispose();
  }

  void _maybeFollow(Position? p) {
    if (p == null || p.id == _lastPositionId) return;
    _lastPositionId = p.id;
    if (!_follow || _map == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _map?.animateCamera(CameraUpdate.newLatLng(p.latLng));
    });
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
          return Scaffold(
            appBar: AppBar(),
            body: const CenteredMessage(
              icon: Icons.directions_car_outlined,
              text: 'Este vehículo ya no está disponible.',
            ),
          );
        }
        _maybeFollow(p);
        final top = MediaQuery.of(context).padding.top;
        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: p == null
                    ? const CenteredMessage(
                        icon: Icons.location_off_outlined,
                        text: 'El equipo aún no ha enviado su ubicación.',
                      )
                    : _buildMap(d, p),
              ),
              Positioned(
                top: top + 12,
                left: 12,
                child: MapButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (p != null && !_follow)
                Positioned(
                  top: top + 12,
                  right: 12,
                  child: MapButton(
                    icon: Icons.my_location,
                    tooltip: 'Seguir vehículo',
                    onPressed: () {
                      setState(() => _follow = true);
                      _map?.animateCamera(CameraUpdate.newLatLng(p.latLng));
                    },
                  ),
                ),
              DraggableScrollableSheet(
                initialChildSize: 0.42,
                minChildSize: 0.16,
                maxChildSize: 0.92,
                snap: true,
                snapSizes: const [0.42],
                builder: (context, scroll) => _buildSheet(d, p, scroll),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheet(Device d, Position? p, ScrollController scroll) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(kRadiusSheet)),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(d.name,
              style: t.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _StatusHeader(device: d, position: p),
          const SizedBox(height: 14),
          _buildInfo(p),
          const SizedBox(height: 18),
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
      ),
    );
  }

  Widget _buildMap(Device d, Position p) {
    final h = MediaQuery.of(context).size.height;
    // Un toque del usuario sobre el mapa deja de seguir al vehículo.
    return Listener(
      onPointerDown: (_) {
        if (_follow) setState(() => _follow = false);
      },
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: p.latLng, zoom: 16),
        onMapCreated: (c) => _map = c,
        markers: {
          Marker(
            markerId: MarkerId('d${d.id}'),
            position: p.latLng,
            icon: MarkerIcons.vehicle(p, d.online),
            rotation: MarkerIcons.rotation(p),
            anchor: const Offset(0.5, 0.5),
            flat: true,
          ),
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        rotateGesturesEnabled: false,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 60,
          bottom: h * 0.42,
        ),
      ),
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
