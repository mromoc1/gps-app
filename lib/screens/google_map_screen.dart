import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../api.dart';
import '../brand.dart';
import '../config.dart';
import '../widgets.dart';

/// Una vista de Google Maps para probar.
class GoogleMapMode {
  final String name;
  final String description;
  final gm.MapType type;
  final bool traffic;

  const GoogleMapMode(this.name, this.description, this.type,
      {this.traffic = false});
}

const List<GoogleMapMode> kGoogleMapModes = [
  GoogleMapMode('Normal', 'El mapa de Google de siempre.', gm.MapType.normal),
  GoogleMapMode('Satélite', 'Imagen satelital sin nombres.', gm.MapType.satellite),
  GoogleMapMode('Híbrido', 'Satélite con calles y nombres.', gm.MapType.hybrid),
  GoogleMapMode('Relieve', 'Terreno y relieve.', gm.MapType.terrain),
  GoogleMapMode('Tráfico', 'Mapa normal con tráfico en vivo.', gm.MapType.normal,
      traffic: true),
];

/// Google Maps a pantalla completa con los vehículos, para comparar con los
/// otros proveedores.
class GoogleMapScreen extends StatefulWidget {
  final int initialIndex;
  const GoogleMapScreen({super.key, this.initialIndex = 0});

  @override
  State<GoogleMapScreen> createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  late int _index;
  bool _infoOpen = true;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  void _go(int delta) {
    setState(() {
      _index = (_index + delta) % kGoogleMapModes.length;
      if (_index < 0) _index += kGoogleMapModes.length;
    });
  }

  Set<gm.Marker> _markers() {
    final out = <gm.Marker>{};
    for (final p in api.positions.values) {
      final d = api.devices[p.deviceId];
      out.add(gm.Marker(
        markerId: gm.MarkerId('${p.deviceId}'),
        position: gm.LatLng(p.latitude, p.longitude),
        rotation: p.speedKmh > 3 ? p.course : 0,
        icon: gm.BitmapDescriptor.defaultMarkerWithHue(
          d?.online == true ? gm.BitmapDescriptor.hueAzure : gm.BitmapDescriptor.hueRed,
        ),
        infoWindow: gm.InfoWindow(
          title: d?.name ?? 'Vehículo',
          snippet: '${p.speedKmh.round()} km/h',
        ),
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final mode = kGoogleMapModes[_index];
    final pad = MediaQuery.of(context).padding;
    final first = api.positions.values.isNotEmpty
        ? api.positions.values.first
        : null;
    final start = first != null
        ? gm.LatLng(first.latitude, first.longitude)
        : const gm.LatLng(-33.4489, -70.6693);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: api,
              builder: (context, _) => gm.GoogleMap(
                initialCameraPosition:
                    gm.CameraPosition(target: start, zoom: 15),
                mapType: mode.type,
                trafficEnabled: mode.traffic,
                markers: _markers(),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                rotateGesturesEnabled: false,
                padding: EdgeInsets.only(
                    top: pad.top + 90, bottom: pad.bottom + 80),
              ),
            ),
          ),
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
                Expanded(child: _infoCard(mode)),
              ],
            ),
          ),
          if (!kHasGoogleMapsKey)
            Center(
              child: Card(
                margin: const EdgeInsets.all(32),
                child: const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Esta versión se compiló sin la clave de Google Maps, '
                    'así que el mapa puede verse en blanco.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
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
                        'Google ${_index + 1} de ${kGoogleMapModes.length}',
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

  Widget _infoCard(GoogleMapMode m) {
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
                    child: Text('Google Maps · ${m.name}',
                        style: t.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  Icon(_infoOpen ? Icons.expand_less : Icons.expand_more,
                      size: 20),
                ],
              ),
              if (_infoOpen) ...[
                const SizedBox(height: 4),
                Text(m.description, style: t.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  'Mapa en app móvil: ilimitado y gratis. Requiere clave de '
                  'Google Cloud con facturación activa.',
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
