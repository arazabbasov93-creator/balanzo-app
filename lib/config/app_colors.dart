import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // PRIMARY BRAND GREEN
  static const Color primaryGreenDark = Color(0xFF1B5E20);
  static const Color primaryGreenLight = Color(0xFF2D7A45);

  // GRADIENT SECONDARY GREEN
  static const Color gradientEndDark = Color(0xFF2E7D32);
  static const Color gradientEndLight = Color(0xFF3D8F55);

  // SCAFFOLD BACKGROUNDS
  static const Color scaffoldDark = Color(0xFF09090B);
  static const Color scaffoldLight = Color(0xFFF8F8F6);

  // CARD / SURFACE BACKGROUNDS
  static const Color cardDark = Color(0xFF111113);
  static const Color cardLight = Color(0xFFF0F0EE);

  // ELEVATED SURFACE
  static const Color surfaceHighDark = Color(0xFF18181C);
  static const Color surfaceHighLight = Color(0xFFE8EBE8);

  // LIGHT TINT SURFACES
  static const Color tintSurfaceDark = Color(0xFF1E2F1E);
  static const Color tintSurfaceLight = Color(0xFFEDF5EE);

  // SECONDARY GREENS
  static const Color green400 = Color(0xFF4CAF50);
  static const Color green300 = Color(0xFF81C784);
  static const Color green100 = Color(0xFFE8F5E9);

  // DARK MODE SURFACE PALETTE
  static const Color darkSurface = Color(0xFF09090B);
  static const Color darkCard = Color(0xFF111113);
  static const Color darkElevated = Color(0xFF18181C);
  static const Color darkOutline = Color(0xFF2C2C34);
  static const Color darkOnSurface = Color(0xFFF2F2F5);
  static const Color darkOnSurfaceVariant = Color(0xFF8888A0);

  // LIGHT MODE SURFACE PALETTE
  static const Color lightSurface = Color(0xFFF8F8F6);
  static const Color lightCard = Color(0xFFF0F0EE);
  static const Color lightOutline = Color(0xFFDDDDDD);
  static const Color lightOnSurface = Color(0xFF1A1A1A);
  static const Color lightOnSurfaceVariant = Color(0xFF555566);

  // SEMANTIC
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFFA000);
  static const Color info = Color(0xFF1976D2);

  // HELPERS
  static Color primaryGreen(Brightness brightness) =>
      brightness == Brightness.dark ? primaryGreenDark : primaryGreenLight;

  static Color gradientEnd(Brightness brightness) =>
      brightness == Brightness.dark ? gradientEndDark : gradientEndLight;

  static Color scaffold(Brightness brightness) =>
      brightness == Brightness.dark ? scaffoldDark : scaffoldLight;

  static Color card(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : cardLight;

  static Color tintSurface(Brightness brightness) =>
      brightness == Brightness.dark ? tintSurfaceDark : tintSurfaceLight;
}
