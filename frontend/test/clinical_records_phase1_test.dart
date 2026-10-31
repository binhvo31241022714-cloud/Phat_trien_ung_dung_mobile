import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/data/services/records_service.dart';
import 'package:frontend/features/me/api_notifications_view.dart';
import 'package:frontend/features/records/followup_screen.dart';
import 'package:frontend/features/records/payment_receipt_screen.dart';
import 'package:frontend/features/records/records_home_screen.dart';
import 'package:frontend/features/records/treatment_list_screen.dart';
import 'package:frontend/features/records/visit_detail_screen.dart';
import 'package:frontend/features/records/visit_history_screen.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/content_provider.dart';
import 'support/fake_catalog_backend.dart';

/// Máy chủ giả trả hồ sơ khám đúng dạng backend giai đoạn 1 tạo ra
/// (visit_{id}, rx_{id}, inv_{id}), của người thân "kid".
class RecordsServer {
  int visitDetailCode = 200, visitsCode = 200, readCode = 200;
  int visitDetailCalls = 0, visitsCalls = 0;
  List<Map<String, dynamic>> visits = [
    {
      'id': 'visit_a1',
      'patientId': 'kid',
      'appointmentId': 'a1',
      'doctorId': 'doc_01',
      'doctorName': 'BS. Minh',
      'serviceIds': ['svc_01'],
      'scheduledAt': '2026-10-20T02:00:00Z',
      'status': 'completed',
      'diagnosis': 'Viêm nướu nhẹ',
      'result': 'Đã cạo vôi',
      'doctorNote': 'Tái khám sau 3 tháng',
    },
    {
      'id': 'visit_old',
      'patientId': 'kid',
      'scheduledAt': {'_seconds': 0},
      'diagnosis': 'Hồ sơ cũ thiếu trạng thái',
    },
    {
      'id': 'visit_pending',
      'patientId': 'kid',
      'scheduledAt': '2026-10-22T02:00:00Z',
      'status': 'pending',
    },
  ];
  http.Response ok(Object value) => http.Response(jsonEncode(value), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
  http.Response fail(int code) => http.Response(
      jsonEncode({'message': 'Lỗi máy chủ $code'}), code,
      headers: {'content-type': 'application/json; charset=utf-8'});

  late final client = ApiClient(client: MockClient((r) async {
    final path = r.url.path;
    if (path == '/api/patients/kid/visits') {
      visitsCalls++;
      return visitsCode == 200 ? ok(visits) : fail(visitsCode);
    }
    if (path.startsWith('/api/visits/') && path.endsWith('/prescriptions')) {
      final id = path.split('/')[3];
      return ok(id == 'visit_a1'
          ? [
              {
                'id': 'rx_a1',
                'visitId': 'visit_a1',
                'patientId': 'kid',
                'issuedAt': '2026-10-20T03:00:00Z',
                'items': [
                  {
                    'medicineName': 'Paracetamol 500mg',
                    'dosage': '1 viên/lần',
                    'frequency': '2 lần/ngày',
                    'durationDays': 3
                  }
                ]
              }
            ]
          : []);
    }
    if (path.startsWith('/api/visits/')) {
      final id = path.split('/')[3];
      if (id == 'visit_a1') visitDetailCalls++;
      if (id == 'visit_a1' && visitDetailCode != 200) {
        return fail(visitDetailCode);
      }
      return ok(visits.firstWhere((v) => v['id'] == id));
    }
    if (path == '/api/patients/kid/invoices') {
      return ok([
        {'id': 'inv_a1'}
      ]);
    }
    if (path == '/api/invoices/inv_a1') {
      return ok({
        'id': 'inv_a1',
        'visitId': 'visit_a1',
        'appointmentId': 'a1',
        'patientId': 'kid',
        'items': [
          {'name': 'Khám tổng quát', 'quantity': 1, 'unitPrice': 100000, 'amount': 100000}
        ],
        'subtotal': 100000,
        'discountAmount': 0,
        'totalAmount': 100000,
        'paymentStatus': 'paid',
        'paymentMethod': 'bank_transfer',
        'issuedAt': '2026-10-20T03:00:00Z',
      });
    }
    if (path == '/api/patients/kid/treatments') {
      return ok([
        {'id': 't_plan'},
        {'id': 't_run'}
      ]);
    }
    if (path == '/api/treatments/t_plan') {
      return ok({'id': 't_plan', 'patientId': 'kid', 'name': 'Niềng răng', 'status': 'planned', 'totalSessions': 2});
    }
    if (path == '/api/treatments/t_run') {
      return ok({'id': 't_run', 'patientId': 'kid', 'name': 'Tẩy trắng', 'status': 'in_progress', 'totalSessions': 2});
    }
    if (path == '/api/treatments/t_plan/sessions') {
      return ok([
        {'id': 't_plan_s1', 'treatmentId': 't_plan', 'patientId': 'kid', 'sessionNumber': 1, 'status': 'planned'}
      ]);
    }
    if (path == '/api/treatments/t_run/sessions') {
      return ok([
        {'id': 't_run_s1', 'treatmentId': 't_run', 'patientId': 'kid', 'sessionNumber': 1, 'status': 'completed', 'visitId': 'visit_a1'},
        {'id': 't_run_s2', 'treatmentId': 't_run', 'patientId': 'kid', 'sessionNumber': 2, 'status': 'planned'}
      ]);
    }
    if (path == '/api/patients/kid/follow-ups') {
      return ok([
        {'id': 'f_new', 'patientId': 'kid', 'scheduledAt': '2099-04-01T02:00:00Z', 'reason': 'Đề xuất mới', 'status': 'suggested'},
        {'id': 'f_old', 'patientId': 'kid', 'scheduledAt': '2099-05-01T02:00:00Z', 'reason': 'Đề xuất cũ', 'status': 'scheduled'},
        {'id': 'f_booked', 'patientId': 'kid', 'scheduledAt': '2099-06-01T02:00:00Z', 'reason': 'Đã đặt', 'status': 'booked'},
      ]);
    }
    if (path.startsWith('/api/patients/')) return ok([]);
    if (path == '/api/notifications') {
      return ok([
        {
          'id': 'a1_completed',
          'userId': 'A',
          'title': 'Đã có kết quả khám',
          'body': 'Kết quả lần khám đã sẵn sàng.',
          'type': 'visit_result',
          'refId': 'visit_a1',
          'isRead': false,
          'createdAt': '2026-10-20T03:00:00Z',
        }
      ]);
    }
    if (path == '/api/notifications/a1_completed/read') {
      return readCode == 200 ? ok({'id': 'a1_completed', 'isRead': true}) : fail(readCode);
    }
    if (path == '/api/notifications/unread-count') return ok({'count': 1});
    return fail(404);
  }));

  PatientDataProvider provider() => PatientDataProvider(
      seedDemo: false, recordsService: RecordsService(client: client))
    ..syncPatients(
        const UserProfile(id: 'A', email: '', fullName: 'Chủ tài khoản', phone: ''),
        [FamilyMember.fromJson({'id': 'kid', 'fullName': 'Bé Na'})]);
}

Future<void> mount(WidgetTester t, PatientDataProvider data, Widget page,
    {ContentProvider? content, AppointmentsProvider? appointments}) async {
  final catalog = FakeCatalogBackend().provider();
  await catalog.load();
  await t.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: data),
    ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
    if (appointments != null) ChangeNotifierProvider.value(value: appointments),
    if (content != null) ChangeNotifierProvider.value(value: content),
  ], child: MaterialApp(home: Scaffold(body: page))));
  await t.pumpAndSettle();
}

void main() {
  late AppConfig previous;
  setUp(() {
    previous = AppConfig.current;
    AppConfig.current = AppConfig.fromValues(
        source: 'api', baseUrl: 'http://fake.invalid:3000');
  });
  tearDown(() => AppConfig.current = previous);

  Future<PatientDataProvider> loaded(RecordsServer s) async {
    final data = s.provider()..selectPatient('kid');
    await data.loadRecords(patientId: 'kid');
    return data;
  }

  testWidgets('A21: nhãn trạng thái lần khám theo dữ liệu thật, ngày lỗi không hiện 1970',
      (t) async {
    final data = await loaded(RecordsServer());
    await mount(t, data, const VisitHistoryScreen(patientId: 'kid'));
    expect(find.text('Đã hoàn thành'), findsOneWidget);
    expect(find.text('Đang xử lý'), findsOneWidget);
    expect(find.text('Trạng thái chưa cập nhật'), findsOneWidget);
    expect(find.textContaining('20/10/2026'), findsOneWidget);
    expect(find.textContaining('Chưa có thời gian'), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);
    expect(find.textContaining('minh họa'), findsNothing);
  });

  testWidgets('trống và lỗi: "Chưa có hồ sơ khám", lỗi có Thử lại', (t) async {
    final s = RecordsServer()..visits = [];
    final data = await loaded(s);
    await mount(t, data, const VisitHistoryScreen(patientId: 'kid'));
    expect(find.text('Chưa có hồ sơ khám.'), findsOneWidget);

    s.visitsCode = 500;
    await data.loadRecords(patientId: 'kid');
    await t.pumpAndSettle();
    expect(data.recordsError, isNotNull);
    expect(find.text(data.recordsError!), findsOneWidget);
    s.visitsCode = 200;
    s.visits = [s.visits.isEmpty ? RecordsServer().visits.first : s.visits.first];
    await t.tap(find.text('Thử lại'));
    await t.pumpAndSettle();
    expect(find.text('Đã hoàn thành'), findsOneWidget);
  });

  testWidgets('kéo xuống để tải lại màn hồ sơ gọi lại API', (t) async {
    final s = RecordsServer();
    final data = await loaded(s);
    await mount(t, data, const VisitHistoryScreen(patientId: 'kid'));
    final before = s.visitsCalls;
    await t.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect(s.visitsCalls, before + 1);
  });

  testWidgets('liệu trình: Dự kiến, Đang điều trị theo status; tái khám cũ "scheduled" là Đã đề xuất',
      (t) async {
    await t.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final data = await loaded(RecordsServer());
    await mount(t, data, const TreatmentListScreen(patientId: 'kid'));
    expect(find.text('Dự kiến'), findsOneWidget);
    expect(find.text('Đang điều trị'), findsOneWidget);
    await mount(t, data, const FollowupScreen(patientId: 'kid'));
    expect(find.text('Đã đề xuất'), findsNWidgets(2));
    expect(find.text('Đã đặt lịch'), findsOneWidget);
  });

  testWidgets('A06: hóa đơn nối đúng lần khám qua visitId, nhãn thanh toán tiếng Việt',
      (t) async {
    final data = await loaded(RecordsServer());
    final visit = data.visits.firstWhere((v) => v.id == 'visit_a1');
    final receipt = data.receipts.single;
    expect(receipt.visitId, 'visit_a1');
    expect(receipt.appointmentId, 'a1');
    expect(receipt.belongsToVisit(visit), isTrue);
    expect(receipt.belongsToVisit(data.visits.firstWhere((v) => v.id == 'visit_pending')), isFalse);
    await mount(t, data, PaymentReceiptScreen(receipt: receipt));
    expect(find.text('Hình thức: Chuyển khoản'), findsOneWidget);
    expect(find.text('Trạng thái: Đã thanh toán'), findsOneWidget);
    expect(find.textContaining('minh họa'), findsNothing);
  });

  testWidgets('A10: lần khám chưa hoàn tất không có nút thêm vào liệu trình', (t) async {
    final data = await loaded(RecordsServer());
    await mount(t, data,
        VisitDetailScreen(visit: data.visits.firstWhere((v) => v.id == 'visit_pending')));
    expect(find.text('Thêm vào liệu trình khám'), findsNothing);
    await mount(t, data,
        VisitDetailScreen(visit: data.visits.firstWhere((v) => v.id == 'visit_a1')));
    expect(find.text('Thêm vào liệu trình khám'), findsOneWidget);
    expect(find.text('Xem đơn thuốc'), findsOneWidget);
    expect(find.text('Xem phiếu thanh toán'), findsOneWidget);
    expect(find.textContaining('20/10/2026 · 09:00'), findsOneWidget);
  });

  group('thông báo visit_result', () {
    Future<(PatientDataProvider, ContentProvider)> open(
        WidgetTester t, RecordsServer s) async {
      final data = s.provider();
      final content = ContentProvider(service: ContentService(client: s.client))
        ..setAccount('A');
      final appointments =
          AppointmentsProvider(service: BookingService(client: s.client));
      await mount(t, data, const ApiNotificationsView(),
          content: content, appointments: appointments);
      await t.tap(find.text('Đã có kết quả khám'));
      await t.pumpAndSettle();
      return (data, content);
    }

    testWidgets('tải lần khám, chọn đúng người thân, tải hồ sơ rồi mở chi tiết lần khám',
        (t) async {
      final s = RecordsServer()..readCode = 500;
      final (data, content) = await open(t, s);
      expect(s.visitDetailCalls, greaterThanOrEqualTo(1));
      expect(data.selectedPatientId, 'kid');
      expect(data.recordsVisit?.id, 'visit_a1');
      expect(data.prescriptions.map((p) => p.id), ['rx_a1']);
      // Đánh dấu đã đọc lỗi vẫn mở được.
      expect(content.errors['read'], isNotNull);
      expect(t.takeException(), isNull);

      // Tab Hồ sơ nhận yêu cầu và mở đúng màn chi tiết lần khám.
      await mount(t, data, const RecordsHomeScreen(),
          appointments: AppointmentsProvider(service: BookingService(client: s.client)));
      expect(find.byType(VisitDetailScreen), findsOneWidget);
      expect(find.text('Chi tiết lần khám'), findsWidgets);
      expect(find.text('Viêm nướu nhẹ'), findsOneWidget);
      expect(find.text('Đã hoàn thành'), findsOneWidget);
    });

    for (final code in [403, 404]) {
      testWidgets('lần khám trả $code: báo lỗi, không mở', (t) async {
        final s = RecordsServer()..visitDetailCode = code;
        final (data, _) = await open(t, s);
        expect(data.recordsVisit, isNull);
        expect(find.text('Lỗi máy chủ $code'), findsOneWidget);
      });
    }
  });
}
