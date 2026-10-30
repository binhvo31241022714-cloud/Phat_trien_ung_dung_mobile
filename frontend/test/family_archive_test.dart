import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';

import 'me_test.dart' show demoUsers, openMe, pumpMe, setBirthday;
import 'support/fake_appointments_provider.dart';
import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';

/// Hồ sơ khám không tải từ API trong test này (chỉ kiểm tra danh sách người khám).
class _NoRecords extends PatientDataProvider {
  _NoRecords() : super(seedDemo: false);
  @override
  Future<void> loadRecords({String? patientId}) async {}
}

/// Nội dung trang chủ/thông báo rỗng, không gọi mạng.
ContentProvider _emptyContent() => ContentProvider(
    service: ContentService(
        client: ApiClient(
            baseUrl: 'http://fake.invalid:3000',
            client: MockClient((r) async => http.Response(
                jsonEncode(r.url.path.endsWith('unread-count')
                    ? {'count': 0}
                    : r.url.path == '/api/home'
                        ? <String, dynamic>{}
                        : <dynamic>[]),
                200,
                headers: {'content-type': 'application/json'})))));

/// MainShell ở chế độ API với backend giả, không gọi mạng.
Future<void> _pumpShell(WidgetTester tester, PatientDataProvider records,
    ProfileProvider profile) async {
  await tester.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider<UserProvider>.value(value: demoUsers()),
    ChangeNotifierProvider<PatientDataProvider>.value(value: records),
    ChangeNotifierProvider<ProfileProvider>.value(value: profile),
    ChangeNotifierProvider<CatalogProvider>(
        create: (_) => FakeCatalogBackend().provider()),
    ChangeNotifierProvider<AppointmentsProvider>(
        create: (_) => FakeAppointmentsProvider()),
    ChangeNotifierProvider<ContentProvider>(create: (_) => _emptyContent()),
  ], child: MaterialApp(theme: AppTheme.light, home: const MainShell())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'delete dialog says old records are kept; 409 shows the server message',
      (tester) async {
    final backend = FakeProfileBackend(family: [
      {'id': 'fam-1', 'fullName': 'Bé Na', 'relationship': 'Con'}
    ])
      ..withUpcomingAppointments.add('fam-1');
    await pumpMe(tester, demoUsers(), PatientDataProvider(),
        profile: backend.provider());
    await openMe(tester, 'Quản lý người thân');

    await openMe(tester, 'Xóa người thân');
    expect(
        find.text('Xóa Bé Na khỏi danh sách người thân? '
            'Hồ sơ khám, hóa đơn và lịch hẹn cũ của người này vẫn được giữ.'),
        findsOneWidget);
    await openMe(tester, 'Xác nhận xóa');
    expect(find.text('Chưa xóa được: ${FakeProfileBackend.upcomingMessage}'),
        findsOneWidget);
    expect(backend.family, hasLength(1));
    expect(find.text('Bé Na'), findsOneWidget);

    // Hủy lịch xong thì xóa được.
    backend.withUpcomingAppointments.clear();
    ScaffoldMessenger.of(tester.element(find.text('Bé Na')))
        .removeCurrentSnackBar();
    await openMe(tester, 'Xóa người thân');
    await openMe(tester, 'Xác nhận xóa');
    expect(find.text('Đã xóa người thân.'), findsOneWidget);
    expect(backend.family, isEmpty);
    expect(tester.takeException(), isNull);
  });

  group('API mode', () {
    late AppConfig previous;
    setUp(() {
      previous = AppConfig.current;
      AppConfig.current = AppConfig.fromValues(
          source: 'api', baseUrl: 'http://fake.invalid:3000');
    });
    tearDown(() => AppConfig.current = previous);

    testWidgets('family added from the Me tab appears in the Records dropdown',
        (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpShell(tester, _NoRecords(), FakeProfileBackend().provider());

      // Mở Hồ sơ một lần trước (giống người dùng đã xem tab này).
      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Bé Na (Con)'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tôi').last);
      await tester.pumpAndSettle();
      await openMe(tester, 'Quản lý người thân');
      await openMe(tester, 'Thêm người thân');
      await tester.enterText(find.byType(TextFormField).first, 'Bé Na');
      await setBirthday(tester);
      await openMe(tester, 'Lưu người thân');
      expect(find.text('Bé Na'), findsOneWidget);

      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Bé Na (Con)'), findsWidgets);

      // Đang xem hồ sơ của Bé Na thì xóa Bé Na ở tab Tôi.
      await tester.tap(find.text('Bé Na (Con)').last);
      await tester.pumpAndSettle();
      expect(find.text('Bé Na'), findsOneWidget);
      await tester.tap(find.text('Tôi').last);
      await tester.pumpAndSettle();
      await openMe(tester, 'Xóa người thân');
      await openMe(tester, 'Xác nhận xóa');
      expect(find.text('Đã xóa người thân.'), findsOneWidget);

      // Tab Hồ sơ không lỗi, quay về "Bản thân", danh sách không còn Bé Na.
      await tester.tap(find.text('Hồ sơ').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Trần Thị Test'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('Bé Na (Con)'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('syncPatients moves Records off a removed relative', () {
      final records = _NoRecords();
      const me = UserProfile(
          id: 'uid-test', email: '', fullName: 'Tôi', phone: '');
      records.syncPatients(me, const [FamilyMember(id: 'fam-1', fullName: 'A')]);
      records.focusAppointmentsFor('fam-1', showAppointments: true);
      records.requestBookingFor('fam-1');
      final version = records.recordsFocusVersion;

      records.syncPatients(me, const []);
      expect(records.appointmentPatientId, 'uid-test');
      expect(records.recordsPatient.id, 'uid-test');
      expect(records.recordsShowAppointments, isFalse);
      expect(records.recordsFocusVersion, version + 1);
      expect(records.takeBookingPatientRequest(), 'uid-test');

      // Người vẫn còn thì không đổi gì.
      records.syncPatients(me, const [FamilyMember(id: 'fam-2', fullName: 'B')]);
      records.focusAppointmentsFor('fam-2');
      final kept = records.recordsFocusVersion;
      records.syncPatients(me, const [FamilyMember(id: 'fam-2', fullName: 'B2')]);
      expect(records.appointmentPatientId, 'fam-2');
      expect(records.recordsFocusVersion, kept);
      records.dispose();
    });

    testWidgets('add, edit and delete family update patients without restart',
        (tester) async {
      final records = _NoRecords();
      final profile = FakeProfileBackend().provider();
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<UserProvider>.value(value: demoUsers()),
        ChangeNotifierProvider<PatientDataProvider>.value(value: records),
        ChangeNotifierProvider<ProfileProvider>.value(value: profile),
        ChangeNotifierProvider<CatalogProvider>(
            create: (_) => FakeCatalogBackend().provider()),
        ChangeNotifierProvider<AppointmentsProvider>(
            create: (_) => FakeAppointmentsProvider()),
        ChangeNotifierProvider<ContentProvider>(
            create: (_) => _emptyContent()),
      ], child: MaterialApp(theme: AppTheme.light, home: const MainShell())));
      await tester.pumpAndSettle();
      List<String> names() => [for (final p in records.patients) p.fullName];
      expect(names(), ['Trần Thị Test']);

      expect(
          await profile.addFamily(const FamilyMember(
              id: '', fullName: 'Bé Na', relationship: 'Con')),
          isNull);
      await tester.pumpAndSettle();
      expect(names(), ['Trần Thị Test', 'Bé Na']);
      final id = profile.family.single.id;

      records.selectPatient(id);
      expect(
          await profile.updateFamily(FamilyMember(
              id: id, fullName: 'Bé Na Na', relationship: 'Con')),
          isNull);
      await tester.pumpAndSettle();
      expect(names(), ['Trần Thị Test', 'Bé Na Na']);
      expect(records.selectedPatientId, id);

      expect(await profile.deleteFamily(id), isNull);
      await tester.pumpAndSettle();
      expect(names(), ['Trần Thị Test']);
      // Người đang chọn bị xóa thì quay về "Bản thân".
      expect(records.selectedPatientId, 'uid-test');
      expect(tester.takeException(), isNull);
    });
  });
}
