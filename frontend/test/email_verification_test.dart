import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/user_provider.dart';

import 'me_test.dart' show openMe, pumpMe;
import 'support/fake_auth_service.dart';

void main() {
  test('register sends a verification email and starts a 60s cooldown',
      () async {
    var now = DateTime(2026, 10, 25, 9);
    final auth = FakeAuthService()..emailVerified = false;
    final users = UserProvider(auth: auth, clock: () => now);
    expect(
        await users.register('Bình', 'binh@example.com', 'secret123'), isNull);
    expect(auth.verificationEmailsSent, 1);
    expect(users.emailVerified, isFalse);
    expect(users.verificationCooldownSeconds, 60);

    now = now.add(const Duration(seconds: 20));
    expect(users.verificationCooldownSeconds, 40);
    expect(await users.resendVerificationEmail(),
        'Vui lòng đợi 40 giây rồi gửi lại.');
    expect(auth.verificationEmailsSent, 1);

    now = now.add(const Duration(seconds: 40));
    expect(users.verificationCooldownSeconds, 0);
    expect(await users.resendVerificationEmail(), isNull);
    expect(auth.verificationEmailsSent, 2);
    expect(users.verificationCooldownSeconds, 60);

    auth.emailVerified = true;
    expect(await users.refreshEmailVerified(), isNull);
    expect(users.emailVerified, isTrue);

    await users.logout();
    expect(users.emailVerified, isNull);
    expect(users.verificationCooldownSeconds, 0);
  });

  test('a failed verification email does not fail registration', () async {
    final auth = FakeAuthService()
      ..emailVerified = false
      ..failVerificationWith = 'Không có kết nối mạng.';
    final users = UserProvider(auth: auth);
    expect(await users.register('A', 'a@example.com', 'secret123'), isNull);
    expect(users.isAuthenticated, isTrue);
    expect(users.emailVerified, isFalse);
    // Chưa gửi được thì không bắt đợi, bấm "Gửi lại thư" được ngay.
    expect(users.verificationCooldownSeconds, 0);
    expect(await users.resendVerificationEmail(), 'Không có kết nối mạng.');
  });

  testWidgets('Me tab reminds unverified users without blocking the app',
      (tester) async {
    var now = DateTime(2026, 10, 25, 9);
    final auth = FakeAuthService()..emailVerified = false;
    final u = UserProvider(auth: auth, clock: () => now);
    await u.login('patient@example.com', 'secret123');
    await pumpMe(tester, u, PatientDataProvider());

    expect(find.text('Email chưa được xác minh'), findsOneWidget);
    // Menu vẫn dùng được khi chưa xác minh.
    expect(find.text('Thông tin cá nhân'), findsOneWidget);

    await openMe(tester, 'Gửi lại thư');
    expect(find.text('Đã gửi lại thư xác minh.'), findsOneWidget);
    expect(auth.verificationEmailsSent, 1);
    expect(find.text('Gửi lại sau 60 giây'), findsOneWidget);
    final resend = find.widgetWithText(OutlinedButton, 'Gửi lại sau 60 giây');
    expect(tester.widget<OutlinedButton>(resend).onPressed, isNull);

    // Đồng hồ trôi 60 giây: nút gửi lại bật lại.
    now = now.add(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Gửi lại thư'), findsOneWidget);

    await openMe(tester, 'Tôi đã xác minh');
    expect(find.textContaining('vẫn chưa được xác minh'), findsOneWidget);
    expect(find.text('Email chưa được xác minh'), findsOneWidget);

    auth.emailVerified = true;
    await openMe(tester, 'Tôi đã xác minh');
    expect(find.text('Đã xác minh email.'), findsOneWidget);
    expect(find.text('Email chưa được xác minh'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('verified users see no reminder', (tester) async {
    final u = UserProvider(auth: FakeAuthService());
    await u.login('patient@example.com', 'secret123');
    await pumpMe(tester, u, PatientDataProvider());
    expect(find.text('Email chưa được xác minh'), findsNothing);
  });
}
