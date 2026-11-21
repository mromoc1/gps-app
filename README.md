# GPS App (prototipo)

App Flutter para clientes de la plataforma GPS. Esta primera versión se conecta
**directo a Traccar** (`https://gps.mromoc1.duckdns.org`) con un usuario cliente.
En la arquitectura final pasará por el backend propio.

## Funciones

- Login con usuario de Traccar (guarda un token de 1 año, no la clave).
- Mapa a pantalla completa con barra de navegación flotante
  (Mapa, Vehículos, Alertas, Perfil) y datos en vivo (WebSocket `/api/socket`).
- Detalle con mapa completo y panel deslizable: velocidad, motor, voltaje del
  auto, batería del GPS, satélites, señal, estado del corte y odómetro.
- Historial de recorrido por día con distancia y velocidad máxima.
- Alertas de todos los vehículos (últimos 3 días + en vivo) y eventos por vehículo.
- Perfil con cuenta, versión, compilación y tecnologías.
- Corte y reactivación de motor con doble confirmación
  (`engineStop` / `engineResume`).

No incluye todavía: notificaciones push con la app cerrada, pagos ni versión iPhone.

## Estructura

```
lib/
  main.dart            arranque, tema y pantalla inicial
  brand.dart           colores y logo
  config.dart          URL del servidor
  api.dart             cliente de Traccar y estado en vivo
  models.dart          Device, Position, TEvent
  util.dart            formatos y textos en español
  widgets.dart         marcadores y componentes
  screens/             login, inicio (pestañas), mapa, vehículos, alertas,
                       perfil, detalle, historial, eventos
tool/patch_android.py  permiso de internet y nombre de la app
.github/workflows/     compilación del APK en GitHub Actions
```

La carpeta `android/` no se guarda en el repo: la genera `flutter create`
en cada compilación.

## Versiones

Ver [CHANGELOG.md](CHANGELOG.md). La versión se cambia en `pubspec.yaml`;
el número de compilación lo asigna GitHub Actions.

## Construida con

Flutter y Dart · flutter_map con OpenStreetMap · http y web_socket_channel ·
shared_preferences · Traccar como servidor GPS.

## Compilar

Cada push a `main` compila el APK en GitHub Actions
(pestaña **Releases**, o **Actions → Compilar APK → Artifacts**).

Para que las actualizaciones se instalen encima de la versión anterior, el
secreto `DEBUG_KEYSTORE_B64` del repo debe tener siempre la misma llave de firma.

En local:

```
flutter create --org cl.gpsapp --project-name gps_app --platforms android .
python3 tool/patch_android.py
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```
