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

## 0.11.1 – 2026-11-27

- **Menús en azul más oscuro** (#1E40AF): barra superior del mapa, barra de
  menú inferior y botón desplegable.
- **Botón desplegable en azul**: las opciones (Ver todos, Zonas, Soporte) van
  en azul oscuro con texto blanco. El botón es azul oscuro cerrado y se pone
  blanco al abrirlo.

## 0.11.0 – 2026-11-27

- **Ícono nuevo de SIRV GPS**: la S dibujada como camino (blanco con línea
  central azul) que termina en un escudo celeste con check, sobre azul
  profundo. Ícono adaptativo de Android con la figura dentro de la zona
  segura, para que no se corte en celulares que lo recortan en círculo.
- El logo dentro de la app (inicio de sesión, barra superior del mapa,
  Perfil y pantalla de carga) usa el mismo dibujo.
- Los dibujos originales quedan en `assets/fuente/` (SVG).

## 0.10.2 – 2026-11-27

- **Barras azules**: la barra superior del mapa (nombre y conexión) y la barra
  de menú inferior pasan al azul de la marca (#1D4ED8), el mismo del botón
  desplegable. Texto e íconos en blanco; lo no elegido en celeste. El logo de
  la barra superior va sobre un cuadrado blanco.

## 0.10.1 – 2026-11-26

- **Nuevo nombre: SIRV GPS.** Cambia el nombre que se ve bajo el ícono del
  celular, en la pantalla de inicio de sesión, en Perfil, en el mensaje de
  soporte por WhatsApp y en los releases de GitHub. El identificador interno
  (`cl.gpsapp.gps_app`) se mantiene, así que se actualiza encima sin
  desinstalar y siguen funcionando Google Maps y las notificaciones.

## 0.10.0 – 2026-11-26

- **Soporte**: nueva opción en el botón desplegable del mapa que abre WhatsApp
  con un mensaje ya escrito para soporte (incluye el nombre o correo de la
  cuenta). El número y el nombre de la persona de soporte se leen del servidor
  de Traccar (atributos `soporteWhatsapp` y `soporteNombre`), así que se pueden
  cambiar sin publicar otra versión.
- Android: se declara que la app abre enlaces https (necesario en Android 11+).

## 0.9.1 – 2026-11-24

- **Nueva paleta azul**: azul intenso (#1D4ED8) en botones, íconos, barra de
  menú, interruptores y vehículos en el mapa; celeste (#0EA5E9) en los
  detalles, como las zonas y sus esquinas. Reemplaza al azul marino y al
  naranjo.
- **Logo e ícono de la app** con degradado azul y punto celeste. El ícono
  adaptativo de Android usa el mismo degradado de fondo.
- Los colores de aviso no cambian: verde (motor encendido), naranjo
  (reconectando, vence pronto) y rojo (comprometido, corte de motor).

## 0.9.0 – 2026-11-22

- **Vehículo comprometido**: en el panel del vehículo hay un botón con ícono
  de alerta a la derecha del nombre. Al tocarlo pregunta si se quiere marcar
  como vehículo comprometido (por ejemplo, robado). Marcado, el auto aparece
  en rojo en el mapa (encima de los demás), con la etiqueta "Comprometido" en
  la lista de Vehículos (primero en la lista) y un aviso en el panel con la
  fecha y quién lo marcó. El mismo botón ofrece "Marcar como recuperado".
- La marca se guarda en Traccar (atributos `comprometido`,
  `comprometidoDesde` y `comprometidoPor` del dispositivo), así que se ve en
  todos los celulares; la app revisa los vehículos cada minuto.

## 0.8.1 – 2026-11-22

- Al abrir el panel de un vehículo, el auto queda centrado en la parte del
  mapa que se ve sobre el panel (antes quedaba tapado por él).

## 0.8.0 – 2026-11-22

- **Panel del vehículo con alto fijo**: ya no se despliega a pantalla
  completa. El nombre, el estado y los botones Detalles, Eventos e Historial
  quedan siempre visibles arriba, y el corte de motor siempre visible abajo;
  solo se desplaza la sección del medio.
- **Eventos dentro del panel**: el botón Eventos muestra los eventos de los
  últimos 7 días en el mismo panel, sin cambiar de pantalla. Los nuevos
  aparecen en vivo.

## 0.7.0 – 2026-11-22

- **Todo el detalle del vehículo en un solo panel**: al tocar un vehículo en
  el mapa sube un panel; arrastrándolo hacia arriba muestra todos los datos,
  Historial, Eventos y el corte de motor. Ya no se abre otra pantalla.
- Con el panel abierto, el mapa principal se centra en el vehículo y lo va
  siguiendo; tocar el mapa cierra el panel.
- Elegir un vehículo en el panel Vehículos abre ese mismo panel sobre el mapa.

## 0.6.0 – 2026-11-22

- **Nombre de la persona** en la barra superior del mapa, junto al estado
  de conexión (en vez de "GPS App").
- **Botón desplegable** abajo a la derecha, sobre la barra de menú, con
  "Ver todos" y "Zonas". Se quitaron los botones sueltos de arriba.
- **Vehículos y Alertas** ahora suben como panel sobre el mapa, igual que al
  tocar un vehículo, en vez de abrir una página aparte.
- **Historial por viajes**: el día se separa en cada recorrido con su hora de
  salida y llegada, kilómetros, duración y velocidad máxima. Al tocar un
  viaje se ve solo esa ruta; "Todo el día" muestra el recorrido completo.
- Se quitó la sección "Construida con" del Perfil.

## 0.5.0 – 2026-11-22

- **Google Maps normal en todos los mapas** (mapa general, detalle del
  vehículo e historial). Se quitó la pantalla Probar mapas y OpenStreetMap.
- **Notificaciones push** con Firebase: llegan aunque la app esté cerrada.
  Nueva pantalla Perfil → Notificaciones para elegir cada alerta (alarmas,
  encendido y apagado, exceso de velocidad, zonas, movimiento, conexión) y
  enviar una prueba.
- **Zonas (geocercas)**: crear, editar y borrar círculos o polígonos
  tocando el mapa, y elegir qué vehículos vigila cada una. Se ven en el mapa.
- **Recuperar la clave por correo** desde "¿Olvidaste tu clave?".
- **Verificación en dos pasos** con Google Authenticator u otra app similar
  (código QR y clave manual).
- **Estado de la cuenta** en Perfil: activa, vence pronto o vencida.
- **Grupos de vehículos**: filtros en Vehículos, solo si hay varios vehículos
  agrupados.
- Requiere Android 7.0 o superior.

## 0.4.0 – 2026-11-22

- **Google Maps** en Probar mapas, con cinco vistas: Normal, Satélite,
  Híbrido, Relieve y Tráfico en vivo, todas con los vehículos encima.
- La clave de Google Maps se agrega al compilar desde el secreto
  `GOOGLE_MAPS_API_KEY`; está restringida a esta app y solo al mapa de Android.

## 0.3.0 – 2026-11-21

- Nueva pantalla **Probar mapas** (Perfil → Aplicación → Probar mapas):
  cada proveedor a pantalla completa con tus vehículos, con flechas para pasar
  de uno a otro y una ficha con sus condiciones de uso.
- Sin clave: OpenStreetMap, OpenTopoMap, CARTO (Voyager, Claro, Oscuro) y
  Esri (Satélite, Satélite con nombres, Calles).
- Con clave, que se ingresa dentro de la app: MapTiler (Calles, Satélite
  híbrido, Oscuro), Mapbox (Calles, Satélite con calles) y Stadia Maps
  (Alidade Smooth y Oscuro).
- Google Maps aparece listado; se probará en una versión aparte porque usa
  otra librería.

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
