import 'package:frontend/features/articles/article_list_screen.dart';
import 'package:frontend/features/doctors/doctor_list_screen.dart';
import 'package:frontend/features/services/service_list_screen.dart';
import 'package:frontend/features/booking/widgets/booking_price_summary.dart';
import 'package:frontend/features/booking/steps/select_datetime_step.dart';
import 'package:frontend/features/booking/steps/select_doctor_step.dart';
import 'package:frontend/features/booking/steps/select_services_step.dart';
import 'package:frontend/features/booking/steps/confirm_booking_step.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/me/saved_items_screen.dart';
import 'package:frontend/features/me/help_screen.dart';
import 'package:frontend/features/me/privacy_screen.dart';
import 'package:frontend/features/me/change_password_screen.dart';
import 'package:frontend/features/me/language_screen.dart';
import 'package:frontend/features/me/settings_screen.dart';
import 'package:frontend/features/me/notifications_screen.dart';
import 'package:frontend/features/me/family_form_screen.dart';
import 'package:frontend/features/me/family_list_screen.dart';
import 'package:frontend/features/me/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/login_screen.dart';
import 'package:frontend/features/auth/register_screen.dart';
import 'package:frontend/features/services/service_detail_screen.dart';
import 'package:frontend/features/doctors/doctor_detail_screen.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'package:frontend/data/models/dental_service.dart';
import 'package:frontend/data/models/doctor.dart';
import 'support/api_app_fixture.dart';
import 'support/data_source_scope.dart';

void main() {
  setUp(() => useDataSourceForTest(DataSource.api));
  for (final width in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('Home and tabs width=$width scale=$scale', (t) async {
        final originalError = FlutterError.onError!;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          originalError(details);
        };
        final f = ApiAppFixture();
        await f.mount(t, width: width, height: 800, scale: scale);
        for (final group in ['featuredServices', 'doctors', 'articles']) {
          await t.ensureVisible(find.byKey(ValueKey('home-$group-carousel')));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
        }
        for (final tab in ['Đặt lịch', 'Hồ sơ', 'Tôi']) {
          await t.tap(find.descendant(
              of: find.byType(NavigationBar), matching: find.text(tab)));
          await t.pumpAndSettle();
          expect(t.takeException(), isNull, reason: tab);
        }
      });

      for (final register in [false, true]) {
        testWidgets(
            'Auth register=$register width=$width scale=$scale keyboard',
            (t) async {
          final f = ApiAppFixture(signedIn: false);
          await f.mount(t,
              width: width,
              height: 800,
              scale: scale,
              home: register ? const RegisterScreen() : const LoginScreen());
          t.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(t.view.resetViewInsets);
          await t.showKeyboard(find.byType(TextFormField).last);
          await t.pumpAndSettle();
          final action = find.widgetWithText(
              FilledButton, register ? 'Tạo tài khoản' : 'Đăng nhập');
          await t.ensureVisible(action);
          await t.pumpAndSettle();
          expect(t.getRect(action).bottom, lessThanOrEqualTo(520));
          expect(t.takeException(), isNull);
        });
      }

      testWidgets('Detail and appointments width=$width scale=$scale',
          (t) async {
        final originalError = FlutterError.onError!;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          originalError(details);
        };
        final f = ApiAppFixture();
        await f.profiles.ensureLoaded();
        f.records.syncPatients(f.profiles.profile!, []);
        f.records.replaceAppointments([]);
        await f.catalog.load();
        await f.content.loadArticles();
        final booking = BookingController(f.records,
            profile: f.profiles, catalog: f.catalog);
        booking.serviceIds.add('service-api');
        booking.doctorId = 'doctor-api';
        booking.doctorChosen = true;
        booking.date = DateTime(2099, 1, 1);
        booking.time = '09:00';
        addTearDown(booking.dispose);
        // These are the same API models used by production detail pages.
        final pages = [
          ServiceDetailScreen(
              service: DentalService.fromJson(f.services.first)),
          DoctorDetailScreen(doctor: Doctor.fromJson(f.doctors.first)),
          const AppointmentsScreen(patientId: ApiAppFixture.owner),
          const EditProfileScreen(),
          const FamilyListScreen(),
          const FamilyFormScreen(),
          const NotificationsScreen(),
          const SettingsScreen(),
          const LanguageScreen(),
          const ChangePasswordScreen(),
          const PrivacyScreen(),
          const HelpScreen(),
          const SavedItemsScreen(),
          const ServiceListScreen(),
          const DoctorListScreen(),
          const ArticleListScreen(),
          SingleChildScrollView(
              child: SelectServicesStep(controller: booking, onDetail: (_) {})),
          SingleChildScrollView(
              child: SelectDoctorStep(controller: booking, onDetail: (_) {})),
          SingleChildScrollView(child: SelectDatetimeStep(controller: booking)),
          SingleChildScrollView(
              child: Column(children: [
            ConfirmBookingStep(controller: booking),
            BookingPriceSummary(controller: booking, onNext: () {}),
          ])),
        ];
        // Mount providers once; replace only the presentation via a notifier.
        final selected = ValueNotifier<Widget>(pages.first);
        addTearDown(selected.dispose);
        await f.mount(t,
            width: width,
            height: 800,
            scale: scale,
            home: ValueListenableBuilder<Widget>(
                valueListenable: selected,
                builder: (_, page, __) =>
                    Theme(data: AppTheme.light, child: Scaffold(body: page))));
        for (final page in pages) {
          selected.value = page;
          await t.pumpAndSettle();
          expect(t.takeException(), isNull,
              reason: page.runtimeType.toString());
          final fields = find.byType(TextFormField);
          final actions = find.byType(FilledButton);
          if (fields.evaluate().isNotEmpty && actions.evaluate().isNotEmpty) {
            t.view.viewInsets = const FakeViewPadding(bottom: 280);
            await t.ensureVisible(fields.last);
            await t.showKeyboard(fields.last);
            await t.pumpAndSettle();
            await t.ensureVisible(actions.last);
            await t.pumpAndSettle();
            expect(t.getRect(actions.last).bottom, lessThanOrEqualTo(520));
            expect(t.takeException(), isNull);
            t.testTextInput.hide();
            t.view.resetViewInsets();
            await t.pumpAndSettle();
          }
        }
      });
    }
  }
}
