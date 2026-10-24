import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/user_provider.dart';

import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';

Future<void> qaPump(WidgetTester tester, PatientDataProvider d,
    {double width = 360, double scale = 1.5, double height = 640}) async {
  final previousError = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.dumpErrorToConsole(details);
    previousError?.call(details);
  };
  addTearDown(() => FlutterError.onError = previousError);
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: d),
        ChangeNotifierProvider(
            create: (_) => UserProvider()..signInDemo('qa@example.com')),
        ChangeNotifierProvider(create: (_) => FakeProfileBackend().provider()),
        ChangeNotifierProvider(create: (_) => FakeCatalogBackend().provider()),
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
}
