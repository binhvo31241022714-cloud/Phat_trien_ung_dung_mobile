import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/user_provider.dart';

import 'support/fake_profile_backend.dart';

import 'support/fake_auth_service.dart';

Widget _withProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
          create: (_) => UserProvider(auth: FakeAuthService())),
      ChangeNotifierProvider(create: (_) => PatientDataProvider()),
      ChangeNotifierProvider(create: (_) => FakeProfileBackend().provider()),
    ],
    child: child,
  );
}

void main() {
  testWidgets('Ứng dụng mở màn hình chào mừng', (tester) async {
    await tester.pumpWidget(_withProviders(const App()));

    expect(find.text('MediCare Dental'), findsOneWidget);
    expect(find.text('Chăm sóc nụ cười của bạn'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Tạo tài khoản'), findsOneWidget);
  });

  testWidgets('MainShell không hiển thị màn hình quản lý người dùng', (
    tester,
  ) async {
    await tester.pumpWidget(
      _withProviders(const MaterialApp(home: MainShell())),
    );

    expect(find.text('Lịch hẹn sắp tới'), findsOneWidget);
    expect(find.text('Quản lý người dùng'), findsNothing);
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();

    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);
    expect(find.text('Quản lý người dùng'), findsNothing);
  });

  testWidgets('luồng đăng nhập, chuyển tab, chi tiết, Back và đăng xuất', (
    tester,
  ) async {
    await tester.pumpWidget(_withProviders(const App()));

    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'minhanh@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'matkhau123');
    await tester.ensureVisible(find.text('Đăng nhập').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng nhập').last);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    expect(find.text('Lịch hẹn sắp tới'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    await tester.drag(
        find.byType(SingleChildScrollView).first, const Offset(0, -1600));
    await tester.pumpAndSettle();
    final data =
        tester.element(find.byType(MainShell)).read<PatientDataProvider>();
    data.toggleSavedArticle(data.articles.first.id);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();
    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);
    await tester.tap(find.text('Chi tiết').first);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);

    await tester.tap(find.text('Hồ sơ').last);
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ nha khoa'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('DỮ LIỆU DEMO · CHỈ ĐỌC'), 200,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('DỮ LIỆU DEMO · CHỈ ĐỌC'), findsOneWidget);

    await tester.tap(find.text('Tôi').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Đã lưu'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Đã lưu'));
    await tester.pumpAndSettle();
    expect(find.text(data.articles.first.title), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    data.focusAppointmentsFor(data.patients.last.id);
    await tester.pumpAndSettle();
    expect(find.text(data.patients.first.fullName), findsOneWidget);

    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();
    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);
    // Tên "Bản thân" lấy từ hồ sơ API (backend giả).
    expect(find.text('Trần Thị Test (Bản thân)'), findsOneWidget);

    await tester.tap(find.text('Tôi').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Đăng xuất').last);
    await tester.pumpAndSettle();
    expect(find.text('Chăm sóc nụ cười của bạn'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNothing);
  });
}
