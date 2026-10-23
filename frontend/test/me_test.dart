import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/utils/validators.dart';
import 'package:frontend/data/models/patient.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/features/me/me_widgets.dart';

Widget providers(UserProvider users, PatientDataProvider data, Widget child) =>
    MultiProvider(providers: [
      ChangeNotifierProvider.value(value: users),
      ChangeNotifierProvider.value(value: data)
    ], child: child);
Future<void> pumpMe(
    WidgetTester tester, UserProvider users, PatientDataProvider data,
    {double width = 390}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(providers(users, data,
      MaterialApp(theme: AppTheme.light, home: const MainShell())));
  await tester.tap(find.text('Tôi').last);
  await tester.pumpAndSettle();
}

Future<void> openMe(WidgetTester tester, String text) async {
  final base = find.text(text);
  if (base.evaluate().isEmpty) {
    await tester.scrollUntilVisible(find.text(text), 180,
        scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(base.last);
  await tester.tap(base.last);
  await tester.pumpAndSettle();
}

Future<void> backMe(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

UserProvider demoUsers() => UserProvider()..signInDemo('patient@example.com');
Future<void> setBirthday(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(BirthdayField));
  await tester.tap(find.byType(BirthdayField));
  await tester.pumpAndSettle();
  final picker =
      tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
  expect(picker.lastDate.isAfter(DateTime.now()), isFalse);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  test('session sign-in/out has stable account id and retains no password', () {
    final u = UserProvider();
    expect(u.currentUser, isNull);
    u.signInDemo('patient@example.com');
    final id = u.currentUser!.id;
    u.setReceiveNotifications(false);
    u.setBiometricDemo(true);
    u.signOutDemo();
    expect(u.isAuthenticated, isFalse);
    expect(u.currentUser, isNull);
    u.signInDemo('patient@example.com');
    expect(u.currentUser!.id, id);
    expect(u.receiveNotifications, isFalse);
    expect(u.biometricDemo, isTrue);
  });
  test('family rules preserve records, ids and selection fallbacks', () {
    final d = PatientDataProvider();
    final appointments = d.appointments.toList();
    expect(d.removeFamilyMember(d.primaryPatient.id), isNotNull);
    expect(d.removeFamilyMember(d.patients.last.id), contains('liên kết'));
    final p = d.addRelative(
        name: 'Người thân kiểm thử',
        relationship: 'Em',
        dateOfBirth: DateTime(2000));
    d.updatePatient(Patient(
        id: p.id,
        fullName: 'Tên đã sửa',
        phone: '',
        dateOfBirth: p.dateOfBirth,
        relationship: 'Khác'));
    expect(d.patients.last.id, p.id);
    expect(d.patients.last.fullName, 'Tên đã sửa');
    d.selectPatient(p.id);
    d.focusAppointmentsFor(p.id);
    d.requestBookingFor(p.id);
    expect(d.removeFamilyMember(p.id), isNull);
    expect(d.selectedPatientId, d.primaryPatient.id);
    expect(d.recordsPatient.id, d.primaryPatient.id);
    expect(d.takeBookingPatientRequest(), d.primaryPatient.id);
    expect(d.appointments, appointments);
  });
  test(
      'optional phone and email validation accepts VN numbers and rejects malformed values',
      () {
    expect(Validators.vietnamesePhone('0903 456 789'), isNull);
    expect(Validators.vietnamesePhone('+84903456789'), isNull);
    expect(Validators.vietnamesePhone('1234'), isNotNull);
    expect(Validators.optionalEmail(''), isNull);
    expect(Validators.optionalEmail('bad'), isNotNull);
  });
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets(
        'all six account destinations, settings, password and FAQ fit $width',
        (tester) async {
      final u = demoUsers(), d = PatientDataProvider();
      await pumpMe(tester, u, d, width: width);
      d.focusAppointmentsFor(d.patients.last.id);
      await tester.pumpAndSettle();
      expect(find.text(u.account.name), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      await openMe(tester, 'Thông tin cá nhân');
      expect(find.text('Thay ảnh (demo)'), findsOneWidget);
      await backMe(tester);
      await openMe(tester, 'Quản lý người thân');
      expect(find.text(d.patients.last.fullName), findsOneWidget);
      await backMe(tester);
      await openMe(tester, 'Thông báo');
      expect(find.text('Tất cả'), findsOneWidget);
      await backMe(tester);
      await openMe(tester, 'Cài đặt');
      await openMe(tester, 'Nhận thông báo');
      expect(u.receiveNotifications, isFalse);
      await openMe(tester, 'Đăng nhập sinh trắc học (mô phỏng)');
      expect(u.biometricDemo, isTrue);
      await openMe(tester, 'Ngôn ngữ');
      expect(find.text('Tiếng Việt'), findsOneWidget);
      expect(find.text('English'), findsNothing);
      await backMe(tester);
      await openMe(tester, 'Đổi mật khẩu');
      for (var i = 0; i < 3; i++) {
        await tester.enterText(find.byType(TextFormField).at(i), 'secret123');
      }
      await openMe(tester, 'Kiểm tra biểu mẫu (demo)');
      expect(
          find.text(
              'Đổi mật khẩu chưa khả dụng trong chế độ demo. Không có mật khẩu nào được thay đổi.'),
          findsOneWidget);
      expect(u.isAuthenticated, isTrue);
      await backMe(tester);
      await openMe(tester, 'Quyền riêng tư');
      expect(find.text('Ai có thể xem hồ sơ?'), findsOneWidget);
      await backMe(tester);
      await backMe(tester);
      await openMe(tester, 'Trợ giúp');
      for (final q in [
        'Làm thế nào để đặt lịch?',
        'Có thể đặt nhiều dịch vụ không?',
        'Có thể đặt cho người thân không?',
        'Xem kết quả điều trị ở đâu?'
      ]) {
        if (find.text(q).evaluate().isEmpty) {
          await tester.scrollUntilVisible(find.text(q), 150,
              scrollable: find.byType(Scrollable).first);
        }
        expect(find.text(q), findsOneWidget);
      }
      await backMe(tester);
      await openMe(tester, 'Đã lưu');
      expect(find.text('Chưa có nội dung đã lưu.'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'profile validation, keyboard and primary-only synchronization at $width',
        (tester) async {
      final u = demoUsers(), d = PatientDataProvider();
      final relative = d.patients.last;
      final ids = d.appointments.map((a) => a.id).toList();
      await pumpMe(tester, u, d, width: width);
      await openMe(tester, 'Thông tin cá nhân');
      await tester.enterText(find.byType(TextFormField).at(0), '');
      await tester.enterText(find.byType(TextFormField).at(1), '123');
      await tester.enterText(find.byType(TextFormField).at(2), 'bad');
      await openMe(tester, 'Lưu thay đổi');
      expect(find.text('Họ và tên không được để trống'), findsOneWidget);
      expect(find.text('Email không hợp lệ'), findsOneWidget);
      expect(u.account.name, isNotEmpty);
      expect(d.primaryPatient.fullName, u.account.name);
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Tên tài khoản mới');
      await tester.enterText(find.byType(TextFormField).at(1), '0901234567');
      await tester.enterText(
          find.byType(TextFormField).at(2), 'new@example.com');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump();
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await openMe(tester, 'Lưu thay đổi');
      expect(u.account.name, 'Tên tài khoản mới');
      expect(find.text('Tên tài khoản mới'), findsOneWidget);
      expect(d.primaryPatient.fullName, u.account.name);
      expect(d.primaryPatient.id, 'patient-001');
      expect(d.patients.last, same(relative));
      expect(d.appointments.map((a) => a.id).toList(), ids);
      expect(u.account.email, 'new@example.com');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('family add/edit/delete dialogs and dropdown synchronization',
      (tester) async {
    final u = demoUsers(), d = PatientDataProvider();
    await pumpMe(tester, u, d);
    await openMe(tester, 'Quản lý người thân');
    expect(find.text('Xóa người thân'), findsOneWidget);
    await openMe(tester, 'Xóa người thân');
    expect(find.byType(AlertDialog), findsOneWidget);
    await openMe(tester, 'Xác nhận xóa');
    expect(find.textContaining('liên kết'), findsOneWidget);
    expect(d.patients.length, 2);
    await openMe(tester, 'Thêm người thân');
    await openMe(tester, 'Lưu người thân');
    expect(find.text('Vui lòng chọn ngày sinh'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Người thân mới');
    await setBirthday(tester);
    await openMe(tester, 'Lưu người thân');
    final p = d.patients.last;
    expect(d.patients.length, 3);
    expect(p.isPrimary, isFalse);
    final card = find
        .ancestor(of: find.text(p.fullName), matching: find.byType(Card))
        .first;
    await tester.tap(find.descendant(of: card, matching: find.text('Sửa')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Người thân đã sửa');
    await openMe(tester, 'Lưu người thân');
    expect(d.patients.last.id, p.id);
    await tester.tap(find.text('Hồ sơ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Người thân đã sửa (Con)').last);
    await tester.pumpAndSettle();
    expect(d.recordsPatient.id, p.id);
    await openMe(tester, 'Lịch hẹn');
    expect(find.text('Chưa có lịch hẹn.'), findsOneWidget);
    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Người thân đã sửa (Con)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tôi').last);
    await tester.pumpAndSettle();
    final editedCard = find
        .ancestor(
            of: find.text('Người thân đã sửa'), matching: find.byType(Card))
        .first;
    await tester.ensureVisible(editedCard);
    await tester.tap(
        find.descendant(of: editedCard, matching: find.text('Xóa người thân')));
    await tester.pumpAndSettle();
    await openMe(tester, 'Hủy');
    expect(d.patients.length, 3);
    await tester.tap(
        find.descendant(of: editedCard, matching: find.text('Xóa người thân')));
    await tester.pumpAndSettle();
    await openMe(tester, 'Xác nhận xóa');
    expect(d.patients.length, 2);
    expect(d.recordsPatient.id, d.primaryPatient.id);
    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();
    expect(
        find.text('${d.primaryPatient.fullName} (Bản thân)'), findsOneWidget);
    expect(u.account.name, d.primaryPatient.fullName);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'notifications filter, mark read, preserve category and open linked appointment',
      (tester) async {
    final u = demoUsers(), d = PatientDataProvider();
    await pumpMe(tester, u, d);
    await openMe(tester, 'Thông báo');
    await openMe(tester, 'Ưu đãi');
    expect(find.text('Chưa có thông báo trong danh mục này.'), findsOneWidget);
    await openMe(tester, 'Hệ thống');
    expect(find.text(d.notifications.last.title), findsOneWidget);
    expect(find.text(d.notifications.first.title), findsNothing);
    await openMe(tester, d.notifications.last.title);
    expect(d.notifications.last.isRead, isTrue);
    expect(d.notifications.last.category, NotificationCategory.system);
    await openMe(tester, 'Lịch hẹn');
    await openMe(tester, d.notifications.first.title);
    expect(d.notifications.first.isRead, isTrue);
    expect(d.notifications.first.appointmentId, isNotNull);
    expect(find.text('Chi tiết lịch hẹn'), findsOneWidget);
    expect(find.text('Mã lịch hẹn: ${d.notifications.first.appointmentId}'),
        findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'all supported bookmarks are shared with detail views and removal',
      (tester) async {
    final u = demoUsers(), d = PatientDataProvider();
    await pumpMe(tester, u, d);
    await openMe(tester, 'Đã lưu');
    expect(find.text('Chưa có nội dung đã lưu.'), findsOneWidget);
    d.toggleSavedArticle(d.articles.first.id);
    d.toggleSavedService(d.services.first.id);
    d.toggleSavedDoctor(d.doctors.first.id);
    await tester.pumpAndSettle();
    for (final name in [
      d.articles.first.title,
      d.services.first.name,
      d.doctors.first.fullName
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    await openMe(tester, d.articles.first.title);
    await openMe(tester, 'Đã lưu · Bỏ lưu');
    expect(d.savedArticles, isEmpty);
    await backMe(tester);
    expect(find.text(d.articles.first.title), findsNothing);
    await openMe(tester, d.services.first.name);
    await openMe(tester, 'Đã lưu · Bỏ lưu');
    expect(d.savedServiceIds, isEmpty);
    await backMe(tester);
    await openMe(tester, d.doctors.first.fullName);
    await openMe(tester, 'Đã lưu · Bỏ lưu');
    expect(d.savedDoctorIds, isEmpty);
    await backMe(tester);
    expect(find.text('Chưa có nội dung đã lưu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'logout cancellation, confirmed session clearing, no Back to shell and login again',
      (tester) async {
    final u = UserProvider(), d = PatientDataProvider();
    await tester.pumpWidget(providers(u, d, const App()));
    Future<void> login() async {
      await openMe(tester, 'Đăng nhập');
      await tester.enterText(
          find.byType(TextFormField).first, 'patient@example.com');
      await tester.enterText(find.byType(TextFormField).last, 'secret123');
      await openMe(tester, 'Đăng nhập');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(u.isAuthenticated, isTrue);
    }

    await login();
    await tester.tap(find.text('Tôi').last);
    await tester.pumpAndSettle();
    await openMe(tester, 'Đăng xuất');
    await openMe(tester, 'Hủy');
    expect(u.isAuthenticated, isTrue);
    await openMe(tester, 'Đăng xuất');
    await openMe(tester, 'Đăng xuất');
    expect(u.currentUser, isNull);
    expect(find.text('Chăm sóc nụ cười của bạn'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MainShell), findsNothing);
    expect(d.appointments, isNotEmpty);
    await login();
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
  testWidgets(
      'password validation and visibility do not alter demo credentials',
      (tester) async {
    final u = demoUsers(), d = PatientDataProvider();
    await pumpMe(tester, u, d);
    await openMe(tester, 'Cài đặt');
    await openMe(tester, 'Đổi mật khẩu');
    await openMe(tester, 'Kiểm tra biểu mẫu (demo)');
    expect(find.text('Mật khẩu không được để trống'), findsNWidgets(3));
    await tester.enterText(find.byType(TextFormField).at(0), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(1), 'newsecret');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await openMe(tester, 'Kiểm tra biểu mẫu (demo)');
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Hiện mật khẩu').first);
    await tester.tap(find.byTooltip('Hiện mật khẩu').first);
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        isFalse);
    expect(u.account.email, 'patient@example.com');
    expect(u.isAuthenticated, isTrue);
  });
}
