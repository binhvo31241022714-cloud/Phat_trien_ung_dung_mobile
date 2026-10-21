import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'primary_button.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const ErrorState({
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Thử lại',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            PrimaryButton(
              label: retryLabel,
              onPressed: onRetry,
              isExpanded: false,
            ),
          ],
        ),
      ),
    );
  }
}
