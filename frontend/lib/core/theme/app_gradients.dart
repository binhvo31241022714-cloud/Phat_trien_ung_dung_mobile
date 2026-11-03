import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Only for prominent hero/banner surfaces, never a default page background.
abstract final class AppGradients {
  static const hero = LinearGradient(
    colors: [AppColors.primaryDark, Color(0xFF006AEF), AppColors.cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
