import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum StatusTone { neutral, info, success, warning, error }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusTone tone;

  const StatusChip({
    required this.label,
    this.tone = StatusTone.neutral,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (tone) {
      StatusTone.neutral => (AppColors.textSecondary, AppColors.background),
      StatusTone.info => (AppColors.primaryDark, AppColors.accent),
      StatusTone.success => (AppColors.success, AppColors.successBackground),
      StatusTone.warning => (AppColors.warning, AppColors.warningBackground),
      StatusTone.error => (AppColors.error, AppColors.errorBackground),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
