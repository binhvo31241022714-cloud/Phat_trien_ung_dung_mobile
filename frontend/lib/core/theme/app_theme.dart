import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'app_text_styles.dart';
import 'app_tokens.dart';

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.accent,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.sky,
        onSecondary: AppColors.primaryDark,
        secondaryContainer: AppColors.accent,
        onSecondaryContainer: AppColors.primaryDark,
        surface: AppColors.surface,
        error: AppColors.error,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.divider,
        outlineVariant: AppColors.divider);
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius));
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius),
            borderSide: BorderSide(color: color, width: width));
    final primaryStyle = FilledButton.styleFrom(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        overlayColor: Colors.white.withValues(alpha: .12),
        disabledBackgroundColor: AppColors.disabled,
        disabledForegroundColor: AppColors.onDisabled,
        minimumSize: const Size(0, AppTokens.controlHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: shape,
        textStyle: AppTextStyles.button);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      visualDensity: VisualDensity.standard,
      textTheme: const TextTheme(
          headlineMedium: AppTextStyles.headline,
          headlineSmall: AppTextStyles.pageTitle,
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.subtitle,
          bodyLarge: AppTextStyles.body,
          bodyMedium: AppTextStyles.body,
          bodySmall: AppTextStyles.caption,
          labelLarge: AppTextStyles.button),
      appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: AppTextStyles.pageTitle),
      cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.cardRadius),
              side: const BorderSide(color: AppColors.divider))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: border(AppColors.divider),
          enabledBorder: border(AppColors.divider),
          focusedBorder: border(AppColors.activeBorder, 1.5),
          errorBorder: border(AppColors.error),
          focusedErrorBorder: border(AppColors.error, 1.5),
          disabledBorder: border(AppColors.disabled),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          hintStyle: const TextStyle(color: AppColors.textSecondary),
          errorMaxLines: 3,
          helperMaxLines: 3,
          prefixIconColor: AppColors.primary,
          suffixIconColor: AppColors.textSecondary),
      filledButtonTheme: FilledButtonThemeData(style: primaryStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppTokens.controlHeight),
              foregroundColor: AppColors.primary,
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.activeBorder),
              shape: shape,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              textStyle: AppTextStyles.button)),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: AppTextStyles.button)),
      iconTheme: const IconThemeData(
          color: AppColors.primary, size: AppTokens.iconSize),
      listTileTheme: const ListTileThemeData(
          iconColor: AppColors.primary,
          textColor: AppColors.textPrimary,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
      chipTheme: ChipThemeData(
          backgroundColor: AppColors.accent,
          selectedColor: AppColors.selection,
          side: BorderSide.none,
          labelStyle:
              AppTextStyles.caption.copyWith(color: AppColors.primaryDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: shape,
          titleTextStyle: AppTextStyles.title,
          contentTextStyle: AppTextStyles.body),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.softBackground,
          surfaceTintColor: Colors.transparent,
          showDragHandle: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primaryDark,
          shape: shape),
      dividerTheme:
          const DividerThemeData(color: AppColors.divider, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.accent,
          surfaceTintColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AppColors.sky
                  : AppColors.textSecondary)),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: states.contains(WidgetState.selected)
                  ? AppColors.primaryDark
                  : AppColors.textSecondary))),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.info),
      tabBarTheme: const TabBarThemeData(
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.sky),
      dividerColor: AppColors.divider,
    );
  }
}
