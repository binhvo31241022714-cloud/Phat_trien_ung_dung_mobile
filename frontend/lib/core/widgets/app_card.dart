import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const AppCard(
      {required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap,
      super.key});
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: AppTokens.cardDecoration(),
      child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.cardRadius),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              child: Padding(padding: padding, child: child))));
}
