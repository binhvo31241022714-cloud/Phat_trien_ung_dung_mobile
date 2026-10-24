import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart' as app;

import '../test/support/fake_auth_service.dart';
import '../test/support/fake_profile_backend.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/features/me/me_widgets.dart';
import 'package:frontend/providers/user_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Android: login, Home, booking, records, family, bookmarks and logout',
      (tester) async {
    // AuthService giả: test luồng giao diện, không gọi Firebase thật.
    final backend = FakeProfileBackend();
    await app.startApp(FakeAuthService(),
        profileService: backend.service());
    await tester.pumpAndSettle();
    Future<void> tapText(String label) async {
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 180,
            scrollable: find.byType(Scrollable).first);
      }
      await tester.ensureVisible(finder.last);
      await tester.tap(finder.last);
      await tester.pumpAndSettle();
    }

    Future<void> back() async {
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    var surfaceReady = false;
    Future<void> shot(String name) async {
      if (!surfaceReady) {
        await binding.convertFlutterSurfaceToImage();
        surfaceReady = true;
      }
      await tester.pumpAndSettle();
      await binding.takeScreenshot(name);
    }

    await tapText('Đăng nhập');
    await tester.enterText(
        find.byType(TextFormField).first, 'android.qa@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'demo123456');
    await tapText('Đăng nhập');
    final data =
        tester.element(find.byType(MainShell)).read<PatientDataProvider>();
    final users = tester.element(find.byType(MainShell)).read<UserProvider>();
    expect(users.isAuthenticated, isTrue);
    await shot('01_home');
    // Real Home detail and bookmark, retaining the one MainShell bar.
    await tapText(data.articles.first.title);
    expect(find.text('Chi tiết bài viết'), findsOneWidget);
    await tapText('Lưu để xem sau');
    expect(data.savedArticles, hasLength(1));
    await back();
    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();
    await shot('02_booking_services');
    await tapText(data.services.first.name);
    await tapText(data.services[1].name);
    await tapText('Tiếp theo →');
    await tapText('Để hệ thống chọn bác sĩ');
    await shot('03_booking_doctor');
    await tapText('Tiếp theo →');
    await tapText('Chọn ngày khám');
    await tester.tap(find.byIcon(Icons.chevron_right).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapText('09:00');
    await shot('04_booking_datetime');
    await tapText('Tiếp theo →');
    await tester.ensureVisible(find.byType(TextFormField).last);
    await tester.enterText(
        find.byType(TextFormField).last, 'Ghi chú kiểm tra Android');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await shot('05_booking_confirm');
    final before = data.appointments.length;
    await tapText('Xác nhận đặt lịch →');
    expect(find.text('Đặt lịch thành công!'), findsOneWidget);
    expect(data.appointments.length, before + 1);
    expect(data.appointments.last.status, AppointmentStatus.pending);
    await shot('06_booking_success');
    await tapText('Xem hồ sơ');
    expect(find.text('Lịch hẹn của ${data.primaryPatient.fullName}'),
        findsOneWidget);
    final services = data.services.take(2).map((s) => s.name).join(', ');
    await tapText(services);
    expect(find.text('Ghi chú: Ghi chú kiểm tra Android'), findsOneWidget);
    await tapText('Hủy lịch');
    await tapText('Giữ lịch');
    expect(data.appointments.last.status, AppointmentStatus.pending);
    await back();
    await back();
    await shot('07_records_overview');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    final relative = data.patients.last;
    await tester
        .tap(find.text('${relative.fullName} (${relative.relationship})').last);
    await tester.pumpAndSettle();
    expect(data.recordsPatient.id, relative.id);
    // Tên "Bản thân" lấy từ hồ sơ API (backend giả).
    expect(data.primaryPatient.fullName, 'Trần Thị Test');
    await shot('08_records_relative');
    await tester.tap(find.text('Tôi').last);
    await tester.pumpAndSettle();
    await shot('09_account');
    await tapText('Quản lý người thân');
    await tapText('Thêm người thân');
    await tester.enterText(
        find.byType(TextFormField).first, 'Người thân Android QA');
    await tester.ensureVisible(find.byType(BirthdayField));
    await tester.tap(find.byType(BirthdayField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapText('Lưu người thân');
    expect(backend.family.last['fullName'], 'Người thân Android QA');
    final newId = backend.family.last['id'];
    await shot('10_family');
    final card = find
        .ancestor(
            of: find.text('Người thân Android QA'), matching: find.byType(Card))
        .first;
    await tester.tap(find.descendant(of: card, matching: find.text('Sửa')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Người thân QA đã sửa');
    await tapText('Lưu người thân');
    expect(backend.family.single['id'], newId);
    expect(backend.family.single['fullName'], 'Người thân QA đã sửa');
    await back();
    await tapText('Đã lưu');
    expect(find.text(data.articles.first.title), findsOneWidget);
    await shot('11_saved');
    await back();
    await tapText('Cài đặt');
    await shot('12_settings');
    await back();
    await tapText('Đăng xuất');
    await tapText('Đăng xuất');
    expect(users.currentUser, isNull);
    expect(find.text('Chăm sóc nụ cười của bạn'), findsOneWidget);
    await shot('13_logged_out');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 5)));
}
