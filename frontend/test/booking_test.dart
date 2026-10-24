import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/booking/booking_screen.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/providers/user_provider.dart';

import 'support/fake_profile_backend.dart';

void main() {
  test('services, total and steps preserve selections', () {
    final d = PatientDataProvider();
    final c = BookingController(d);
    c.next();
    expect(c.step, 0);
    c.toggleService(d.services[0].id);
    c.toggleService(d.services[1].id);
    expect(c.total, d.services[0].price + d.services[1].price);
    c.next();
    c.next();
    expect(c.step, 1);
    c.chooseDoctor(d.doctors.first.id);
    c.next();
    c.back();
    expect(c.doctorId, d.doctors.first.id);
    expect(c.serviceIds.length, 2);
    c.toggleService(d.services[0].id);
    expect(c.total, d.services[1].price);
    c.dispose();
  });
  test('time validation and single shared appointment for relative', () async {
    final d = PatientDataProvider();
    final c = BookingController(d, clock: () => DateTime(2026, 10, 21, 10));
    c.chooseDate(DateTime(2026, 10, 20));
    expect(c.date, isNull);
    c.chooseDate(DateTime(2026, 10, 22));
    c.chooseTime('09:00');
    c.chooseDate(DateTime(2026, 10, 21));
    expect(c.time, isNull);
    c.chooseTime('09:00');
    expect(c.time, isNull);
    c.chooseTime('10:30');
    expect(c.validTime, isTrue);
    c.toggleService(d.services.first.id);
    c.chooseDoctor(null);
    c.selectPatient(d.patients.last.id);
    c.note = 'Ghi chú\nnhiều dòng';
    final count = d.appointments.length;
    await Future.wait([c.submit(), c.submit()]);
    await c.submit();
    expect(d.appointments.length, count + 1);
    expect(c.created!.patientId, d.patients.last.id);
    expect(c.created!.doctorId, isNull);
    expect(c.created!.totalPrice, c.total);
    expect(c.created!.note, c.note);
    expect(d.selectedPatientId, d.patients.first.id);
    c.dispose();
  });
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('booking detail and doctor step fit $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = PatientDataProvider();
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: d,
          child: MaterialApp(
              theme: AppTheme.light,
              home: const Scaffold(body: BookingScreen()))));
      await tester.tap(find.text('Chi tiết').first);
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.text(d.services.first.name));
      await tester.pump();
      await tester.ensureVisible(find.text('Tiếp theo →'));
      await tester.tap(find.text('Tiếp theo →'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn bác sĩ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('complete booking, keyboard and records navigation $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = PatientDataProvider();
      final count = d.appointments.length;
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: d,
          child: MultiProvider(
              providers: [
                ChangeNotifierProvider(create: (_) => UserProvider()),
                ChangeNotifierProvider(
                    create: (_) => FakeProfileBackend().provider()),
              ],
              child: MaterialApp(
                  theme: AppTheme.light, home: const MainShell()))));
      await tester.tap(find.text('Đặt lịch').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(d.services.first.name).last);
      await tester.pump();
      await tester.tap(find.text('Trang chủ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lịch').last);
      await tester.pumpAndSettle();
      expect(find.text('1 dịch vụ đã chọn'), findsOneWidget);
      if (width == 430) {
        await tester
            .ensureVisible(find.byType(DropdownButtonFormField<String>));
        await tester.tap(find.byType(DropdownButtonFormField<String>));
        await tester.pumpAndSettle();
        await tester.tap(find
            .text(
                '${d.patients.last.fullName} (${d.patients.last.relationship})')
            .last);
        await tester.pumpAndSettle();
        expect(d.selectedPatientId, d.patients.first.id);
      }
      await tester.ensureVisible(find.text('Tiếp theo →'));
      await tester.tap(find.text('Tiếp theo →'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xem thông tin chi tiết ›').first);
      await tester.tap(find.text('Xem thông tin chi tiết ›').first);
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết bác sĩ'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Để hệ thống chọn bác sĩ'));
      await tester.tap(find.text('Để hệ thống chọn bác sĩ'));
      await tester.pump();
      await tester.ensureVisible(find.text('Tiếp theo →'));
      await tester.tap(find.text('Tiếp theo →'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Chọn ngày khám'));
      await tester.tap(find.text('Chọn ngày khám'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('09:00'));
      await tester.tap(find.text('09:00'));
      await tester.pump();
      await tester.ensureVisible(find.text('Tiếp theo →'));
      await tester.tap(find.text('Tiếp theo →'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.enterText(
          find.byType(TextFormField).last, 'Ghi chú nhiều dòng\nÊ buốt');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.ensureVisible(find.text('Xác nhận đặt lịch →'));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xác nhận đặt lịch →'));
      await tester.tap(find.text('Xác nhận đặt lịch →'));
      await tester.pumpAndSettle();
      expect(find.text('Đặt lịch thành công!'), findsOneWidget);
      expect(d.appointments.length, count + 1);
      if (width == 430) {
        await tester.tap(find.text('Về trang chủ'));
        await tester.pumpAndSettle();
        expect(find.text('Lịch hẹn sắp tới'), findsOneWidget);
        expect(d.selectedPatientId, d.patients.first.id);
        expect(d.appointmentPatientId, d.patients.last.id);
        expect(d.appointments.last.patientId, d.patients.last.id);
      } else {
        await tester.tap(find.text('Xem hồ sơ'));
        await tester.pumpAndSettle();
        expect(find.text('Lịch hẹn của ${d.patients.first.fullName}'),
            findsOneWidget);
        expect(find.text('Chưa có lịch hẹn.'), findsNothing);
        expect(find.text('Chờ phân công'), findsOneWidget);
      }
      await tester.tap(find.text('Đặt lịch').last);
      await tester.pumpAndSettle();
      expect(find.text('0 dịch vụ đã chọn'), findsOneWidget);
      expect(d.appointments.length, count + 1);
      expect(tester.takeException(), isNull);
    });
  }
}
