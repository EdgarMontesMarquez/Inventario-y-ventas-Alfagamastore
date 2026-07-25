import 'package:flutter/material.dart';

/// Alfa Design Language 2.0 - Color Tokens
/// 100% Light Mode Only System (Inspirado en el diseño limpio Azul Eléctrico & Blanco)
class ColorTokens {
  ColorTokens._();

  // ==========================================
  // LIGHT THEME TOKENS (SISTEMA 100% CLARO EXCLUSIVO)
  // ==========================================
  static const Color lightBgPrimary = Color(0xFFF4F7FF); // Azul hielo polvo muy suave
  static const Color lightBgSecondary = Color(0xFFEBF2FF); // Azul claro secundario
  static const Color lightBgTertiary = Color(0xFFE2ECFF);

  static const Color lightSurfacePrimary = Color(0xFFFFFFFF); // Blanco brillante para tarjetas
  static const Color lightSurfaceSecondary = Color(0xFFF8FAFC);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceOverlay = Color(0xFFFFFFFF);

  static const Color lightBorderSubtle = Color(0xFFE2E8F0);
  static const Color lightBorderStrong = Color(0xFFCBD5E1);
  static const Color lightBorderFocus = Color(0xFF0066FF);

  static const Color lightTextPrimary = Color(0xFF0A192F); // Azul Noche Oscuro (Alto contraste AAA)
  static const Color lightTextSecondary = Color(0xFF475569); // Slate Grey
  static const Color lightTextDisabled = Color(0xFF94A3B8);
  static const Color lightTextInverse = Color(0xFFFFFFFF);
  static const Color lightTextLink = Color(0xFF0066FF);

  static const Color lightBrandPrimary = Color(0xFF0066FF); // Azul Eléctrico Vibrante
  static const Color lightBrandPrimaryHover = Color(0xFF0052CC);
  static const Color lightBrandSecondary = Color(0xFF10B981); // Verde Esmeralda
  static const Color lightBrandLight = Color(0xFFE6F0FF);

  // ==========================================
  // REDIRECCIÓN DIRECTA PARA MODO CLARO UNIFICADO
  // ==========================================
  static const Color darkBgPrimary = lightBgPrimary;
  static const Color darkBgSecondary = lightBgSecondary;
  static const Color darkBgTertiary = lightBgTertiary;

  static const Color darkSurfacePrimary = lightSurfacePrimary;
  static const Color darkSurfaceSecondary = lightSurfaceSecondary;
  static const Color darkSurfaceElevated = lightSurfaceElevated;
  static const Color darkSurfaceOverlay = lightSurfaceOverlay;

  static const Color darkBorderSubtle = lightBorderSubtle;
  static const Color darkBorderStrong = lightBorderStrong;
  static const Color darkBorderFocus = lightBorderFocus;

  static const Color darkTextPrimary = lightTextPrimary;
  static const Color darkTextSecondary = lightTextSecondary;
  static const Color darkTextDisabled = lightTextDisabled;
  static const Color darkTextInverse = lightTextInverse;
  static const Color darkTextLink = lightTextLink;

  static const Color darkBrandPrimary = lightBrandPrimary;
  static const Color darkBrandPrimaryHover = lightBrandPrimaryHover;
  static const Color darkBrandSecondary = lightBrandSecondary;

  // ==========================================
  // ESTADOS Y ALERTAS SEMÁNTICAS (VIBRANTES Y NÍTIDAS)
  // ==========================================
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusSuccessDim = Color(0xFFE6F7F0);

  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusWarningDim = Color(0xFFFFFBEB);

  static const Color statusDanger = Color(0xFFEF4444);
  static const Color statusDangerDim = Color(0xFFFEE2E2);

  static const Color statusInfo = Color(0xFF0066FF);
  static const Color statusInfoDim = Color(0xFFE6F0FF);

  static const Color statusNeutral = Color(0xFF64748B);
  static const Color statusNeutralDim = Color(0xFFF1F5F9);

  // ==========================================
  // PALETA EXCLUSIVA DE GRÁFICAS Y CATEGORÍAS
  // ==========================================
  static const Color chart1 = Color(0xFF0066FF); // Azul Eléctrico
  static const Color chart2 = Color(0xFFF59E0B); // Amarillo Dorado
  static const Color chart3 = Color(0xFF10B981); // Verde Esmeralda
  static const Color chart4 = Color(0xFFEF4444); // Coral Red
  static const Color chart5 = Color(0xFF2A2B68); // Púrpura Índigo
  static const Color chart6 = Color(0xFF6366F1); // Violeta
  static const Color chart7 = Color(0xFF06B6D4); // Cyan
  static const Color chart8 = Color(0xFFEC4899); // Rosa
  static const Color chart9 = Color(0xFF8B5CF6); // Púrpura
  static const Color chart10 = Color(0xFFF97316); // Naranja
  static const Color chart11 = Color(0xFF14B8A6); // Turquesa
  static const Color chart12 = Color(0xFF475569); // Slate

  // ==========================================
  // COMPATIBILIDAD CON CÓDIGO EXISTENTE (ALIASES MODO CLARO)
  // ==========================================
  static const Color background = lightBgPrimary;
  static const Color surface = lightSurfacePrimary;
  static const Color surfaceElevated = lightSurfaceSecondary;
  static const Color surfaceVariant = lightBgSecondary;

  static const Color border = lightBorderSubtle;
  static const Color borderBright = lightBorderStrong;

  static const Color primary = lightBrandPrimary;
  static const Color primaryDim = lightBrandLight;

  static const Color secondary = statusSuccess;
  static const Color secondaryDim = statusSuccessDim;

  static const Color warning = statusWarning;
  static const Color warningDim = statusWarningDim;

  static const Color error = statusDanger;
  static const Color errorDim = statusDangerDim;

  static const Color text = lightTextPrimary;
  static const Color textMuted = lightTextSecondary;
  static const Color textDim = lightTextDisabled;
  static const Color textOnPrimary = lightTextInverse;
  static const Color textOnSecondary = lightTextInverse;
}


