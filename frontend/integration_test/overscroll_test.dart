import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart' as app;

import '../test/support/fake_auth_service.dart';
import '../test/support/fake_catalog_backend.dart';
import '../test/support/fake_profile_backend.dart';
import '../test/support/mock_data_source.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/core/theme/app_scroll_behavior.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/features/me/me_widgets.dart';
import 'package:frontend/features/records/records_widgets.dart';
import 'package:frontend/routes/app_routes.dart';

void main() {
  useMockDataSource();
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android boundaries across all tabs and secondary routes',
      (tester) async {
    // AuthService giả: test luồng giao diện, không gọi Firebase thật.
    await app.startApp(FakeAuthService(),
        profileService: FakeProfileBackend().service(),
        catalogService: FakeCatalogBackend().service());
    await tester.pumpAndSettle();
    final root = tester.state<NavigatorState>(find.byType(Navigator).first);
    Future<void> sweep(String page) async {
      expect(find.byType(StretchingOverscrollIndicator), findsNothing,
          reason: page);
      expect(find.byType(GlowingOverscrollIndicator), findsNothing,
          reason: page);
      final states = find
          .byType(Scrollable)
          .evaluate()
          .map((e) => (e as StatefulElement).state as ScrollableState)
          .toList();
      for (final state in states) {
        if (!state.mounted || !state.position.hasContentDimensions) continue;
        expect(ScrollConfiguration.of(state.context), isA<AppScrollBehavior>(),
            reason: page);
        final finder = find.byWidget(state.widget);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final position = state.position;
        final horizontal =
            axisDirectionToAxis(position.axisDirection) == Axis.horizontal;
        final forward =
            horizontal ? const Offset(-160, 0) : const Offset(0, -160);
        position.jumpTo(position.minScrollExtent);
        await tester.pumpAndSettle();
        // Pull beyond the leading boundary while the finger is still down.
        final gesture = await tester.startGesture(tester.getCenter(finder));
        await gesture.moveBy(-forward);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(StretchingOverscrollIndicator), findsNothing,
            reason: page);
        await gesture.up();
        await tester.pumpAndSettle();
        if (position.maxScrollExtent > position.minScrollExtent) {
          await tester.drag(finder, forward);
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(position.minScrollExtent),
              reason: '$page scrolls');
          position.jumpTo(position.maxScrollExtent);
          await tester.drag(finder, forward);
          await tester.pumpAndSettle();
        }
        position.jumpTo(position.minScrollExtent);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull, reason: page);
      debugPrint('SCROLL_QA: $page');
    }

    await sweep('Welcome');
    for (final route in [
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword
    ]) {
      root.pushNamed(route);
      await tester.pumpAndSettle();
      await sweep(route);
      root.pop();
      await tester.pumpAndSettle();
    }
    final user = tester.element(find.byType(MaterialApp)).read<UserProvider>();
    user.signInDemo('scroll.qa@example.invalid');
    root.pushNamed(AppRoutes.main);
    await tester.pumpAndSettle();
    final data =
        tester.element(find.byType(MainShell)).read<PatientDataProvider>();
    await sweep('Home including three horizontal lists');
    // Real Home catalog lists and details, preserving the nested navigator.
    for (var index = 0; index < 3; index++) {
      final all = find.text('Xem tất cả').at(index);
      await tester.ensureVisible(all);
      await tester.tap(all);
      await tester.pumpAndSettle();
      await sweep('Catalog $index list');
      // Dịch vụ, bác sĩ trên trang chủ lấy từ API (backend giả).
      final catalog =
          tester.element(find.byType(MainShell)).read<CatalogProvider>();
      final name = [
        catalog.services.first.name,
        catalog.doctors.first.fullName,
        data.articles.first.title
      ][index];
      final item = find.text(name).first;
      await tester.ensureVisible(item);
      await tester.tap(item);
      await tester.pumpAndSettle();
      await sweep('Catalog $index detail');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Đặt lịch').last);
    await tester.pumpAndSettle();
    await sweep('Booking services');
    await tester.tap(find.text('Hồ sơ').last);
    await tester.pumpAndSettle();
    await sweep('Records overview');
    final recordNav =
        Navigator.of(tester.element(find.byType(RecordsPage).last));
    final records = <(String, Object)>[
      (RecordsRoutes.appointments, data.primaryPatient.id),
      (RecordsRoutes.appointment, data.appointments.first.id),
      (RecordsRoutes.visits, data.primaryPatient.id),
      (RecordsRoutes.visit, data.visits.first),
      (RecordsRoutes.result, data.visits.first),
      for (final p in data.prescriptions) (RecordsRoutes.prescription, p),
      for (final r in data.receipts) (RecordsRoutes.receipt, r),
      (RecordsRoutes.treatments, data.primaryPatient.id),
      (RecordsRoutes.treatment, data.treatmentPlans.first),
      (RecordsRoutes.photos, data.treatmentPlans.first),
      (RecordsRoutes.followups, data.primaryPatient.id),
    ];
    for (final entry in records) {
      recordNav.pushNamed(entry.$1, arguments: entry.$2);
      await tester.pumpAndSettle();
      await sweep('Records ${entry.$1}');
      expect(find.byType(NavigationBar), findsOneWidget);
      recordNav.pop();
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Tôi').last);
    await tester.pumpAndSettle();
    await sweep('Account overview');
    final meNav = Navigator.of(tester.element(find.byType(MePage).last));
    for (final route in [
      MeRoutes.profile,
      MeRoutes.family,
      MeRoutes.familyForm,
      MeRoutes.notifications,
      MeRoutes.settings,
      MeRoutes.language,
      MeRoutes.password,
      MeRoutes.privacy,
      MeRoutes.help,
      MeRoutes.saved
    ]) {
      meNav.pushNamed(route);
      await tester.pumpAndSettle();
      await sweep('Account $route');
      expect(find.byType(NavigationBar), findsOneWidget);
      meNav.pop();
      await tester.pumpAndSettle();
    }
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('14_overscroll_account');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
