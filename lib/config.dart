/// Configuración general de la app.
library;

const String kAppName = 'Alerto GPS';

/// Servidor Traccar (prototipo). En la versión final la app hablará con el
/// backend propio, no directamente con Traccar.
const String kServerUrl = 'https://gps.mromoc1.duckdns.org';

/// Teselas del mapa (OpenStreetMap).
const String kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kUserAgentPackage = 'cl.alerto.alerto_gps';
