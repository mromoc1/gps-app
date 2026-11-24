import 'package:flutter/material.dart';

/// Paleta azul de la marca.
/// Azul principal: botones, íconos, barra de menú y vehículos en el mapa.
const Color kBrandBlue = Color(0xFF1D4ED8);

/// Azul profundo: fondo del logo y final del degradado.
const Color kBrandDeep = Color(0xFF0B2A6F);

/// Celeste de acento: detalles, zonas y punto del logo.
const Color kBrandAccent = Color(0xFF0EA5E9);
const Color kBrandSky = Color(0xFF38BDF8);

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

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: kBrandBlue.withValues(alpha: 0.25),
            blurRadius: size * 0.12,
            offset: Offset(0, size * 0.04),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.location_on, color: Colors.white, size: size * 0.6),
          Positioned(
            right: size * 0.18,
            top: size * 0.16,
            child: Container(
              width: size * 0.2,
              height: size * 0.2,
              decoration: BoxDecoration(
                color: kBrandSky,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E40AF), width: size * 0.03),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
