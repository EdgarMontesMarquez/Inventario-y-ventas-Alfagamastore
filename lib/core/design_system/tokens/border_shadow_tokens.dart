import 'package:flutter/material.dart';

/// Alfa Design Language 2.0 - Border & Shadow Tokens
/// Radios de curvatura modernos y amplios (Inspirados en las tarjetas de UI móvil de referencia).
class BorderShadowTokens {
  BorderShadowTokens._();

  // Radios de Borde Atómicos Redondeados
  static const double radiusXS = 6.0;
  static const double radiusSM = 10.0;
  static const double radiusMD = 14.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 28.0;
  static const double radiusPill = 9999.0;
  static const double radiusCircle = 50.0;

  // Elevaciones y Sombras Flotantes Suaves
  static List<BoxShadow> get shadowLevel0 => const [];

  static List<BoxShadow> get shadowLevel1 => const [
    BoxShadow(
      color: Color(0x0A000000), // ~4% opacidad flotante
      blurRadius: 10,
      offset: Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get shadowLevel2 => const [
    BoxShadow(
      color: Color(0x12000000), // ~7% opacidad
      blurRadius: 18,
      offset: Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get shadowLevel3 => const [
    BoxShadow(
      color: Color(0x1F000000), // ~12% opacidad para modales
      blurRadius: 28,
      offset: Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get shadowLevel4 => const [
    BoxShadow(
      color: Color(0x28000000),
      blurRadius: 36,
      offset: Offset(0, 14),
      spreadRadius: 0,
    ),
  ];

  // Elevaciones 3D Táctiles e Inmersivas (Subtítulos, bordes biselados y profundidad sutil)
  static List<BoxShadow> get shadow3DCard => const [
    BoxShadow(
      color: Color(0x0C003399), // Tono azul muy suave ambiental (5% opacidad)
      blurRadius: 16,
      offset: Offset(0, 6),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x0D0A192F), // Sombra de contacto inferior (5% opacidad)
      blurRadius: 4,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get shadow3DButton => const [
    BoxShadow(
      color: Color(0x330066FF), // Reflejo suave de botón azul primario
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x1A000000), // Borde táctil inferior 3D
      blurRadius: 2,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // Textura Inmersiva Táctil 3D (Efecto Claymorphism Suave y Elegante)
  static List<BoxShadow> get shadowClayCard => const [
    BoxShadow(
      color: Color(0xFFFFFFFF), // Brillo de bisel superior/izquierdo
      blurRadius: 6,
      offset: Offset(-3, -3),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x140A192F), // Sombra suave inferior de contacto (Clay)
      blurRadius: 12,
      offset: Offset(4, 6),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get shadowClayButton => const [
    BoxShadow(
      color: Color(0x400066FF),
      blurRadius: 10,
      offset: Offset(0, 5),
      spreadRadius: -1,
    ),
    BoxShadow(
      color: Color(0x200A192F),
      blurRadius: 2,
      offset: Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // Aliases de compatibilidad
  static const double radiusXs = radiusXS;
  static const double radiusSm = radiusSM;
  static const double radiusMd = radiusMD;
  static const double radiusLg = radiusLG;
  static const double radiusXl = radiusXL;
  static const double radiusRound = radiusXL;
  static const double radiusFull = radiusPill;

  static List<BoxShadow> get shadowLight => shadow3DCard;
  static List<BoxShadow> get shadowMedium => shadow3DButton;
  static List<BoxShadow> get shadowPrimary => shadow3DButton;
  static List<BoxShadow> get shadowSecondary => shadow3DCard;
}



