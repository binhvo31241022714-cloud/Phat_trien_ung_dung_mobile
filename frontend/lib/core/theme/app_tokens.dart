import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Shared presentation dimensions. Text-bearing controls use minimum heights.
abstract final class AppTokens {
  static const spaceSmall = 8.0;
  static const spaceMedium = 12.0;
  static const pagePadding = 16.0;
  static const sectionGap = 24.0;
  static const cardGap = 12.0;
  static const controlHeight = 48.0;
  static const radius = 16.0;
  static const cardRadius = 18.0;
  static const iconSize = 20.0;
  static const pageInsets = EdgeInsets.all(pagePadding);
  // Leave room for the existing floating bottom navigation and safe scrolling.
  static const scrollInsets =
      EdgeInsets.fromLTRB(pagePadding, pagePadding, pagePadding, 96);
  static const cardShadow =
      BoxShadow(color: Color(0x0C26354A), blurRadius: 12, offset: Offset(0, 4));
  static BoxDecoration cardDecoration({bool selected = false}) => BoxDecoration(
        color: selected ? AppColors.accent : AppColors.surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(
            color: selected ? AppColors.activeBorder : AppColors.divider),
        boxShadow: const [cardShadow],
      );
}
