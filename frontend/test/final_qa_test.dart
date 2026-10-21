import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/app.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/features/booking/steps/select_services_step.dart';
import 'package:frontend/features/me/notifications_screen.dart';
import 'dart:collection';
import 'package:frontend/data/models/dental_service.dart';
import 'package:frontend/data/models/doctor.dart';
import 'package:frontend/data/models/article.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/user_provider.dart';

Future<void> qaPump(WidgetTester tester, PatientDataProvider d,
    {double width = 360, double scale = 1.5, double height = 640}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: d),
        ChangeNotifierProvider(
            create: (_) => UserProvider()..signInDemo('qa@example.com'))
      ],
      child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: const MainShell())));
  await tester.pumpAndSettle();
}

Future<void> qaOpen(WidgetTester tester, String label) async {
  final base = find.text(label);
  if (base.evaluate().isEmpty) {
    await tester.scrollUntilVisible(base, 180,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(base.last);
  await tester.tap(base.last);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('large text and short viewport across four tabs $width',
        (tester) async {
      final d = PatientDataProvider();
      await qaPump(tester, d, width: width);
      expect(tester.takeException(), isNull, reason: 'initial Home');
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Home article and horizontal cards');
      for (final label in ['Đặt lịch', 'Hồ sơ', 'Tôi']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: label);
      }
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  }
  testWidgets('Home article bookmark reaches Saved and removes in both places',
      (tester) async {
    final d = PatientDataProvider();
    await qaPump(tester, d, scale: 1, height: 900);
    await qaOpen(tester, d.articles.first.title);
    expect(find.text('Chi tiết bài viết'), findsOneWidget);
    await qaOpen(tester, 'Lưu để xem sau');
    expect(d.savedArticles.single.id, d.articles.first.id);
    await tester.tap(find.text('Tôi').last);
    await tester.pumpAndSettle();
    await qaOpen(tester, 'Đã lưu');
    expect(find.text(d.articles.first.title), findsOneWidget);
    await qaOpen(tester, d.articles.first.title);
    await qaOpen(tester, 'Đã lưu · Bỏ lưu');
    expect(d.savedArticles, isEmpty);
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(find.text('Lưu để xem sau'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('large text full booking, keyboard and success $width',
        (tester) async {
      final d = PatientDataProvider();
      await qaPump(tester, d, width: width);
      await tester.tap(find.text('Đặt lịch').last);
      await tester.pumpAndSettle();
      final c = tester
          .widget<SelectServicesStep>(find.byType(SelectServicesStep))
          .controller;
      await qaOpen(tester, d.services.first.name);
      await qaOpen(tester, 'Tiếp theo →');
      await qaOpen(tester, 'Để hệ thống chọn bác sĩ');
      await qaOpen(tester, 'Tiếp theo →');
      final tomorrow = DateTime.now().add(const Duration(days: 2));
      c.chooseDate(DateTime(tomorrow.year, tomorrow.month, tomorrow.day));
      await tester.pumpAndSettle();
      await qaOpen(tester, '09:00');
      await qaOpen(tester, 'Tiếp theo →');
      expect(tester.takeException(), isNull, reason: 'confirmation');
      await tester.ensureVisible(find.byType(TextFormField).last);
      await tester.enterText(find.byType(TextFormField).last,
          'Ghi chú dài\nNhiều dòng để kiểm tra bàn phím');
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pump();
      await tester.ensureVisible(find.text('Xác nhận đặt lịch →'));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await qaOpen(tester, 'Xác nhận đặt lịch →');
      expect(find.text('Đặt lịch thành công!'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'success');
    });
  }
  testWidgets('Welcome supports short height and large text', (tester) async {
    tester.view.physicalSize = const Size(360, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => PatientDataProvider())
    ], child: const _LargeApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await qaOpen(tester, 'Đăng nhập');
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
  });
  test('disposed booking draft cannot notify or submit', () async {
    final c = BookingController(PatientDataProvider());
    c.dispose();
    c.chooseDate(DateTime.now());
    c.chooseTime('09:00');
    c.toggleService('service-checkup');
    c.chooseDoctor(null);
    c.selectPatient('patient-001');
    c.next();
    c.back();
    expect(await c.submit(), isNull);
  });
  testWidgets('orphan and empty notifications never invent a real appointment',
      (tester) async {
    final d = _OrphanNotifications();
    await qaPump(tester, d, scale: 1, height: 900);
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(
        find.text(
            'Lịch hẹn liên kết không còn khả dụng. Đây là thông báo demo.'),
        findsOneWidget);
    expect(find.text('Nội dung lịch không tồn tại'), findsNothing);
    await qaOpen(tester, 'Ưu đãi');
    expect(find.text('Chưa có thông báo trong danh mục này.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Home catalog actions open matching lists, details and notifications',
      (tester) async {
    final d = PatientDataProvider();
    await qaPump(tester, d, scale: 1, height: 900);
    for (final entry in [
      (
        'Dịch vụ nổi bật',
        'Dịch vụ nha khoa',
        d.services.first.name,
        'Chi tiết dịch vụ'
      ),
      (
        'Đội ngũ bác sĩ',
        'Đội ngũ bác sĩ',
        d.doctors.first.fullName,
        'Chi tiết bác sĩ'
      ),
      (
        'Kiến thức nha khoa',
        'Kiến thức nha khoa',
        d.articles.first.title,
        'Chi tiết bài viết'
      )
    ]) {
      final header = find
          .ancestor(of: find.text(entry.$1), matching: find.byType(Row))
          .first;
      final action =
          find.descendant(of: header, matching: find.text('Xem tất cả'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(AppBar), matching: find.text(entry.$2)),
          findsOneWidget);
      await qaOpen(tester, entry.$3);
      expect(find.text(entry.$4), findsOneWidget);
      expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byTooltip('Thông báo'));
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        3);
    await tester.tap(find.text('Hồ sơ').last);
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ nha khoa'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('register validation and forgot-password return to login in demo',
      (tester) async {
    final data = PatientDataProvider(), users = UserProvider();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: users)
    ], child: const App()));
    await qaOpen(tester, 'Tạo tài khoản');
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextFormField).at(i),
          ['QA Patient', 'qa@example.com', 'secret123', 'different'][i]);
    }
    final registerButton = find.widgetWithText(FilledButton, 'Tạo tài khoản');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('khớp'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(users.isAuthenticated, isFalse);
    await qaOpen(tester, 'Đăng nhập');
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'bad');
    await tester.enterText(find.byType(TextFormField).last, '12');
    await qaOpen(tester, 'Đăng nhập');
    expect(find.text('Email không hợp lệ'), findsOneWidget);
    expect(find.text('Mật khẩu phải có ít nhất 6 ký tự'), findsOneWidget);
    await qaOpen(tester, 'Quên mật khẩu?');
    await tester.enterText(find.byType(TextFormField), 'qa@example.com');
    await qaOpen(tester, 'Tiếp tục');
    expect(find.textContaining('Chưa có email thật'), findsOneWidget);
    await qaOpen(tester, 'Về đăng nhập');
    expect(find.text('Chào mừng trở lại!'), findsOneWidget);
    expect(users.isAuthenticated, isFalse);
    expect(tester.takeException(), isNull);
  });
  test('expired or disposed submissions cannot leave ghost appointments',
      () async {
    final data = PatientDataProvider();
    var now = DateTime(2026, 10, 22, 8);
    BookingController draft() {
      final c = BookingController(data, clock: () => now);
      c.toggleService(data.services.first.id);
      c.chooseDoctor(null);
      c.chooseDate(DateTime(2026, 10, 22));
      c.chooseTime('09:00');
      return c;
    }

    final c = draft();
    final count = data.appointments.length;
    final first = c.submit();
    now = DateTime(2026, 10, 22, 9, 1);
    expect(await first, isNull);
    expect(data.appointments.length, count);
    c.dispose();
    now = DateTime(2026, 10, 22, 8);
    final second = draft();
    final pending = second.submit();
    second.dispose();
    expect(await pending, isNull);
    expect(data.appointments.length, count);
  });
  testWidgets(
      'empty catalog, notifications and appointments remain usable with large text',
      (tester) async {
    final d = _EmptyData();
    await qaPump(tester, d);
    expect(tester.takeException(), isNull);
    expect(find.text('Bạn chưa có lịch hẹn nào trong thời gian tới.'),
        findsOneWidget);
    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có dịch vụ để đặt lịch.'), findsOneWidget);
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Thông báo'));
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo trong danh mục này.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LargeApp extends StatelessWidget {
  const _LargeApp();
  @override
  Widget build(BuildContext context) => const MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(1.5)), child: App());
}

class _OrphanNotifications extends PatientDataProvider {
  @override
  UnmodifiableListView<PatientNotification> get notifications =>
      UnmodifiableListView([
        PatientNotification(
            id: 'missing',
            title: 'Lịch hẹn mẫu',
            message: 'Nội dung lịch không tồn tại',
            createdAt: DateTime(2026),
            category: NotificationCategory.appointment,
            appointmentId: 'absent')
      ]);
}

class _EmptyData extends PatientDataProvider {
  @override
  List<DentalService> get services => [];
  @override
  List<Doctor> get doctors => [];
  @override
  List<Article> get articles => [];
  @override
  UnmodifiableListView<Appointment> get appointments =>
      UnmodifiableListView([]);
  @override
  UnmodifiableListView<PatientNotification> get notifications =>
      UnmodifiableListView([]);
}
