import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const headline = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  static const title = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const subtitle = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  static const body = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 12.5,
    height: 1.4,
  );

  static const caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 10.5,
    height: 1.4,
  );

  static const button = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );
}
