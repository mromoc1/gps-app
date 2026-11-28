import 'package:flutter/material.dart';

/// Paleta azul de la marca.
/// Azul principal: botones, íconos, barra de menú y vehículos en el mapa.
const Color kBrandBlue = Color(0xFF1D4ED8);

/// Azul profundo: fondo del logo y final del degradado.
const Color kBrandDeep = Color(0xFF0B2A6F);

/// Celeste de acento: detalles, zonas y punto del logo.
const Color kBrandAccent = Color(0xFF0EA5E9);
const Color kBrandSky = Color(0xFF38BDF8);

/// Azul más oscuro de los menús: barras superior e inferior y botón
/// desplegable del mapa.
const Color kMenuBlue = Color(0xFF1E40AF);

/// Texto e íconos secundarios sobre fondo azul (barras superior e inferior).
const Color kOnBlueMuted = Color(0xFFBFD0F7);

/// Degradado de la marca (logo e ícono de la app).
const LinearGradient kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2563EB), kBrandDeep],
);

/// Rojo de vehículo comprometido (marcador, etiqueta y botón de alerta).
const Color kCompromisedColor = Color(0xFFD32F2F);

/// Esquinas semicurvas, iguales en toda la app.
const double kRadiusButton = 10;
const double kRadiusCard = 12;
const double kRadiusSheet = 16;

RoundedRectangleBorder roundedShape(double r) =>
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

/// Logo de SIRV GPS (el mismo dibujo del ícono de la app: la S como camino
/// con un escudo). Fuente en assets/fuente/icono.svg.
class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.23);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: kBrandDeep.withValues(alpha: 0.25),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
