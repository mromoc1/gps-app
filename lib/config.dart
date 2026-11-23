/// Configuración general de la app.
library;

const String kAppName = 'GPS App';

/// Versión de la app. En GitHub Actions se inyectan con --dart-define:
/// APP_VERSION sale de pubspec.yaml y APP_BUILD es el número de compilación.
const String kAppVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '0.10.0');
const String kAppBuild =
    String.fromEnvironment('APP_BUILD', defaultValue: 'local');
const String kAppCommit = String.fromEnvironment('APP_COMMIT');
const String kAppBuildDate = String.fromEnvironment('APP_BUILD_DATE');

/// true cuando la compilación incluyó la clave de Google Maps.
const bool kHasGoogleMapsKey = bool.fromEnvironment('HAS_GOOGLE_MAPS_KEY');

/// Servidor Traccar (prototipo). En la versión final la app hablará con el
/// backend propio, no directamente con Traccar.
const String kServerUrl = 'https://gps.mromoc1.duckdns.org';

/// Firebase (notificaciones push). Son datos de configuración del cliente,
/// no secretos: van dentro de toda app que usa Firebase.
const String kFirebaseApiKey = 'AIzaSyDpJcu2WT2Oq1j3CN0gdL3eXZL6SL5BFEs';
const String kFirebaseAppId = '1:392670200010:android:0cca9b5a3e4c87b5a07433';
const String kFirebaseSenderId = '392670200010';
const String kFirebaseProjectId = 'gps-app-515500';
