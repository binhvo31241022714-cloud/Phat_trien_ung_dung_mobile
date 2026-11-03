import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';

/// Presentation only: reading, filtering and destinations stay with the caller.
class NotificationCard extends StatelessWidget {
  const NotificationCard(
      {required this.isRead, required this.child, this.onTap, super.key});
  final bool isRead;
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.cardGap),
      child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              border: Border.all(
                  color: isRead ? AppColors.divider : AppColors.activeBorder,
                  width: isRead ? 1 : 1.5)),
          child: AppCard(onTap: onTap, child: child)));
}

class NotificationFilterChip extends StatelessWidget {
  const NotificationFilterChip(
      {required this.label,
      required this.selected,
      required this.onSelected,
      super.key});
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: true,
        checkmarkColor: AppColors.primary,
        selectedColor: AppColors.accent,
        backgroundColor: AppColors.surface,
        side: BorderSide(
            color: selected ? AppColors.activeBorder : AppColors.divider),
        labelStyle: TextStyle(
            color: selected ? AppColors.primaryDark : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );
}
