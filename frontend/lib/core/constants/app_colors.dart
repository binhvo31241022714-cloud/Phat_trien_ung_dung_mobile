import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF000675);
  static const primaryDark = Color(0xFF04044A);
  static const sky = Color(0xFF00A4FF);
  static const cyan = Color(0xFF00D2F5);
  static const accent = Color(0xFFEAF5FF);
  static const background = Color(0xFFF8FAFF);
  static const softBackground = Color(0xFFF0F7FF);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF26354A);
  static const textSecondary = Color(0xFF64748B);
  static const divider = Color(0xFFE2EAF3);
  static const activeBorder = Color(0xFF80CFFF);
  static const disabled = Color(0xFFE8EEF5);
  static const onDisabled = Color(0xFF94A3B8);

  // Preserve existing success/warning/error colors and their meanings.
  static const success = Color(0xFF248A5A);
  static const successBackground = Color(0xFFE8F6EE);
  static const warning = Color(0xFFAD6A00);
  static const warningBackground = Color(0xFFFFF4DD);
  static const error = Color(0xFFD32F2F);
  static const errorBackground = Color(0xFFFFECEB);
  static const info = Color(0xFF006BD6);
  static const infoBackground = Color(0xFFE5F2FF);

  static const selection = Color(0xFFDDF0FF);
  static const translucentSurface = Color(0xBFFFFFFF);

  // Compatibility for screens migrated in later batches: flat page background,
  // and blue selection fills under the existing token names. No module changes.
  static const pageGradient = LinearGradient(colors: [background, background]);
  static const glassPurple = Color(0xBFEAF5FF);
  static const glassPurpleStrong = selection;
}
