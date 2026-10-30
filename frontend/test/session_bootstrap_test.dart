import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart' as app;
import 'support/fake_auth_service.dart';

void main() {
  testWidgets(
      'real app provider bootstrap does not notify ancestors during build',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Use the actual startApp wiring; auth is local and no account is signed in.
    await tester.runAsync(() => app.startApp(FakeAuthService()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(MaterialApp), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
