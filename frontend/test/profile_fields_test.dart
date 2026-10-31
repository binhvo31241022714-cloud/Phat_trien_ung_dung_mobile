import 'package:frontend/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/me/me_widgets.dart';
import 'package:frontend/features/me/settings_screen.dart'
    show notificationsSettingDescription;

import 'me_test.dart' show demoUsers, openMe, pumpMe;
import 'support/fake_profile_backend.dart';

/// Số dạng +84 có dấu cách: app chấp nhận, máy chủ chỉ nhận chữ số.
const spacedPhone = '+84 912 345 678';

Finder phoneField() => find.widgetWithText(TextFormField, 'Số điện thoại');

void main() {
  testWidgets('add family: +84 phone is normalized, birthday is optional',
      (tester) async {
    final backend = FakeProfileBackend();
    await pumpMe(tester, demoUsers(), PatientDataProvider(),
        profile: backend.provider());
    await openMe(tester, 'Quản lý người thân');
    await openMe(tester, 'Thêm người thân');
    expect(find.text('Chọn ngày sinh (không bắt buộc)'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Bé Na');
    await tester.enterText(phoneField(), spacedPhone);
    // Không chọn ngày sinh.
    await openMe(tester, 'Lưu người thân');

    expect(find.text('Đã thêm người thân.'), findsOneWidget);
    expect(backend.family.single['phone'], '0912345678');
    expect(backend.family.single['birthday'], '');
    expect(find.text('Con · Chưa có ngày sinh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit family: +84 phone is normalized, no birthday needed',
      (tester) async {
    final backend = FakeProfileBackend(family: [
      {'id': 'fam-1', 'fullName': 'Bé Na', 'relationship': 'Con', 'phone': ''}
    ]);
    await pumpMe(tester, demoUsers(), PatientDataProvider(),
        profile: backend.provider());
    await openMe(tester, 'Quản lý người thân');
    final card = find
        .ancestor(of: find.text('Bé Na'), matching: find.byType(Card))
        .first;
    await tester.tap(find.descendant(of: card, matching: find.text('Sửa')));
    await tester.pumpAndSettle();
    await tester.enterText(phoneField(), spacedPhone);
    await openMe(tester, 'Lưu người thân');

    expect(find.text('Đã cập nhật người thân.'), findsOneWidget);
    expect(backend.family.single['phone'], '0912345678');
    expect(backend.family.single['birthday'], '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile: +84 phone is normalized, birthday is optional',
      (tester) async {
    final backend = FakeProfileBackend(); // Hồ sơ chưa có ngày sinh.
    await pumpMe(tester, demoUsers(), PatientDataProvider(),
        profile: backend.provider());
    await openMe(tester, 'Thông tin cá nhân');
    await tester.enterText(phoneField(), spacedPhone);
    await openMe(tester, 'Lưu thay đổi');

    expect(find.text('Đã lưu thông tin cá nhân.'), findsOneWidget);
    expect(backend.me['phone'], '0912345678');
    expect(backend.me['birthday'], '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chosen birthday still cannot be in the future',
      (tester) async {
    final form = GlobalKey<FormState>();
    Future<String?> validate(DateTime? value) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Form(
                  key: form,
                  child: BirthdayField(value: value, onChanged: (_) {})))));
      form.currentState!.validate();
      await tester.pump();
      return find.text('Ngày sinh không được ở tương lai').evaluate().isEmpty
          ? null
          : 'future';
    }

    expect(await validate(null), isNull);
    expect(await validate(DateTime(2000, 1, 1)), isNull);
    expect(
        await validate(DateTime.now().add(const Duration(days: 1))), 'future');
  });

  testWidgets('API: notification switch is saved on the server (A18)',
      (tester) async {
    final backend = FakeProfileBackend();
    final profile = backend.provider();
    await pumpMe(tester, demoUsers(), PatientDataProvider(), profile: profile);
    await openMe(tester, 'Cài đặt');
    expect(find.text(notificationsSettingDescription), findsOneWidget);
    await openMe(tester, 'Nhận thông báo');
    expect(backend.me['notificationsEnabled'], isFalse);
    expect(profile.profile?.notificationsEnabled, isFalse);
    expect(tester.takeException(), isNull);
  }, skip: AppConfig.current.dataSource != DataSource.api);

  testWidgets('notification switch says it is a local option only (A18)',
      (tester) async {
    final users = demoUsers();
    await pumpMe(tester, users, PatientDataProvider());
    await openMe(tester, 'Cài đặt');
    expect(
        find.text(
            'Chỉ là tùy chọn lưu trên máy này. Ứng dụng chưa gửi thông báo đẩy.'),
        findsOneWidget);
    await openMe(tester, 'Nhận thông báo');
    expect(users.receiveNotifications, isFalse);

    // Màn hình Thông báo khi đã tắt: không còn nhắc "phiên demo".
    Navigator.of(tester.element(find.text('Cài đặt').last)).pop();
    await tester.pumpAndSettle();
    await openMe(tester, 'Thông báo');
    if (AppConfig.current.dataSource == DataSource.mock) {
      expect(find.textContaining('chưa gửi thông báo đẩy'), findsOneWidget);
    } else {
      expect(
          find.text('Chưa có thông báo trong danh mục này.'), findsOneWidget);
    }
    expect(find.textContaining('tắt nhận thông báo trong phiên demo'),
        findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: AppConfig.current.dataSource != DataSource.mock);
}
