import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/appointments_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/user_provider.dart';

import '../features/shared/patient_detail_screen.dart';
import '../routes/app_routes.dart';

class BookingRequest {
  final bool replaceSelection;
  final DateTime? suggestedDate;
  final String? doctorId;
  final List<String>? serviceIds;
  final bool restrictToServiceIds;
  final String? comboId;
  final String? patientId;

  const BookingRequest({
    this.replaceSelection = false,
    this.suggestedDate,
    this.doctorId,
    this.serviceIds,
    this.restrictToServiceIds = false,
    this.comboId,
    this.patientId,
  });
}

class PatientNavigation {
  const PatientNavigation._();

  static BookingRequest? pendingBookingRequest;

  static void selectTab(BuildContext context, int index) {
    MainShellScope.maybeOf(context)?.onSelectTab(index);
  }

  /// Hàm dùng chung để mở màn hình đặt lịch với các giá trị chọn sẵn (tùy chọn).
  /// Dùng để gắn nút "Đặt lịch với bác sĩ này" ở chi tiết bác sĩ, dịch vụ, combo.
  static void openBooking(
    BuildContext context, {
    String? doctorId,
    List<String>? serviceIds,
    bool restrictToServiceIds = false,
    String? comboId,
    String? patientId,
  }) {
    pendingBookingRequest = BookingRequest(
      doctorId: doctorId,
      serviceIds: serviceIds,
      restrictToServiceIds: restrictToServiceIds,
      comboId: comboId,
      patientId: patientId,
    );
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
    selectTab(context, 1);
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

  static Future<void> logout(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final profile = context.read<ProfileProvider>();
    final catalog = context.read<CatalogProvider>();
    final appointments = context.read<AppointmentsProvider>();
    await context.read<UserProvider>().logout();
    if (!context.mounted) return;
    profile.clear();
    catalog.clear();
    appointments.clear();
    navigator.pushNamedAndRemoveUntil(
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
