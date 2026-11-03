import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isExpanded;

  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: Stack(alignment: Alignment.center, children: [
        Opacity(
            opacity: isLoading ? 0 : 1,
            child: icon == null
                ? Text(label, textAlign: TextAlign.center)
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon),
                    const SizedBox(width: 8),
                    Flexible(child: Text(label, textAlign: TextAlign.center))
                  ])),
        if (isLoading)
          const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
      ]),
    );
    return isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
