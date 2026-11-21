# Cambios

El número de versión sigue el formato `MAYOR.MENOR.PARCHE`
(versionado semántico). Se cambia a mano en `pubspec.yaml`:

- **MAYOR**: cambios grandes o incompatibles (por ejemplo, pasar del prototipo al backend propio).
- **MENOR**: funciones nuevas.
- **PARCHE**: correcciones.

El **número de compilación** lo pone GitHub Actions solo (`github.run_number`)
y sube en cada compilación. Cada APK publicado se etiqueta como
`v<versión>-b<compilación>`, por ejemplo `v0.2.1-b4`.

Cada versión necesita su sección `## X.Y.Z` en este archivo: sin ella la
compilación falla. El texto de la sección aparece como "Novedades" en el release.

## 0.2.2 – 2026-11-21

- Diseño: botones, tarjetas, barra de navegación, menús, diálogos y paneles
  con esquinas semicurvas (antes algunos eran completamente redondos).
- Los botones del mapa pasan de círculos a cuadrados con esquinas suaves.
- Los avisos aparecen flotando sobre la barra inferior.

## 0.2.1 – 2026-11-21

- Publicación oficial: cada versión queda en Releases con notas de cambios,
  checksum SHA-256 y huella de la firma.
- Enlace fijo que siempre descarga la última versión:
  `https://github.com/mromoc1/gps-app/releases/latest/download/gps-app.apk`
- Firma oficial de la app: desde esta versión las actualizaciones se instalan
  encima de la anterior. Hay que desinstalar una última vez la 0.2.0.
- Revisión automática en ramas y pull requests, sin publicar.
- Plantillas para reportar fallas y sugerir mejoras.

## 0.2.0 – 2026-11-21

- Nombre de la app: **GPS App** (antes Alerto GPS). Nuevo identificador
  `cl.gpsapp.gps_app`: hay que desinstalar la versión anterior.
- Mapa a pantalla completa con barra de navegación flotante:
  Mapa, Vehículos, Alertas y Perfil.
- Al tocar un vehículo en el mapa se abre un resumen con acceso al detalle
  y al historial.
- Detalle del vehículo con mapa completo y panel deslizable.
- Nueva pestaña Alertas con los eventos de todos los vehículos de los
  últimos 3 días y los que llegan en vivo.
- Nueva pestaña Perfil: cuenta, conexión, versión y compilación,
  licencias y tecnologías con que está construida.
- Versionado automático en las compilaciones.

## 0.1.x – 2026-11-21

- Primer prototipo (Alerto GPS): login con token, mapa en vivo, detalle,
  historial, eventos y corte de motor con doble confirmación.
