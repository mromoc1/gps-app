# Cambios

El número de versión sigue el formato `MAYOR.MENOR.PARCHE`
(versionado semántico). Se cambia a mano en `pubspec.yaml`:

- **MAYOR**: cambios grandes o incompatibles (por ejemplo, pasar del prototipo al backend propio).
- **MENOR**: funciones nuevas.
- **PARCHE**: correcciones.

El **número de compilación** lo pone GitHub Actions solo (`github.run_number`)
y sube en cada compilación. Cada APK publicado se etiqueta como
`v<versión>-b<compilación>`, por ejemplo `v0.2.0-b3`.

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
