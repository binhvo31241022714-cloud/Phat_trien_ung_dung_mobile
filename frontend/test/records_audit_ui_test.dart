import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/records/exam_result_screen.dart';
import 'package:frontend/features/records/visit_detail_screen.dart';
import 'package:frontend/features/records/visit_history_screen.dart';
import 'package:frontend/features/records/payment_receipt_screen.dart';
import 'package:frontend/features/records/treatment_detail_screen.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'support/fake_catalog_backend.dart';

class ClinicalFixture extends PatientDataProvider {
  final visit = Visit.fromJson({
    'id': 'v',
    'patientId': 'p',
    'appointmentId': 'a',
    'result': 'Kết quả API'
  });
  final receipt =
      Receipt.fromJson({'id': 'invoice', 'patientId': 'p', 'visitId': 'v'});
  ClinicalFixture() : super(seedDemo: false) {
    syncPatients(
        const UserProfile(
            id: 'p', email: '', fullName: 'Bệnh nhân API', phone: ''),
        []);
  }
  @override
  Future<void> loadRecords({String? patientId}) async {}
  @override
  List<Visit> get visits => [visit];
  @override
  List<Receipt> get receipts => [receipt];
}

void main() {
  late AppConfig previous;
  setUp(() {
    previous = AppConfig.current;
    AppConfig.current = AppConfig.fromValues(
        source: 'api', baseUrl: 'http://fake.invalid:3000');
  });
  tearDown(() => AppConfig.current = previous);
  Future<void> mount(
      WidgetTester tester, ClinicalFixture data, Widget child) async {
    final catalog = FakeCatalogBackend().provider();
    await catalog.load();
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<PatientDataProvider>.value(value: data),
          ChangeNotifierProvider<CatalogProvider>(create: (_) => catalog),
        ],
        child: MaterialApp(
            home: child,
            onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => PaymentReceiptScreen(
                    receipt: settings.arguments! as Receipt)))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'A06/A16: visit-only invoice opens without cached appointment; dates remain absent',
      (t) async {
    final data = ClinicalFixture();
    await mount(t, data, VisitDetailScreen(visit: data.visit));
    expect(find.textContaining('Chưa cập nhật'), findsWidgets);
    expect(find.textContaining('1970'), findsNothing);
    await t.ensureVisible(find.text('Xem phiếu thanh toán'));
    await t.tap(find.text('Xem phiếu thanh toán'));
    await t.pumpAndSettle();
    expect(find.byType(PaymentReceiptScreen), findsOneWidget);
    expect(find.textContaining('Bệnh nhân API'), findsOneWidget);
    expect(find.textContaining('1970'), findsNothing);
  });
  testWidgets(
      'A21: API results are read-only; missing visit status is not completed',
      (t) async {
    final data = ClinicalFixture();
    await mount(t, data, const VisitHistoryScreen(patientId: 'p'));
    expect(find.text('Trạng thái chưa cập nhật'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsNothing);
    await mount(t, data, ExamResultScreen(visit: data.visit));
    expect(find.text('Thông tin hồ sơ · Chỉ đọc'), findsOneWidget);
    expect(find.textContaining('minh họa'), findsNothing);
    await mount(
        t,
        data,
        TreatmentDetailScreen(
            plan: TreatmentPlan.fromJson({
          'id': 't',
          'patientId': 'p',
          'totalSessions': 1,
        }, sessions: [
          TreatmentSession.fromJson({'status': 'completed'})
        ])));
    expect(find.text('Trạng thái chưa cập nhật'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'A21: explicitly marked demo result retains illustration label in API mode',
      (t) async {
    final data = ClinicalFixture();
    await mount(
        t, data, ExamResultScreen(visit: Visit.fromJson({'isDemo': true})));
    expect(find.text('Thông tin minh họa · Chỉ đọc'), findsOneWidget);
  });
}
