import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/models/home_appointment.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';
import 'module4_test.dart' as fixture;

Map<String, dynamic> appointment([Map<String, dynamic> extra = const {}]) => {
      'id': 'appointment_real',
      'accountId': 'account_real',
      'patientId': 'account_real',
      'date': '2099-01-01',
      'startTime': '09:00',
      'status': 'booked',
      'doctorId': 'doc_01',
      'serviceIds': ['svc_01'],
      ...extra,
    };
void main() {
  test('Home endTime is preferred over duration', () {
    final a = HomeAppointment.read(
        appointment({'endTime': '10:15', 'durationMinutes': 45}))!;
    expect(a.endAt, DateTime(2099, 1, 1, 10, 15));
  });
  test('Home endAt Timestamp takes precedence over endTime and duration', () {
    final end = DateTime(2099, 1, 1, 11).toUtc();
    final a = HomeAppointment.read(appointment({
      'endAt': {'_seconds': end.millisecondsSinceEpoch ~/ 1000},
      'endTime': '10:00',
      'durationMinutes': 45
    }))!;
    expect(a.endAt, end.toLocal());
  });
  test('Home uses valid explicit duration when end is missing', () {
    final a = HomeAppointment.read(appointment({'durationMinutes': 75}))!;
    expect(a.endAt, DateTime(2099, 1, 1, 10, 15));
  });
  test('Home never invents thirty minutes for missing or invalid duration', () {
    for (final value in [
      null,
      0,
      -10,
      '60',
      double.nan,
      double.infinity,
      1.5,
      1e100
    ]) {
      final a = HomeAppointment.read(appointment({'durationMinutes': value}))!;
      expect(a.endAt, isNull);
      expect(a.durationMinutes, 0);
    }
  });
  test('invalid end times do not normalize into invented dates', () {
    for (final value in ['25:00', '09:99', '08:00', 'bad', null]) {
      expect(
          HomeAppointment.read(appointment({'endTime': value}))!.endAt, isNull);
    }
    expect(
        HomeAppointment.read(
                appointment({'endAt': 'bad', 'durationMinutes': 60}))!
            .endAt,
        DateTime(2099, 1, 1, 10));
  });
  test('invalid/missing start date is safe and does not default to now', () {
    for (final extra in [
      {'date': '2099-02-30'},
      {'date': null},
      {'startTime': 'bad'},
      {'startTime': null}
    ]) {
      expect(HomeAppointment.read(appointment(extra)), isNull);
    }
  });
  test('valid ISO start/end and missing doctor/name are safe', () {
    final a = HomeAppointment.read(appointment({
      'date': null,
      'scheduledAt': '2099-01-01T09:00:00Z',
      'endAt': '2099-01-01T10:00:00Z',
      'doctorId': null,
      'doctorName': null,
      'serviceIds': []
    }))!;
    expect(a.endAt!.difference(a.scheduledAt).inMinutes, 60);
    expect(a.doctorId, isNull);
    expect(a.serviceIds, isEmpty);
  });

  group('API Home appointment card', () {
    Future<void> mount(WidgetTester tester, Map<String, dynamic> raw) async {
      final b = fixture.Backend();
      final p = await fixture.ready(b);
      p.home = ContentHome({
        'featuredServices': [],
        'featuredDoctors': [],
        'latestArticles': [],
        'upcomingAppointment': raw
      });
      final catalog = FakeCatalogBackend().provider();
      await catalog.load();
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<ContentProvider>.value(value: p),
        ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ChangeNotifierProvider(create: (_) => PatientDataProvider()),
        ChangeNotifierProvider(
            create: (_) => UserProvider()..signInDemo('test')),
        ChangeNotifierProvider<ProfileProvider>(
            create: (_) => FakeProfileBackend().provider()),
      ], child: const MaterialApp(home: HomeScreen())));
      await tester.pumpAndSettle();
    }

    testWidgets('uses API catalog names and actual end time', (tester) async {
      await mount(tester, appointment({'endTime': '10:15'}));
      expect(find.text('Khám răng tổng quát'), findsWidgets);
      expect(find.text('BS. Nguyễn Văn API'), findsOneWidget);
      expect(find.text('09:00 - 10:15'), findsOneWidget);
    });
    testWidgets('prefers appointment snapshot names', (tester) async {
      await mount(
          tester,
          appointment({
            'doctorName': 'Bác sĩ trong lịch',
            'serviceName': 'Dịch vụ trong lịch',
            'durationMinutes': 60
          }));
      expect(find.text('Bác sĩ trong lịch'), findsOneWidget);
      expect(find.text('Dịch vụ trong lịch'), findsOneWidget);
      expect(find.text('09:00 - 10:00'), findsOneWidget);
    });
    testWidgets('unknown IDs use fallback instead of raw IDs or mock names',
        (tester) async {
      await mount(
          tester,
          appointment({
            'doctorId': 'unknown_doctor',
            'serviceIds': ['unknown_service']
          }));
      expect(find.text('Chưa có thông tin dịch vụ'), findsOneWidget);
      expect(find.text('Chưa có thông tin bác sĩ'), findsOneWidget);
      expect(find.text('unknown_doctor'), findsNothing);
      expect(find.text('unknown_service'), findsNothing);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('09:00 - 09:30'), findsNothing);
    });
    testWidgets('API mode never resolves IDs from demo catalog',
        (tester) async {
      await mount(
          tester,
          appointment({
            'doctorId': 'doctor-lan',
            'serviceIds': ['service-checkup']
          }));
      expect(find.text('Chưa có thông tin dịch vụ'), findsOneWidget);
      expect(find.text('Chưa có thông tin bác sĩ'), findsOneWidget);
    });
    testWidgets('missing doctor and services remain safe', (tester) async {
      await mount(tester, appointment({'doctorId': null, 'serviceIds': []}));
      expect(find.text('Chờ phân công'), findsOneWidget);
      expect(find.text('Dịch vụ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('missing duration does not inherit shared model default',
        (tester) async {
      await mount(tester, appointment());
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('09:00 - 09:30'), findsNothing);
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
}
