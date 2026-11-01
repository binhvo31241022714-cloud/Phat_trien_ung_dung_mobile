import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/records_service.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/records/records_home_screen.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'package:frontend/features/records/appointment_detail_screen.dart';
import 'package:frontend/data/models/appointment.dart';
import 'support/fake_appointments_provider.dart';
import 'support/api_app_fixture.dart';
import 'booking_api_sync_test.dart' show draft;
import 'package:frontend/features/records/visit_detail_screen.dart';
import 'package:frontend/features/records/followup_screen.dart';
import 'package:frontend/features/records/treatment_detail_screen.dart';
import 'package:frontend/features/records/payment_receipt_screen.dart';
import 'package:frontend/features/records/prescription_screen.dart';
import 'clinical_records_phase1_test.dart' show RecordsServer, mount;

const owner = UserProfile(id: 'A', fullName: 'Owner');
FamilyMember member(bool archived) => FamilyMember.fromJson({
      'id': 'kid',
      'fullName': 'Bé Na',
      'relationship': 'Con',
      'isArchived': archived,
    });
void archive(PatientDataProvider p) =>
    p.syncPatients(owner, [], historyFamily: [member(true)]);

void main() {
  late AppConfig previous;
  setUp(() {
    previous = AppConfig.current;
    AppConfig.current = AppConfig.fromValues(
        source: 'api', baseUrl: 'http://fake.invalid:3000');
  });
  tearDown(() => AppConfig.current = previous);
  Future<PatientDataProvider> loaded() async {
    final p = RecordsServer().provider();
    archive(p);
    p.selectPatient('kid');
    await p.loadRecords();
    addTearDown(p.dispose);
    return p;
  }

  test(
      'registry keeps archived history separate from booking and preserves selection on archive',
      () async {
    final p = RecordsServer().provider();
    addTearDown(p.dispose);
    p.syncPatients(owner, [member(false)], historyFamily: [member(false)]);
    p.selectPatient('kid');
    p.focusAppointmentsFor('kid');
    archive(p);
    expect(p.patients.map((p) => p.id), ['A']);
    expect(p.recordsPatients.map((p) => p.id), ['A', 'kid']);
    expect(p.recordsPatient.id, 'kid');
    expect(p.selectedPatient.isArchived, isTrue);
    expect(p.canWritePatient('kid'), isFalse);
    await p.loadRecords();
    expect(p.visitsFor('kid'), isNotEmpty);
    expect(p.receipts, isNotEmpty);
    expect(p.prescriptions, isNotEmpty);
    expect(p.treatmentPlans, isNotEmpty);
    expect(p.followupsFor('kid'), isNotEmpty);
  });

  test('active registry refresh cannot reset archived Records selection',
      () async {
    final p = await loaded();
    p.syncPatients(owner, []);
    expect(p.selectedPatient.id, 'kid');
    expect(p.isArchivedPatient('kid'), isTrue);
    p.requestBookingFor('kid');
    expect(p.takeBookingPatientRequest(), isNull);
  });

  test('pending archived booking rejected before HTTP, retains patient ID',
      () async {
    final p = await loaded();
    var writes = 0;
    final c = BookingController(p, initialPatientId: 'kid', bookingService:
        BookingService(client: ApiClient(client: MockClient((_) async {
      writes++;
      return http.Response('{}', 200);
    }))));
    addTearDown(c.dispose);
    await expectLater(c.submit(), throwsA(isA<ApiException>()));
    expect(c.patientId, 'kid');
    expect(writes, 0);
  });

  test('direct archived link action fails without calling writer', () async {
    final p = await loaded();
    await expectLater(
        p.linkVisitToTreatment(
            treatmentId: 't_plan', visitId: 'visit_a1', sessionId: 't_plan_s1'),
        throwsA(isA<ApiException>()));
  });

  test('visit notification focus opens archived patient with its documents',
      () async {
    final p = await loaded();
    expect(await p.focusVisit('visit_a1'), isTrue);
    expect(p.recordsPatient.id, 'kid');
    expect(p.recordsVisit!.id, 'visit_a1');
    expect(p.prescriptions.first.patientId, 'kid');
  });

  test('follow-up notification focus accepts archived membership', () async {
    final p = PatientDataProvider(
        seedDemo: false,
        recordsService: RecordsService(
            client: ApiClient(
                client: MockClient((r) async => http.Response(
                    jsonEncode(r.url.path == '/api/follow-ups/f'
                        ? {'id': 'f', 'patientId': 'kid', 'status': 'suggested'}
                        : r.url.path == '/api/patients/kid/follow-ups'
                            ? [
                                {
                                  'id': 'f',
                                  'patientId': 'kid',
                                  'status': 'suggested'
                                }
                              ]
                            : []),
                    200)))));
    addTearDown(p.dispose);
    archive(p);
    expect(await p.focusFollowUp('f'), isTrue);
    expect(p.recordsPatient.id, 'kid');
    expect(p.recordsFollowupsPatientId, 'kid');
  });

  test('removed membership rejects notification without switching to self',
      () async {
    final p = RecordsServer().provider();
    addTearDown(p.dispose);
    p.syncPatients(owner, [], historyFamily: []);
    await expectLater(p.focusVisit('visit_a1'), throwsA(isA<ApiException>()));
    expect(p.recordsVisit, isNull);
  });

  test('session switch clears archived registry, focus and rejects stale read',
      () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final p = PatientDataProvider(
        seedDemo: false,
        recordsService:
            RecordsService(client: ApiClient(client: MockClient((r) {
          if (!started.isCompleted) started.complete();
          return response.future;
        }))));
    addTearDown(p.dispose);
    archive(p);
    p.selectPatient('kid');
    final pending = p.loadRecords();
    await started.future;
    p.clearPrivateState();
    p.syncPatients(const UserProfile(id: 'B'), [], historyFamily: []);
    response.complete(http.Response('[]', 200));
    await pending;
    expect(p.recordsPatients.map((p) => p.id), ['B']);
    expect(p.selectedPatient.id, 'B');
    expect(p.recordsVisit, isNull);
    expect(p.recordsFollowupsPatientId, isNull);
    expect(p.visits, isEmpty);
  });

  testWidgets('Records selector labels archived and retains focus', (t) async {
    final p = await loaded();
    p.focusAppointmentsFor('kid');
    await mount(t, p, const RecordsHomeScreen());
    expect(find.textContaining('Đã lưu trữ · Chỉ xem lịch sử'), findsWidgets);
    expect(p.recordsPatient.id, 'kid');
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'archived Visit shows result/prescription/invoice but no link action',
      (t) async {
    final p = await loaded();
    await mount(t, p, VisitDetailScreen(visit: p.visits.first));
    expect(find.text('Xem đơn thuốc'), findsOneWidget);
    expect(find.text('Thêm vào liệu trình'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('archived Follow-ups remain readable without rebooking',
      (t) async {
    final p = await loaded();
    await mount(t, p, const FollowupScreen(patientId: 'kid'));
    expect(find.text('Đề xuất mới'), findsOneWidget);
    expect(find.text('Đặt lịch tái khám'), findsNothing);
  });

  testWidgets('archived clinical detail parsers and screens remain readable',
      (t) async {
    final p = await loaded();
    await mount(t, p, TreatmentDetailScreen(plan: p.treatmentPlans.first));
    expect(t.takeException(), isNull);
    await mount(t, p, PaymentReceiptScreen(receipt: p.receipts.first));
    expect(t.takeException(), isNull);
    expect(find.textContaining('Bé Na'), findsOneWidget);
    await mount(t, p, PrescriptionScreen(prescription: p.prescriptions.first));
    expect(find.textContaining('Paracetamol'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'archived appointment history and detail open without active lookup or booking CTA',
      (t) async {
    final p = await loaded();
    p.upsertApiAppointment(
        Appointment.fromJson({
          'id': 'a_old',
          'accountId': 'A',
          'patientId': 'kid',
          'date': '2026-10-20',
          'startTime': '09:00',
          'status': 'completed',
        }),
        generation: p.sessionGeneration);
    final appointments = FakeAppointmentsProvider();
    addTearDown(appointments.dispose);
    await mount(t, p, const AppointmentsScreen(patientId: 'kid'),
        appointments: appointments);
    expect(find.text('Đặt lịch khám'), findsNothing);
    expect(t.takeException(), isNull);
    await mount(t, p, const AppointmentDetailScreen(appointmentId: 'a_old'),
        appointments: appointments);
    expect(find.textContaining('Bé Na'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  test('archive during quote prevents POST and preserves pending patient',
      () async {
    final p = RecordsServer().provider();
    addTearDown(p.dispose);
    final quote = Completer<http.Response>();
    final started = Completer<void>();
    var posts = 0;
    final service = BookingService(client: ApiClient(client: MockClient((r) {
      if (r.method == 'POST' && r.url.path == '/api/appointments') posts++;
      if (!started.isCompleted) started.complete();
      return quote.future;
    })));
    final c = draft(p, service)..selectPatient('kid');
    addTearDown(c.dispose);
    final pending = c.submit();
    final assertion = expectLater(pending, throwsA(isA<ApiException>()));
    await started.future;
    archive(p);
    quote.complete(http.Response(
        jsonEncode({
          'subtotal': 100000,
          'discount': 0,
          'totalPrice': 100000,
          'durationMinutes': 45
        }),
        200));
    await assertion;
    expect(posts, 0);
    expect(c.patientId, 'kid');
  });

  testWidgets(
      'MainShell loads history query but booking selector stays active-only',
      (t) async {
    final fixture = ApiAppFixture();
    fixture.family.add(
        {'id': 'archived-api', 'fullName': 'Archived API', 'isArchived': true});
    await fixture.mount(t);
    expect(fixture.requests.any((r) => r.url.query == 'includeArchived=true'),
        isTrue);
    expect(fixture.profiles.family.map((p) => p.id), ['relative-api']);
    expect(
        fixture.records.patients.any((p) => p.id == 'archived-api'), isFalse);
    expect(
        fixture.records.recordsPatients
            .any((p) => p.id == 'archived-api' && p.isArchived),
        isTrue);
    await t.tap(find.text('Đặt lịch').last);
    await t.pumpAndSettle();
    expect(find.textContaining('Archived API'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
