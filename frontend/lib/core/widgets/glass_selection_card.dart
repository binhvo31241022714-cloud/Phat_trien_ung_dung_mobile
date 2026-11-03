import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_tokens.dart';

/// A bounded blur for the few related options on detail pages, not list cards.
class GlassSelectionCard extends StatelessWidget {
  const GlassSelectionCard({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.cardGap),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(AppTokens.radius),
                      border: Border.all(color: AppColors.divider),
                      boxShadow: const [AppTokens.cardShadow]),
                  child: Material(
                      color: Colors.transparent,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: child))))));
}
