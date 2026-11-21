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
tool/                  preparar Android, firma, versión y notas de release
.github/workflows/     release.yml (publicar) y ci.yml (revisión)
.github/ISSUE_TEMPLATE plantillas de fallas y mejoras
```

La carpeta `android/` no se guarda en el repo: la genera `flutter create`
en cada compilación.

## Versiones

Ver [CHANGELOG.md](CHANGELOG.md). La versión se cambia en `pubspec.yaml`;
el número de compilación lo asigna GitHub Actions.

## Construida con

Flutter y Dart · flutter_map con OpenStreetMap · http y web_socket_channel ·
shared_preferences · Traccar como servidor GPS.

## Descargar

Enlace fijo a la última versión (requiere sesión de GitHub con acceso al repo):

**https://github.com/mromoc1/gps-app/releases/latest/download/gps-app.apk**

<img src="docs/descarga-qr.png" alt="QR de descarga" width="180">

Todas las versiones, con sus notas, checksum y firma, están en
[Releases](https://github.com/mromoc1/gps-app/releases). Se guardan las últimas 10.

## Cómo publicar una versión

1. Trabaja en una rama y abre un pull request: la **Revisión** automática
   analiza el código, revisa el CHANGELOG y deja un APK de prueba en Checks.
2. Sube la versión en `pubspec.yaml` (`version: X.Y.Z+1`).
3. Agrega la sección `## X.Y.Z – fecha` en `CHANGELOG.md`.
4. Une a `main`. **Publicar versión** compila, firma, arma las notas
   (novedades del CHANGELOG + commits) y publica el release con:
   - `gps-app-vX.Y.Z-bN.apk` (versión exacta)
   - `gps-app.apk` (el del enlace fijo)
   - `.sha256` (checksum)

También se puede lanzar a mano desde **Actions → Publicar versión → Run workflow**.

## Firma

El APK se firma con la llave oficial guardada en los secretos del repo:

| Secreto | Contenido |
| --- | --- |
| `ANDROID_KEYSTORE_B64` | La llave `gps-app-release.jks` en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | La clave de la llave |

Sin esos secretos el APK sale con firma de depuración y el release lo indica.
**Guarda una copia de la llave y su clave fuera de GitHub**: si se pierde,
no se podrán publicar actualizaciones en Google Play con la misma app.

## Reportar fallas

En **Issues → New issue** hay plantillas para reportar una falla o sugerir una mejora.

## Compilar en local

```
./tool/prepare_android.sh
flutter build apk --release
```
