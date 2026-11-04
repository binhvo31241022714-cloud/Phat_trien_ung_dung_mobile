import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PageBackground extends StatelessWidget {
  const PageBackground({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.pageGradient),
      child: SizedBox.expand(child: child));
}
