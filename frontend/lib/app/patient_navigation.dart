import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

import '../features/shared/patient_detail_screen.dart';
import '../routes/app_routes.dart';

class PatientNavigation {
  const PatientNavigation._();

  static void selectTab(BuildContext context, int index) {
    MainShellScope.maybeOf(context)?.onSelectTab(index);
  }

  static Future<T?> openDetail<T>(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    return Navigator.of(context).pushNamed<T>(
      AppRoutes.detail,
      arguments: PatientDetailArguments(
        title: title,
        description: description,
      ),
    );
  }

  static void logout(BuildContext context) {
    context.read<UserProvider>().signOutDemo();
    Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (_) => false,
    );
  }
}

class MainShellScope extends InheritedWidget {
  final ValueChanged<int> onSelectTab;
  final int selectedIndex;

  const MainShellScope({
    required this.onSelectTab,
    this.selectedIndex = 0,
    required super.child,
    super.key,
  });

  static MainShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MainShellScope>();

  @override
  bool updateShouldNotify(MainShellScope oldWidget) =>
      onSelectTab != oldWidget.onSelectTab ||
      selectedIndex != oldWidget.selectedIndex;
}
