import 'support/empty_content_provider.dart';
import 'support/fake_appointments_provider.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app.dart';
import 'package:frontend/core/theme/app_scroll_behavior.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/user_provider.dart';

import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';
import 'package:frontend/routes/app_routes.dart';

void main() {
  testWidgets(
      'Android stretch is removed without changing vertical/horizontal scrolling',
      (tester) async {
    Widget content(ScrollBehavior? behavior) => MaterialApp(
        theme: ThemeData(useMaterial3: true, platform: TargetPlatform.android),
        scrollBehavior: behavior,
        home: Scaffold(
            body: ListView(children: [
          const SizedBox(height: 100),
          SizedBox(
              height: 150,
              child: ListView(
                key: const ValueKey('horizontal'),
                scrollDirection: Axis.horizontal,
                children: List.generate(
                    8, (i) => SizedBox(width: 200, child: Text('Card $i'))),
              )),
          const SizedBox(height: 1600),
        ])));
    await tester.pumpWidget(content(null));
    expect(find.byType(StretchingOverscrollIndicator), findsWidgets);
    await tester.pumpWidget(content(const AppScrollBehavior()));
    await tester.pumpAndSettle();
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(find.byType(GlowingOverscrollIndicator), findsNothing);
    final horizontal = find.descendant(
        of: find.byKey(const ValueKey('horizontal')),
        matching: find.byType(Scrollable));
    final state = tester.state<ScrollableState>(horizontal);
    final cardSize = tester.getSize(find.byKey(const ValueKey('horizontal')));
    await tester.drag(horizontal, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(state.position.pixels, greaterThan(0));
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.drag(horizontal, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('horizontal'))), cardSize);
    final vertical = find.byType(Scrollable).first;
    final verticalState = tester.state<ScrollableState>(vertical);
    await tester.drag(vertical, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(verticalState.position.pixels, greaterThan(0));
    expect(verticalState.position.physics,
        isNot(isA<NeverScrollableScrollPhysics>()));
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
  });

  testWidgets('real App routes and all four tabs inherit the shared behavior',
      (tester) async {
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider<ContentProvider>(
          create: (_) => emptyContentProvider()),
      ChangeNotifierProvider<AppointmentsProvider>(
          create: (_) => FakeAppointmentsProvider()),
      ChangeNotifierProvider(create: (_) => UserProvider()),
      ChangeNotifierProvider(create: (_) => PatientDataProvider()),
      ChangeNotifierProvider(create: (_) => FakeProfileBackend().provider()),
      ChangeNotifierProvider(create: (_) => FakeCatalogBackend().provider()),
    ], child: const App()));
    await tester.pumpAndSettle();
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).scrollBehavior,
        isA<AppScrollBehavior>());
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.main);
    await tester.pumpAndSettle();
    for (final label in ['Trang chủ', 'Đặt lịch', 'Hồ sơ', 'Tôi']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      for (final element in find.byType(Scrollable).evaluate()) {
        expect(ScrollConfiguration.of(element), isA<AppScrollBehavior>());
      }
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
