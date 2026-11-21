import 'package:shared_preferences/shared_preferences.dart';

/// Proveedores que necesitan clave de API.
enum MapKeyProvider { maptiler, mapbox, stadia }

extension MapKeyProviderInfo on MapKeyProvider {
  String get label {
    switch (this) {
      case MapKeyProvider.maptiler:
        return 'MapTiler';
      case MapKeyProvider.mapbox:
        return 'Mapbox';
      case MapKeyProvider.stadia:
        return 'Stadia Maps';
    }
  }

  String get signupUrl {
    switch (this) {
      case MapKeyProvider.maptiler:
        return 'https://cloud.maptiler.com/account/keys/';
      case MapKeyProvider.mapbox:
        return 'https://account.mapbox.com/access-tokens/';
      case MapKeyProvider.stadia:
        return 'https://client.stadiamaps.com/';
    }
  }

  String get _prefKey => 'mapkey_${name}';
}

/// Un estilo de mapa para probar.
class MapStyle {
  final String id;
  final String name;
  final String provider;
  final String description;
  final String urlTemplate; // {key} se reemplaza por la clave
  final List<String> subdomains;
  final String? overlayUrl; // capa de nombres sobre el satélite
  final int maxZoom;
  final String attribution;
  final MapKeyProvider? keyProvider;
  final String terms;

  const MapStyle({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    required this.urlTemplate,
    required this.attribution,
    required this.terms,
    this.subdomains = const [],
    this.overlayUrl,
    this.maxZoom = 19,
    this.keyProvider,
  });

  bool get needsKey => keyProvider != null;

  String resolve(String? key) => urlTemplate.replaceAll('{key}', key ?? '');
}

const String _esri = 'https://server.arcgisonline.com/ArcGIS/rest/services';

const List<MapStyle> kMapStyles = [
  // ---------------------------------------------------- OpenStreetMap
  MapStyle(
    id: 'osm',
    name: 'Estándar',
    provider: 'OpenStreetMap',
    description: 'El mapa que usa la app hoy.',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap',
    terms: 'Gratis, solo para uso liviano. No apto para app comercial con muchos usuarios.',
  ),
  MapStyle(
    id: 'opentopomap',
    name: 'Topográfico',
    provider: 'OpenTopoMap',
    description: 'Relieve y curvas de nivel. Útil en campo y cordillera.',
    urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    maxZoom: 17,
    attribution: '© OpenStreetMap · OpenTopoMap',
    terms: 'Gratis, uso liviano.',
  ),
  // ------------------------------------------------------------ CARTO
  MapStyle(
    id: 'carto-voyager',
    name: 'Voyager',
    provider: 'CARTO',
    description: 'Limpio y colorido; los autos se destacan bien.',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png',
    subdomains: ['a', 'b', 'c', 'd'],
    attribution: '© OpenStreetMap · © CARTO',
    terms: 'Gratis para pruebas; uso comercial requiere contrato con CARTO.',
  ),
  MapStyle(
    id: 'carto-light',
    name: 'Claro (Positron)',
    provider: 'CARTO',
    description: 'Muy claro y minimalista.',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}@2x.png',
    subdomains: ['a', 'b', 'c', 'd'],
    attribution: '© OpenStreetMap · © CARTO',
    terms: 'Gratis para pruebas; uso comercial requiere contrato con CARTO.',
  ),
  MapStyle(
    id: 'carto-dark',
    name: 'Oscuro (Dark Matter)',
    provider: 'CARTO',
    description: 'Fondo oscuro, ideal de noche.',
    urlTemplate:
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}@2x.png',
    subdomains: ['a', 'b', 'c', 'd'],
    attribution: '© OpenStreetMap · © CARTO',
    terms: 'Gratis para pruebas; uso comercial requiere contrato con CARTO.',
  ),
  // ------------------------------------------------------------- Esri
  MapStyle(
    id: 'esri-satellite',
    name: 'Satélite',
    provider: 'Esri',
    description: 'Imagen satelital de alta calidad.',
    urlTemplate: '$_esri/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Imágenes © Esri, Maxar, Earthstar',
    terms: 'Uso comercial requiere cuenta de ArcGIS.',
  ),
  MapStyle(
    id: 'esri-hybrid',
    name: 'Satélite con nombres',
    provider: 'Esri',
    description: 'Satélite con calles y lugares encima.',
    urlTemplate: '$_esri/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    overlayUrl:
        '$_esri/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    attribution: 'Imágenes © Esri, Maxar, Earthstar',
    terms: 'Uso comercial requiere cuenta de ArcGIS.',
  ),
  MapStyle(
    id: 'esri-streets',
    name: 'Calles',
    provider: 'Esri',
    description: 'Mapa de calles estilo clásico.',
    urlTemplate: '$_esri/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
    attribution: '© Esri',
    terms: 'Uso comercial requiere cuenta de ArcGIS.',
  ),
  // --------------------------------------------------------- MapTiler
  MapStyle(
    id: 'maptiler-streets',
    name: 'Calles',
    provider: 'MapTiler',
    description: 'Calles detalladas en español.',
    urlTemplate:
        'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}@2x.png?key={key}',
    attribution: '© MapTiler © OpenStreetMap',
    keyProvider: MapKeyProvider.maptiler,
    terms: 'Plan gratuito para partir; planes pagados al crecer.',
  ),
  MapStyle(
    id: 'maptiler-satellite',
    name: 'Satélite híbrido',
    provider: 'MapTiler',
    description: 'Satélite con calles y nombres.',
    urlTemplate:
        'https://api.maptiler.com/maps/hybrid/256/{z}/{x}/{y}@2x.jpg?key={key}',
    attribution: '© MapTiler © OpenStreetMap',
    keyProvider: MapKeyProvider.maptiler,
    terms: 'Plan gratuito para partir; planes pagados al crecer.',
  ),
  MapStyle(
    id: 'maptiler-dark',
    name: 'Oscuro',
    provider: 'MapTiler',
    description: 'Estilo oscuro.',
    urlTemplate:
        'https://api.maptiler.com/maps/streets-v2-dark/256/{z}/{x}/{y}@2x.png?key={key}',
    attribution: '© MapTiler © OpenStreetMap',
    keyProvider: MapKeyProvider.maptiler,
    terms: 'Plan gratuito para partir; planes pagados al crecer.',
  ),
  // ----------------------------------------------------------- Mapbox
  MapStyle(
    id: 'mapbox-streets',
    name: 'Calles',
    provider: 'Mapbox',
    description: 'Estilo Streets de Mapbox.',
    urlTemplate:
        'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={key}',
    attribution: '© Mapbox © OpenStreetMap',
    keyProvider: MapKeyProvider.mapbox,
    terms: 'Plan gratuito; se cobra por uso al crecer.',
  ),
  MapStyle(
    id: 'mapbox-satellite',
    name: 'Satélite con calles',
    provider: 'Mapbox',
    description: 'Satélite con calles y nombres.',
    urlTemplate:
        'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={key}',
    attribution: '© Mapbox © OpenStreetMap © Maxar',
    keyProvider: MapKeyProvider.mapbox,
    terms: 'Plan gratuito; se cobra por uso al crecer.',
  ),
  // ----------------------------------------------------------- Stadia
  MapStyle(
    id: 'stadia-smooth',
    name: 'Alidade Smooth',
    provider: 'Stadia Maps',
    description: 'Suave y legible.',
    urlTemplate:
        'https://tiles.stadiamaps.com/tiles/alidade_smooth/{z}/{x}/{y}@2x.png?api_key={key}',
    attribution: '© Stadia Maps © OpenMapTiles © OpenStreetMap',
    keyProvider: MapKeyProvider.stadia,
    terms: 'Plan gratuito para desarrollo; pagado para uso comercial.',
  ),
  MapStyle(
    id: 'stadia-dark',
    name: 'Alidade Oscuro',
    provider: 'Stadia Maps',
    description: 'Versión oscura.',
    urlTemplate:
        'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}@2x.png?api_key={key}',
    attribution: '© Stadia Maps © OpenMapTiles © OpenStreetMap',
    keyProvider: MapKeyProvider.stadia,
    terms: 'Plan gratuito para desarrollo; pagado para uso comercial.',
  ),
];

/// Claves de los proveedores, guardadas en el teléfono.
class MapKeys {
  static Future<String?> get(MapKeyProvider p) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(p._prefKey);
    return (v == null || v.trim().isEmpty) ? null : v.trim();
  }

  static Future<void> set(MapKeyProvider p, String? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null || value.trim().isEmpty) {
      await prefs.remove(p._prefKey);
    } else {
      await prefs.setString(p._prefKey, value.trim());
    }
  }

  static Future<Map<MapKeyProvider, String>> all() async {
    final out = <MapKeyProvider, String>{};
    for (final p in MapKeyProvider.values) {
      final k = await get(p);
      if (k != null) out[p] = k;
    }
    return out;
  }
}
