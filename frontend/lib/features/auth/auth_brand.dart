import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class AuthBrand extends StatelessWidget {
  const AuthBrand({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(children: [
        const CircleAvatar(
            radius: 42,
            backgroundColor: AppColors.accent,
            child: Icon(Icons.medical_services_rounded,
                size: 42, color: AppColors.sky)),
        const SizedBox(height: 16),
        const Text('YourSmile Dental',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary)),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.headline),
        const SizedBox(height: 8),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
      ]);
}
