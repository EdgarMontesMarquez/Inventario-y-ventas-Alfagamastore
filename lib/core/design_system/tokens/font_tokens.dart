import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Alfa Design Language 2.0 - Font Tokens
/// Google Fonts Plus Jakarta Sans (Headings), Inter (UI/Body), JetBrains Mono (Finanzas/SKU).
class FontTokens {
  FontTokens._();

  static TextStyle get headingStyle => GoogleFonts.plusJakartaSans();
  static TextStyle get bodyStyle => GoogleFonts.inter();
  static TextStyle get monoStyle => GoogleFonts.jetBrainsMono();

  // Jerarquía Principal
  static TextStyle get h1 => headingStyle.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static TextStyle get h2 => headingStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.3,
  );

  static TextStyle get h3 => headingStyle.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static TextStyle get h4 => headingStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  // Cuerpo de Texto
  static TextStyle get bodyLarge => bodyStyle.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static TextStyle get bodyMedium => bodyStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static TextStyle get bodySmall => bodyStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static TextStyle get caption => bodyStyle.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static TextStyle get label => headingStyle.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static TextStyle get button => headingStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  static TextStyle get tableCell => bodyStyle.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  // Cifras Financieras y Monospaciado Tabular
  static TextStyle get metric => monoStyle.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static TextStyle get moneyLarge => monoStyle.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static TextStyle get moneyMedium => monoStyle.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.25,
  );

  static TextStyle get moneySmall => monoStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static TextStyle get monoCode => monoStyle.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.5,
  );

  // Compatibilidad
  static TextStyle get sans => bodyStyle;
  static TextStyle get mono => monoStyle;
}

