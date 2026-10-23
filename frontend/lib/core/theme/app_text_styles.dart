import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const headline = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const subtitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    height: 1.5,
  );

  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    height: 1.4,
  );

  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}
