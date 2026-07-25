import 'package:flutter/material.dart';
import '../design_system/tokens/color_tokens.dart';
import '../design_system/tokens/font_tokens.dart';
import '../design_system/tokens/border_shadow_tokens.dart';

/// Alfa Design Language 2.0 - Theme Provider
/// Define el tema 100% Claro con Azul Eléctrico y tarjetas flotantes blancas.
class AppTheme {
  AppTheme._();

  // ==========================================
  // LIGHT THEME (CONFIGURACIÓN PRINCIPAL EXCLUSIVA)
  // ==========================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ColorTokens.lightBgPrimary,

      colorScheme: const ColorScheme.light(
        primary: ColorTokens.lightBrandPrimary,
        secondary: ColorTokens.lightBrandSecondary,
        error: ColorTokens.statusDanger,
        surface: ColorTokens.lightSurfacePrimary,
        onPrimary: ColorTokens.lightTextInverse,
        onSecondary: ColorTokens.lightTextInverse,
        onError: Colors.white,
        onSurface: ColorTokens.lightTextPrimary,
      ),

      textTheme: TextTheme(
        headlineLarge: FontTokens.h1.copyWith(color: ColorTokens.lightTextPrimary),
        headlineMedium: FontTokens.h2.copyWith(color: ColorTokens.lightTextPrimary),
        headlineSmall: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary),
        bodyLarge: FontTokens.bodyLarge.copyWith(color: ColorTokens.lightTextPrimary),
        bodyMedium: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextSecondary),
        bodySmall: FontTokens.bodySmall.copyWith(color: ColorTokens.lightTextSecondary),
      ),

      cardTheme: CardThemeData(
        color: ColorTokens.lightSurfacePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(BorderShadowTokens.radiusLG),
          side: const BorderSide(color: ColorTokens.lightBorderSubtle, width: 1.0),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: ColorTokens.lightBorderSubtle,
        thickness: 1.0,
        space: 1.0,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: ColorTokens.lightBgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: ColorTokens.lightTextPrimary),
        titleTextStyle: FontTokens.h3.copyWith(color: ColorTokens.lightTextPrimary),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ColorTokens.lightSurfacePrimary,
        selectedItemColor: ColorTokens.lightBrandPrimary,
        unselectedItemColor: ColorTokens.lightTextDisabled,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: ColorTokens.lightBrandPrimary,
        foregroundColor: ColorTokens.lightTextInverse,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(BorderShadowTokens.radiusPill),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColorTokens.lightSurfacePrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BorderShadowTokens.radiusMD),
          borderSide: const BorderSide(color: ColorTokens.lightBorderSubtle, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BorderShadowTokens.radiusMD),
          borderSide: const BorderSide(color: ColorTokens.lightBorderSubtle, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BorderShadowTokens.radiusMD),
          borderSide: const BorderSide(color: ColorTokens.lightBorderFocus, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BorderShadowTokens.radiusMD),
          borderSide: const BorderSide(color: ColorTokens.statusDanger, width: 1.8),
        ),
        labelStyle: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextSecondary),
        hintStyle: FontTokens.bodyMedium.copyWith(color: ColorTokens.lightTextDisabled),
      ),
    );
  }

  // Enfoque 100% Claro: darkTheme retorna exactamente la configuración de LightTheme
  static ThemeData get darkTheme => lightTheme;
}


