import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'support/fake_catalog_backend.dart';
import 'support/data_source_scope.dart';

void main() {
  late PatientDataProvider data;
  late AppointmentsProvider source;
  late CatalogProvider catalog;
  late List<Map<String, dynamic>> rows;
  int? error;
  Completer<void>? gate;
  int gets = 0;
  setUp(() {
    useDataSourceForTest(DataSource.api);
    rows = [
      for (final status in [
        'booked',
        'confirmed',
        'cancelled',
        'rejected',
        'completed',
        'unexpected'
      ])
        {
          'id': status,
          'accountId': 'A',
          'patientId': 'A',
          'status': status,
          'serviceIds': ['svc_01'],
          'doctorName': 'Bác sĩ API',
          'date': '2099-01-01',
          'startTime': '09:00',
        }
    ];
    error = null;
    gate = null;
    gets = 0;
    data = PatientDataProvider(seedDemo: false)
      ..syncPatients(
          const UserProfile(id: 'A', email: '', fullName: 'A', phone: ''), [])
      ..replaceAppointments(rows.map(Appointment.fromJson).toList());
    source = AppointmentsProvider(
        service: BookingService(client: ApiClient(client: MockClient((r) async {
      gets++;
      if (gate != null) await gate!.future;
      return http.Response(
          jsonEncode(error == null ? rows : {'message': 'Thử lại sau'}),
          error ?? 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }))));
    catalog = FakeCatalogBackend().provider();
  });
  tearDown(() {
    source.dispose();
    catalog.dispose();
    data.dispose();
  });
  Finder card(String id) => find.byKey(ValueKey('appointment-card-$id'));
  Finder tab(String text) => find.widgetWithText(Tab, text);
  Future<void> mount(WidgetTester t,
      {double width = 390, double height = 1800, double scale = 1}) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: data),
          ChangeNotifierProvider.value(value: source),
          ChangeNotifierProvider.value(value: catalog),
        ],
        child: MaterialApp(
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: child!),
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) =>
                  Scaffold(body: Text('Detail ${settings.arguments}'))),
          home: const AppointmentsScreen(patientId: 'A'),
        )));
    await t.pumpAndSettle();
  }

  Future<void> select(WidgetTester t, String label) async {
    await t.ensureVisible(tab(label));
    await t.tap(tab(label));
    await t.pumpAndSettle();
  }

  testWidgets(
      'three tabs filter statuses without relabeling rejected or losing history',
      (t) async {
    await mount(t);
    expect(find.byType(Tab), findsNWidgets(3));
    expect(card('booked'), findsOneWidget);
    expect(card('confirmed'), findsNothing);
    expect(card('completed'), findsOneWidget);
    expect(card('unexpected'), findsOneWidget);
    expect(card('rejected'), findsNothing);
    await select(t, 'Đã xác nhận');
    expect(card('confirmed'), findsOneWidget);
    expect(card('booked'), findsNothing);
    await select(t, 'Đã hủy');
    expect(card('cancelled'), findsOneWidget);
    expect(card('rejected'), findsOneWidget);
    expect(
        find.descendant(
            of: card('rejected'), matching: find.text('Bị từ chối')),
        findsOneWidget);
    expect(card('completed'), findsOneWidget);
    expect(find.text('Không xác định'), findsOneWidget);
    await select(t, 'Chờ xác nhận');
    expect(card('booked'), findsOneWidget);
    expect(data.appointments.length, 6);
    expect(gets, 0, reason: 'switching tabs is a local filter');
    await t.tap(card('completed'));
    await t.pumpAndSettle();
    expect(find.text('Detail completed'), findsOneWidget);
  });

  testWidgets(
      'refresh moves booked to confirmed, then cancelled; new creates stay pending',
      (t) async {
    rows.removeWhere((r) => r['id'] != 'booked');
    data.replaceAppointments(rows.map(Appointment.fromJson).toList());
    await mount(t);
    rows.single['status'] = 'confirmed';
    final refresh =
        t.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await t.pumpAndSettle();
    await refresh;
    expect(card('booked'), findsNothing);
    await select(t, 'Đã xác nhận');
    expect(card('booked'), findsOneWidget);
    rows.single['status'] = 'cancelled';
    final cancelRefresh =
        t.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
    await t.pumpAndSettle();
    await cancelRefresh;
    expect(card('booked'), findsNothing);
    await select(t, 'Đã hủy');
    expect(card('booked'), findsOneWidget);
    data.upsertApiAppointment(
        Appointment.fromJson({...rows.single, 'id': 'new', 'status': 'booked'}),
        generation: data.sessionGeneration);
    await select(t, 'Chờ xác nhận');
    expect(card('new'), findsOneWidget);
    expect(gets, 2);
  });

  testWidgets('each tab keeps loading, error, retry and empty states',
      (t) async {
    rows.clear();
    data.replaceAppointments([]);
    await mount(t);
    for (final label in ['Chờ xác nhận', 'Đã xác nhận', 'Đã hủy']) {
      await select(t, label);
      expect(find.text('Chưa có lịch hẹn.'), findsOneWidget);
      gate = Completer<void>();
      final load = source.load();
      await t.pump();
      expect(find.text('Đang tải lịch hẹn…'), findsOneWidget);
      error = 500;
      gate!.complete();
      await load;
      gate = null;
      await t.pumpAndSettle();
      expect(find.text('Yêu cầu thất bại (HTTP 500).'), findsOneWidget);
      error = null;
      await t.tap(find.text('Thử lại lịch hẹn'));
      await t.pumpAndSettle();
      expect(find.text('Chưa có lịch hẹn.'), findsOneWidget);
    }
  });

  testWidgets(
      'small Android with large text fits and old session cards disappear',
      (t) async {
    await mount(t, width: 320, height: 640, scale: 1.5);
    expect(t.takeException(), isNull);
    await select(t, 'Đã hủy');
    expect(t.takeException(), isNull);
    data.clearPrivateState();
    source.clear();
    data.syncPatients(
        const UserProfile(id: 'B', email: '', fullName: 'B', phone: ''), []);
    await t.pumpAndSettle();
    expect(find.byType(Tab), findsNothing);
    expect(card('cancelled'), findsNothing);
    expect(find.textContaining('không còn trong danh sách'), findsOneWidget);
  });
}
