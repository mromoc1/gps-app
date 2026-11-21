/// Configuración general de la app.
library;

const String kAppName = 'GPS App';

/// Versión de la app. En GitHub Actions se inyectan con --dart-define:
/// APP_VERSION sale de pubspec.yaml y APP_BUILD es el número de compilación.
const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.3.0');
const String kAppBuild =
    String.fromEnvironment('APP_BUILD', defaultValue: 'local');
const String kAppCommit = String.fromEnvironment('APP_COMMIT');
const String kAppBuildDate = String.fromEnvironment('APP_BUILD_DATE');

/// Servidor Traccar (prototipo). En la versión final la app hablará con el
/// backend propio, no directamente con Traccar.
const String kServerUrl = 'https://gps.mromoc1.duckdns.org';

/// Teselas del mapa (OpenStreetMap).
const String kTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kUserAgentPackage = 'cl.gpsapp.gps_app';
