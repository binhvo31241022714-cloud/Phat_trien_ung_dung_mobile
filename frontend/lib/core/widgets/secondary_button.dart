import 'package:flutter/material.dart';

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isExpanded;

  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isExpanded = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: icon == null
          ? Text(label)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(label),
              ],
            ),
    );
    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
