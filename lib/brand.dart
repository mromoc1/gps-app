import 'package:flutter/material.dart';

const Color kBrandNavy = Color(0xFF12355B);
const Color kBrandOrange = Color(0xFFF28C28);

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
        color: kBrandNavy,
        borderRadius: BorderRadius.circular(size * 0.28),
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
                color: kBrandOrange,
                shape: BoxShape.circle,
                border: Border.all(color: kBrandNavy, width: size * 0.03),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
