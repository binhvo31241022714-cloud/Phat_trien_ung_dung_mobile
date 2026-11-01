import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/models/patient.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/records_service.dart';
import 'package:frontend/features/records/records_widgets.dart';
import 'package:frontend/features/records/records_home_screen.dart';
import 'clinical_records_phase1_test.dart' show mount;

// All transport is MockClient: no auth token getter or external connections.
class RecordsFixture {
  final calls = <String>[];
  final overrides = <String, Object>{};
  Future<void> Function(String)? before;
  final rows = <String, Object>{
    '/api/patients/A/visits': [
      {'id': 'v', 'patientId': 'A'}
    ],
    '/api/patients/A/invoices': [
      {'id': 'i'}
    ],
    '/api/patients/A/treatments': [
      {'id': 't'}
    ],
    '/api/patients/A/follow-ups': [
      {'id': 'f', 'patientId': 'A'}
    ],
    '/api/visits/v': {'id': 'v', 'patientId': 'A'},
    '/api/visits/v/prescriptions': [
      {'id': 'rx', 'visitId': 'v', 'patientId': 'A', 'items': []}
    ],
    '/api/invoices/i': {
      'id': 'i',
      'patientId': 'A',
      'visitId': 'v',
      'items': []
    },
    '/api/treatments/t': {'id': 't', 'patientId': 'A'},
    '/api/treatments/t/sessions': [
      {'id': 's', 'patientId': 'A', 'treatmentId': 't'}
    ],
    '/api/follow-ups/f': {'id': 'f', 'patientId': 'A'},
  };
  late final client = ApiClient(client: MockClient((r) async {
    final path = r.url.path;
    calls.add(path);
    await before?.call(path);
    final value = overrides[path] ?? rows[path] ?? [];
    if (value is Exception) throw value;
    if (value is int) return http.Response('{"message":"failure"}', value);
    return http.Response(jsonEncode(value), 200,
        headers: {'content-type': 'application/json'});
  }));
  late final provider = PatientDataProvider(
      seedDemo: false, recordsService: RecordsService(client: client))
    ..syncPatients(const UserProfile(id: 'A', fullName: 'Owner'), []);
}

void main() {
  late AppConfig previous;
  setUp(() {
    previous = AppConfig.current;
    AppConfig.current =
        AppConfig.fromValues(source: 'api', baseUrl: 'http://fake.invalid');
  });
  tearDown(() => AppConfig.current = previous);
  RecordsFixture fixture() {
    final f = RecordsFixture();
    addTearDown(f.provider.dispose);
    return f;
  }

  test('normal snapshot: four lists + 2V + I + 2T, legacy optional fields',
      () async {
    final f = fixture();
    await f.provider.loadRecords();
    expect(f.calls.length, 9);
    expect(f.calls.toSet().length, 9);
    expect(f.provider.recordsError, isNull);
    expect(f.provider.unavailableRecords, 0);
    expect(f.provider.visits.single.id, 'v');
    expect(f.provider.prescriptions.single.id, 'rx');
    expect(f.provider.receipts.single.id, 'i');
    expect(f.provider.treatmentPlans.single.sessions.single.id, 's');
  });

  for (final path in [
    '/api/visits/v',
    '/api/visits/v/prescriptions',
    '/api/invoices/i',
    '/api/treatments/t',
    '/api/treatments/t/sessions'
  ]) {
    test('404 omits entire parent group: $path', () async {
      final f = fixture()..overrides[path] = 404;
      await f.provider.loadRecords();
      expect(f.provider.recordsError, isNull);
      expect(f.provider.unavailableRecords, 1);
      if (path.contains('/visits/')) {
        expect(f.provider.visits, isEmpty);
        expect(f.provider.prescriptions, isEmpty);
        expect(f.provider.receipts, hasLength(1));
      } else if (path.contains('/treatments/')) {
        expect(f.provider.treatmentPlans, isEmpty);
        expect(f.provider.visits, hasLength(1));
      } else {
        expect(f.provider.receipts, isEmpty);
      }
    });
  }
  testWidgets('partial warning and retry restore complete snapshot', (t) async {
    final f = fixture()..overrides['/api/invoices/i'] = 404;
    await f.provider.loadRecords();
    await t.pumpWidget(ChangeNotifierProvider.value(
        value: f.provider,
        child: const MaterialApp(
            home:
                RecordsPage(title: 'Records', children: [Text('Available')]))));
    expect(find.textContaining('Dữ liệu hồ sơ chưa đầy đủ'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    f.overrides.clear();
    await t.tap(find.text('Tải lại'));
    await t.pumpAndSettle();
    expect(find.textContaining('Dữ liệu hồ sơ chưa đầy đủ'), findsNothing);
    expect(f.provider.receipts, hasLength(1));
  });
  testWidgets('all details unavailable is error, never empty state', (t) async {
    final f = fixture();
    for (final p in ['/api/visits/v', '/api/invoices/i', '/api/treatments/t']) {
      f.overrides[p] = 404;
    }
    await f.provider.loadRecords();
    await t.pumpWidget(ChangeNotifierProvider.value(
        value: f.provider,
        child: const MaterialApp(
            home: RecordsPage(
                title: 'Records', children: [Text('Chưa có hồ sơ')]))));
    expect(find.text('Chưa có hồ sơ'), findsNothing);
    expect(find.textContaining('không còn khả dụng'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  for (final path in [
    '/api/patients/A/visits',
    '/api/patients/A/invoices',
    '/api/patients/A/treatments',
    '/api/patients/A/follow-ups'
  ]) {
    test('mandatory list 404 remains fatal: $path', () async {
      final f = fixture()..overrides[path] = 404;
      await f.provider.loadRecords();
      expect(f.provider.recordsError, isNotNull);
      expect(f.provider.visits, isEmpty);
      expect(f.provider.unavailableRecords, 0);
    });
  }
  for (final code in [401, 403, 500]) {
    for (final path in [
      '/api/visits/v',
      '/api/visits/v/prescriptions',
      '/api/invoices/i',
      '/api/treatments/t',
      '/api/treatments/t/sessions'
    ]) {
      test('fatal $code at $path never becomes partial success', () async {
        final f = fixture();
        await f.provider.loadRecords();
        f.overrides[path] = code;
        await f.provider.loadRecords();
        expect(f.provider.recordsError, isNotNull);
        expect(f.provider.visits, isEmpty);
        expect(f.provider.receipts, isEmpty);
        expect(f.provider.unavailableRecords, 0);
      });
    }
  }
  for (final error in [
    http.ClientException('offline'),
    TimeoutException('timeout')
  ]) {
    test('transport $error is fatal', () async {
      final f = fixture()..overrides['/api/invoices/i'] = error;
      await f.provider.loadRecords();
      expect(f.provider.recordsError, isNotNull);
      expect(f.provider.unavailableRecords, 0);
    });
  }
  final broken = <String, (String, Object)>{
    'list envelope': ('/api/patients/A/visits', {}),
    'list entry': ('/api/patients/A/visits', [null]),
    'missing id': ('/api/patients/A/visits', [{}]),
    'invalid id': (
      '/api/patients/A/visits',
      [
        {'id': '../v'}
      ]
    ),
    'dot id': (
      '/api/patients/A/visits',
      [
        {'id': '..'}
      ]
    ),
    'duplicate id': (
      '/api/patients/A/visits',
      [
        {'id': 'v'},
        {'id': 'v'}
      ]
    ),
    'detail envelope': ('/api/visits/v', []),
    'detail id': ('/api/visits/v', {'id': 'other', 'patientId': 'A'}),
    'cross patient': ('/api/invoices/i', {'id': 'i', 'patientId': 'other'}),
    'rx linkage': (
      '/api/visits/v/prescriptions',
      [
        {'id': 'rx', 'visitId': 'other'}
      ]
    ),
    'missing detail patient': ('/api/visits/v', {'id': 'v'}),
    'owner conflict': (
      '/api/visits/v',
      {'id': 'v', 'patientId': 'A', 'accountId': 'B'}
    ),
    'user conflict': (
      '/api/invoices/i',
      {'id': 'i', 'patientId': 'A', 'userId': 'B'}
    ),
    'rx malformed items': (
      '/api/visits/v/prescriptions',
      [
        {
          'id': 'rx',
          'items': [null]
        }
      ]
    ),
    'malformed services': (
      '/api/visits/v',
      {'id': 'v', 'patientId': 'A', 'serviceIds': {}}
    ),
    'sessions linkage': (
      '/api/treatments/t/sessions',
      [
        {'id': 's', 'treatmentId': 'other'}
      ]
    ),
  };
  for (final entry in broken.entries) {
    test('malformed ${entry.key} is fatal', () async {
      final f = fixture()..overrides[entry.value.$1] = entry.value.$2;
      await f.provider.loadRecords();
      expect(f.provider.recordsError, isNotNull);
      expect(f.provider.visits, isEmpty);
      expect(f.provider.unavailableRecords, 0);
    });
  }
  test('notification visit disappears on reload: no stale fallback', () async {
    final f = fixture();
    f.before = (path) async {
      if (path == '/api/patients/A/visits') f.overrides['/api/visits/v'] = 404;
    };
    await expectLater(f.provider.focusVisit('v'), throwsA(isA<ApiException>()));
    expect(f.provider.recordsVisit, isNull);
    expect(f.provider.recordsFocusVersion, 0);
  });
  test('notification reload preserves forbidden status', () async {
    final f = fixture();
    f.before = (path) async {
      if (path == '/api/patients/A/visits') f.overrides['/api/visits/v'] = 403;
    };
    await expectLater(
        f.provider.focusVisit('v'),
        throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
    expect(f.provider.recordsVisit, isNull);
  });
  test('notification followup missing from fresh list does not navigate',
      () async {
    final f = fixture()..overrides['/api/patients/A/follow-ups'] = [];
    await expectLater(
        f.provider.focusFollowUp('f'), throwsA(isA<ApiException>()));
    expect(f.provider.recordsFollowupsPatientId, isNull);
    expect(f.provider.recordsFocusVersion, 0);
  });
  test('session switch discards pending partial snapshot', () async {
    final f = fixture();
    final gate = Completer<void>();
    f.before = (path) async {
      if (path == '/api/visits/v') await gate.future;
    };
    final loading = f.provider.loadRecords();
    await Future<void>.delayed(Duration.zero);
    f.provider.clearPrivateState();
    f.provider.syncPatients(const UserProfile(id: 'B', fullName: 'B'), []);
    gate.complete();
    await loading;
    expect(f.provider.selectedPatientId, 'B');
    expect(f.provider.visits, isEmpty);
    expect(f.provider.unavailableRecords, 0);
  });
  test('newest reload wins over older partial snapshot', () async {
    final f = fixture();
    final gate = Completer<void>();
    var visits = 0;
    f.before = (path) async {
      if (path == '/api/visits/v' && ++visits == 1) await gate.future;
    };
    final old = f.provider.loadRecords();
    await Future<void>.delayed(Duration.zero);
    await f.provider.loadRecords();
    gate.complete();
    await old;
    expect(f.provider.recordsError, isNull);
    expect(f.provider.visits.single.id, 'v');
    expect(
        f.calls.where((p) => p == '/api/visits/v/prescriptions'), hasLength(1));
  });
  test('archived family partial snapshot remains read-only and isolated',
      () async {
    final f = fixture();
    f.provider.syncPatients(
        const UserProfile(id: 'owner', fullName: 'Owner'), [],
        historyFamily: [
          FamilyMember.fromJson({
            'id': 'A',
            'fullName': 'Archived',
            'relationship': 'Con',
            'isArchived': true
          })
        ]);
    f.provider.selectPatient('A', reload: false);
    f.overrides['/api/invoices/i'] = 404;
    await f.provider.loadRecords();
    expect(f.provider.isArchivedPatient('A'), isTrue);
    expect(f.provider.canWritePatient('A'), isFalse);
    expect(f.provider.recordsError, isNull);
    expect(f.provider.unavailableRecords, 1);
    expect(f.provider.visits.single.patientId, 'A');
  });
  test('owned orphan detail does not extend membership or list permission',
      () async {
    final f = fixture();
    f.overrides['/api/visits/v'] = {
      'id': 'v',
      'patientId': 'orphan',
      'accountId': 'A'
    };
    await expectLater(f.provider.focusVisit('v'), throwsA(isA<ApiException>()));
    expect(f.calls, ['/api/visits/v']);
    expect(f.provider.selectedPatientId, 'A');
    expect(f.provider.recordsVisit, isNull);
  });
  test('invoice linkage to loaded visit cannot contradict appointment',
      () async {
    final f = fixture();
    f.overrides['/api/visits/v'] = {
      'id': 'v',
      'patientId': 'A',
      'appointmentId': 'a'
    };
    f.overrides['/api/invoices/i'] = {
      'id': 'i',
      'patientId': 'A',
      'visitId': 'v',
      'appointmentId': 'b'
    };
    await f.provider.loadRecords();
    expect(f.provider.recordsError, isNotNull);
    expect(f.provider.receipts, isEmpty);
  });
  test('focus cannot navigate after a competing reload', () async {
    final f = fixture();
    final gate = Completer<void>();
    final started = Completer<void>();
    var lists = 0;
    f.before = (path) async {
      if (path == '/api/patients/A/visits' && ++lists == 1) {
        started.complete();
        await gate.future;
      }
    };
    final focusing = f.provider.focusVisit('v');
    await started.future;
    await f.provider.loadRecords();
    gate.complete();
    expect(await focusing, isFalse);
    expect(f.provider.recordsVisit, isNull);
    expect(f.provider.recordsFocusVersion, 0);
  });
  test('focus cannot navigate after logout', () async {
    final f = fixture();
    final gate = Completer<void>();
    final started = Completer<void>();
    f.before = (path) async {
      if (path == '/api/visits/v') {
        started.complete();
        await gate.future;
      }
    };
    final focusing = f.provider.focusVisit('v');
    await started.future;
    f.provider.clearPrivateState();
    gate.complete();
    expect(await focusing, isFalse);
    expect(f.provider.recordsVisit, isNull);
  });
  test('valid empty lists remain an ordinary empty snapshot', () async {
    final f = fixture();
    for (final key
        in f.rows.keys.where((key) => key.startsWith('/api/patients/'))) {
      f.overrides[key] = [];
    }
    await f.provider.loadRecords();
    expect(f.calls.length, 4);
    expect(f.provider.recordsError, isNull);
    expect(f.provider.unavailableRecords, 0);
  });
  test('contradictory list/detail appointment linkage is fatal', () async {
    final f = fixture();
    f.overrides['/api/patients/A/visits'] = [
      {'id': 'v', 'appointmentId': 'a'}
    ];
    f.overrides['/api/visits/v'] = {
      'id': 'v',
      'patientId': 'A',
      'appointmentId': 'b'
    };
    await f.provider.loadRecords();
    expect(f.provider.recordsError, isNotNull);
    expect(f.provider.visits, isEmpty);
  });
  testWidgets('Records selector change makes one set of list requests',
      (t) async {
    final f = fixture();
    // Use existing safe widget harness; self plus a second registry entry.
    f.provider.addFamilyMember(Patient(
        id: 'kid',
        fullName: 'Child',
        phone: '',
        dateOfBirth: DateTime(2010),
        relationship: 'Con'));
    await mount(t, f.provider, const RecordsHomeScreen());
    f.calls.clear();
    final selector = t.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>));
    selector.onChanged!('kid');
    await t.pumpAndSettle();
    expect(f.provider.selectedPatientId, 'kid');
    expect(f.calls, [
      '/api/patients/kid/visits',
      '/api/patients/kid/invoices',
      '/api/patients/kid/treatments',
      '/api/patients/kid/follow-ups',
    ]);
  });
}
