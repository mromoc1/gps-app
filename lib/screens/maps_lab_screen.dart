import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../brand.dart';
import '../config.dart';
import '../map_styles.dart';
import '../widgets.dart';
import 'google_map_screen.dart';

/// Lista de mapas disponibles para probar.
class MapsLabScreen extends StatefulWidget {
  const MapsLabScreen({super.key});

  @override
  State<MapsLabScreen> createState() => _MapsLabScreenState();
}

class _MapsLabScreenState extends State<MapsLabScreen> {
  Map<MapKeyProvider, String> _keys = {};

  @override
  void initState() {
    super.initState();
    _reloadKeys();
  }

  Future<void> _reloadKeys() async {
    final k = await MapKeys.all();
    if (mounted) setState(() => _keys = k);
  }

  Future<void> _editKey(MapKeyProvider p) async {
    await showKeyDialog(context, p);
    await _reloadKeys();
  }

  void _open(int index) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => MapPreviewScreen(initialIndex: index)))
        .then((_) => _reloadKeys());
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final providers = <String>[];
    for (final s in kMapStyles) {
      if (!providers.contains(s.provider)) providers.add(s.provider);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Probar mapas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Toca un mapa para verlo a pantalla completa con tus vehículos. '
            'Dentro puedes pasar al siguiente con las flechas.',
            style: t.textTheme.bodyMedium
                ?.copyWith(color: t.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          for (final prov in providers) ...[
            _providerHeader(prov),
            Card(
              margin: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  for (var i = 0; i < kMapStyles.length; i++)
                    if (kMapStyles[i].provider == prov)
                      _styleTile(i, kMapStyles[i]),
                ],
              ),
            ),
          ],
          _providerHeader('Google Maps'),
          Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: Column(
              children: [
                for (var i = 0; i < kGoogleMapModes.length; i++)
                  ListTile(
                    leading: Icon(kGoogleMapModes[i].traffic
                        ? Icons.traffic_outlined
                        : (kGoogleMapModes[i].name == 'Normal'
                            ? Icons.map_outlined
                            : Icons.satellite_alt)),
                    title: Text(kGoogleMapModes[i].name),
                    subtitle: Text(kGoogleMapModes[i].description),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => GoogleMapScreen(initialIndex: i))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerHeader(String prov) {
    final t = Theme.of(context);
    MapKeyProvider? kp;
    for (final s in kMapStyles) {
      if (s.provider == prov && s.keyProvider != null) kp = s.keyProvider;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(prov,
                style: t.textTheme.labelLarge
                    ?.copyWith(color: t.colorScheme.primary)),
          ),
          if (kp != null)
            TextButton.icon(
              icon: Icon(
                _keys.containsKey(kp) ? Icons.key : Icons.key_off,
                size: 18,
              ),
              label: Text(_keys.containsKey(kp) ? 'Cambiar clave' : 'Ingresar clave'),
              onPressed: () => _editKey(kp!),
            ),
        ],
      ),
    );
  }

  Widget _styleTile(int index, MapStyle s) {
    final missing = s.needsKey && !_keys.containsKey(s.keyProvider);
    return ListTile(
      leading: Icon(_iconFor(s), color: missing ? Colors.grey : null),
      title: Text(s.name),
      subtitle: Text(missing ? 'Requiere clave · ${s.description}' : s.description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(index),
    );
  }
}

IconData _iconFor(MapStyle s) {
  final n = '${s.id} ${s.name}'.toLowerCase();
  if (n.contains('sat')) return Icons.satellite_alt;
  if (n.contains('dark') || n.contains('oscuro')) return Icons.dark_mode_outlined;
  if (n.contains('topo')) return Icons.terrain;
  return Icons.map_outlined;
}

Future<void> showKeyDialog(BuildContext context, MapKeyProvider p) async {
  final current = await MapKeys.get(p);
  if (!context.mounted) return;
  final ctrl = TextEditingController(text: current ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Clave de ${p.label}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Crea una clave gratuita en ${p.signupUrl} y pégala aquí. '
              'Queda guardada solo en este teléfono.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Clave de API'),
          ),
        ],
      ),
      actions: [
        if (current != null)
          TextButton(
              onPressed: () => Navigator.pop(c, ''),
              child: const Text('Borrar')),
        TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Guardar')),
      ],
    ),
  );
  if (result != null) await MapKeys.set(p, result);
}

/// Un mapa a pantalla completa, con flechas para pasar al siguiente.
class MapPreviewScreen extends StatefulWidget {
  final int initialIndex;
  const MapPreviewScreen({super.key, required this.initialIndex});

  @override
  State<MapPreviewScreen> createState() => _MapPreviewScreenState();
}

class _MapPreviewScreenState extends State<MapPreviewScreen> {
  final MapController _map = MapController();
  late int _index;
  Map<MapKeyProvider, String> _keys = {};
  bool _infoOpen = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    final k = await MapKeys.all();
    if (mounted) setState(() => _keys = k);
  }

  void _go(int delta) {
    setState(() {
      _index = (_index + delta) % kMapStyles.length;
      if (_index < 0) _index += kMapStyles.length;
    });
    final max = kMapStyles[_index].maxZoom.toDouble();
    if (_map.camera.zoom > max) _map.move(_map.camera.center, max);
  }

  @override
  Widget build(BuildContext context) {
    final style = kMapStyles[_index];
    final key = style.keyProvider == null ? null : _keys[style.keyProvider];
    final missingKey = style.needsKey && key == null;
    final pad = MediaQuery.of(context).padding;
    final positions = api.positions.values.toList();
    final center = positions.isNotEmpty
        ? positions.first.latLng
        : const LatLng(-33.4489, -70.6693);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15,
                maxZoom: 19,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                if (!missingKey)
                  TileLayer(
                    key: ValueKey('base-${style.id}-$key'),
                    urlTemplate: style.resolve(key),
                    subdomains: style.subdomains,
                    maxNativeZoom: style.maxZoom,
                    maxZoom: 19,
                    userAgentPackageName: kUserAgentPackage,
                  ),
                if (!missingKey && style.overlayUrl != null)
                  TileLayer(
                    key: ValueKey('overlay-${style.id}'),
                    urlTemplate: style.overlayUrl!,
                    maxNativeZoom: style.maxZoom,
                    maxZoom: 19,
                    userAgentPackageName: kUserAgentPackage,
                  ),
                MarkerLayer(markers: [
                  for (final p in positions)
                    vehicleMarker(p, api.devices[p.deviceId]?.online ?? false),
                ]),
              ],
            ),
          ),
          // Cabecera: volver + nombre del mapa
          Positioned(
            top: pad.top + 12,
            left: 12,
            right: 12,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MapButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Volver',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                Expanded(child: _infoCard(style)),
              ],
            ),
          ),
          if (missingKey)
            Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.key_off, size: 40),
                      const SizedBox(height: 10),
                      Text('Este mapa necesita una clave de ${style.keyProvider!.label}.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () async {
                          await showKeyDialog(context, style.keyProvider!);
                          await _loadKeys();
                        },
                        child: const Text('Ingresar clave'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            bottom: pad.bottom + 84,
            child: MapCredit(text: style.attribution),
          ),
          // Navegación entre mapas
          Positioned(
            left: 16,
            right: 16,
            bottom: pad.bottom + 16,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 4,
              borderRadius: BorderRadius.circular(kRadiusCard),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Anterior',
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _go(-1),
                    ),
                    Expanded(
                      child: Text(
                        '${_index + 1} de ${kMapStyles.length}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Siguiente',
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _go(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(MapStyle s) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(kRadiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadiusCard),
        onTap: () => setState(() => _infoOpen = !_infoOpen),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${s.provider} · ${s.name}',
                        style: t.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Icon(_infoOpen ? Icons.expand_less : Icons.expand_more,
                      size: 20),
                ],
              ),
              if (_infoOpen) ...[
                const SizedBox(height: 4),
                Text(s.description, style: t.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(s.terms,
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                if (s.needsKey) ...[
                  const SizedBox(height: 4),
                  Text(
                    _keys.containsKey(s.keyProvider)
                        ? 'Clave ingresada'
                        : 'Requiere clave de ${s.keyProvider!.label}',
                    style: t.textTheme.labelSmall?.copyWith(
                        color: _keys.containsKey(s.keyProvider)
                            ? Colors.green.shade700
                            : t.colorScheme.error),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Atajo usado desde otras pantallas.
void openMapsLab(BuildContext context) {
  Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const MapsLabScreen()));
}
