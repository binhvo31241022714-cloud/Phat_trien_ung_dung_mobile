import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/providers/user_provider.dart';

import 'support/fake_profile_backend.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/data/models/patient.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/records/records_widgets.dart';
import 'package:frontend/features/records/visit_detail_screen.dart';
import 'package:frontend/features/records/exam_result_screen.dart';

Future<void> pumpShell(WidgetTester tester, PatientDataProvider data,
    {double width = 390}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: data,
      child: MultiProvider(providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FakeProfileBackend().provider()),
      ], child: MaterialApp(theme: AppTheme.light, home: const MainShell()))));
  await tester.tap(find.text('Hồ sơ').last);
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Appointment newAppointment(PatientDataProvider data,
        {String id = 'record-test',
        String? patientId,
        AppointmentStatus status = AppointmentStatus.pending,
        DateTime? at}) =>
    Appointment(
      id: id,
      patientId: patientId ?? data.patients.first.id,
      serviceIds: [data.services.first.id, data.services[1].id],
      scheduledAt: at ?? DateTime.now().add(const Duration(minutes: 90)),
      status: status,
      totalPrice: data.services.first.price + data.services[1].price,
      note: 'Ghi chú kiểm thử',
    );

void main() {
  test('filter every collection and stable appointment ordering by patient',
      () {
    final d = PatientDataProvider();
    final now = DateTime(2026, 10, 21);
    final first = d.patients.first.id;
    final child = d.patients.last.id;
    expect(d.appointmentsFor(first, now: now).map((a) => a.patientId).toSet(),
        {first});
    expect(d.appointmentsFor(child, now: now).map((a) => a.patientId).toSet(),
        {child});
    expect(d.appointmentsFor(first, now: now).first.status,
        AppointmentStatus.confirmed);
    expect(d.visitsFor(child), isEmpty);
    expect(d.treatmentsFor(child), isEmpty);
    expect(d.followupsFor(child), isEmpty);
    d.focusAppointmentsFor(child);
    expect(d.recordsPatient.id, child);
    expect(d.selectedPatient.id, first);
    expect(d.visitsFor(first), hasLength(1));
  });
  test(
      'cancel preserves fields and notifies; completed, cancelled and past cannot cancel',
      () {
    final d = PatientDataProvider();
    final a = newAppointment(d);
    d.addAppointment(a);
    final count = d.appointments.length;
    var notifications = 0;
    d.addListener(() => notifications++);
    expect(d.cancelAppointment(a.id), isTrue);
    final cancelled = d.appointments.firstWhere((v) => v.id == a.id);
    expect(cancelled.status, AppointmentStatus.cancelled);
    expect(cancelled.totalPrice, a.totalPrice);
    expect(cancelled.serviceIds, a.serviceIds);
    expect(cancelled.patientId, a.patientId);
    expect(cancelled.note, a.note);
    expect(d.appointments.length, count);
    expect(notifications, 1);
    expect(d.cancelAppointment(a.id), isFalse);
    for (final status in [
      AppointmentStatus.completed,
      AppointmentStatus.cancelled
    ]) {
      final b = newAppointment(d, id: status.name, status: status);
      d.addAppointment(b);
      expect(d.cancelAppointment(b.id), isFalse);
    }
    final past = newAppointment(d,
        id: 'past', at: DateTime.now().subtract(const Duration(days: 1)));
    d.addAppointment(past);
    expect(d.cancelAppointment(past.id), isFalse);
  });
  test('treatment progress is calculated with zero and out-of-range guards',
      () {
    TreatmentPlan plan(int completed, int total) => TreatmentPlan(
        id: 'test',
        patientId: 'test',
        title: 'Test',
        description: '',
        completedVisits: completed,
        totalVisits: total);
    expect(plan(3, 12).progress, .25);
    expect(plan(0, 0).progress, 0);
    expect(plan(5, 2).progress, 1);
  });
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets(
        'overview filters relatives, counts and keeps account at $width',
        (tester) async {
      final d = PatientDataProvider();
      await pumpShell(tester, d, width: width);
      expect(find.text('Hồ sơ nha khoa'), findsOneWidget);
      expect(
          find.text('${d.patients.first.fullName} (Bản thân)'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        final counts = [
          d
              .appointmentsFor(d.patients.first.id)
              .where((a) =>
                  a.status == AppointmentStatus.pending ||
                  a.status == AppointmentStatus.confirmed)
              .length,
          d.visitsFor(d.patients.first.id).length,
          d.treatmentsFor(d.patients.first.id).length
        ];
        expect(
            tester.widget<Text>(find.byKey(ValueKey('records-count-$i'))).data,
            '${counts[i]}');
      }
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find
          .text('${d.patients.last.fullName} (${d.patients.last.relationship})')
          .last);
      await tester.pumpAndSettle();
      expect(d.recordsPatient.id, d.patients.last.id);
      expect(d.selectedPatient.id, d.patients.first.id);
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('records-count-1')))
              .data,
          '0');
      await open(tester, 'Lịch hẹn');
      expect(find.text('Lịch hẹn của ${d.patients.last.fullName}'),
          findsOneWidget);
      expect(find.text(serviceNames(d, d.appointments.first.serviceIds)),
          findsNothing);
      await back(tester);
      await open(tester, 'Lịch sử khám');
      expect(find.text('Chưa có lịch sử khám.'), findsOneWidget);
      await back(tester);
      await open(tester, 'Liệu trình điều trị');
      expect(find.text('Chưa có liệu trình điều trị.'), findsOneWidget);
      await back(tester);
      await open(tester, 'Lịch tái khám');
      expect(find.text('Chưa có lịch tái khám được đề xuất.'), findsOneWidget);
      await tester.tap(find.text('Tôi').last);
      await tester.pumpAndSettle();
      expect(find.text(d.patients.first.fullName), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
        'visit, prescription, receipt, treatment photos and back fit $width',
        (tester) async {
      final d = PatientDataProvider();
      await pumpShell(tester, d, width: width);
      await open(tester, 'Lịch sử khám');
      expect(find.text('Đã hoàn thành'), findsOneWidget);
      final visit = d.visits.first;
      await open(tester, visitServices(d, visit));
      expect(find.text(visit.diagnosis), findsOneWidget);
      expect(find.text(visit.note), findsOneWidget);
      expect(find.text(missingRecordInfo), findsOneWidget);
      expect(find.text('Xem kết quả khám'), findsNothing);
      await open(tester, 'Xem đơn thuốc');
      expect(find.text('Không có thuốc được ghi nhận trong đơn này.'),
          findsOneWidget);
      expect(find.text(d.prescriptions.first.instructions), findsOneWidget);
      await back(tester);
      await open(tester, 'Xem phiếu thanh toán');
      expect(find.text('Tổng tiền: 150.000 ₫'), findsOneWidget);
      expect(find.text('Đã thanh toán'), findsNothing);
      await back(tester);
      await back(tester);
      await back(tester);
      await open(tester, 'Liệu trình điều trị');
      expect(
          tester
              .widget<LinearProgressIndicator>(
                  find.byType(LinearProgressIndicator))
              .value,
          d.treatmentPlans.first.progress);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      await open(tester, 'Xem ảnh trước – sau');
      expect(find.byIcon(Icons.image_outlined), findsNWidgets(2));
      expect(find.text('Ảnh minh họa chưa được tải lên.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Liệu trình điều trị'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'live shared appointment, confirmation, cancellation and Home update',
      (tester) async {
    final d = PatientDataProvider();
    await pumpShell(tester, d);
    final count = d.appointments.length;
    final a = newAppointment(d);
    d.addAppointment(a);
    await tester.pumpAndSettle();
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('records-count-0'))).data,
        '2');
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(find.text('Chờ phân công'), findsOneWidget);
    await tester.tap(find.text('Hồ sơ').last);
    await tester.pumpAndSettle();
    await open(tester, 'Lịch hẹn');
    await open(tester, serviceNames(d, a.serviceIds));
    expect(find.text('Mã lịch hẹn: ${a.id}'), findsOneWidget);
    await open(tester, 'Hủy lịch');
    expect(find.byType(AlertDialog), findsOneWidget);
    await open(tester, 'Giữ lịch');
    expect(d.appointments.firstWhere((v) => v.id == a.id).status,
        AppointmentStatus.pending);
    await open(tester, 'Hủy lịch');
    await open(tester, 'Xác nhận hủy');
    expect(find.text('Đã hủy'), findsOneWidget);
    expect(find.text('Hủy lịch'), findsNothing);
    expect(d.appointments.length, count + 1);
    await back(tester);
    expect(find.text('Đã hủy'), findsOneWidget);
    await back(tester);
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('records-count-0'))).data,
        '1');
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(find.text('Chờ phân công'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'followup and empty appointments open booking for correct patient without submitting',
      (tester) async {
    final d = PatientDataProvider();
    await pumpShell(tester, d);
    final count = d.appointments.length;
    await open(tester, 'Lịch tái khám');
    await open(tester, 'Đặt lịch tái khám');
    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);
    expect(
        find.text('${d.recordsPatient.fullName} (Bản thân)'), findsOneWidget);
    expect(d.appointments.length, count);
    // A relative with a follow-up and no appointments exercises both entry points.
    final child = d.patients.last;
    d.requestBookingFor(child.id);
    await tester.pumpAndSettle();
    expect(
        find.text('${child.fullName} (${child.relationship})'), findsOneWidget);
    expect(d.selectedPatientId, d.patients.first.id);
    expect(d.appointments.length, count);
  });
  testWidgets(
      'missing optional visit records hide actions; result route shows supplied read-only data',
      (tester) async {
    final visit = Visit(
        id: 'result-test',
        patientId: 'patient-001',
        visitedAt: DateTime(2026, 10, 12),
        clinic: 'Test',
        diagnosis: 'Kết luận kiểm thử',
        note: 'Dặn dò kiểm thử',
        treatment: 'Điều trị kiểm thử',
        result: 'Kết quả kiểm thử');
    final d = PatientDataProvider();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: d,
        child: MaterialApp(
            theme: AppTheme.light,
            home: VisitDetailScreen(visit: visit),
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
                builder: (_) =>
                    ExamResultScreen(visit: settings.arguments! as Visit)))));
    expect(find.text('Điều trị kiểm thử'), findsOneWidget);
    expect(find.text('Xem đơn thuốc'), findsNothing);
    expect(find.text('Xem phiếu thanh toán'), findsNothing);
    await open(tester, 'Xem kết quả khám');
    expect(find.text('Kết quả kiểm thử'), findsOneWidget);
    expect(find.text('Thông tin minh họa · Chỉ đọc'), findsOneWidget);
  });
  testWidgets('empty appointments start a draft for the selected relative',
      (tester) async {
    final d = PatientDataProvider();
    final relative = Patient(
        id: 'relative-empty',
        fullName: 'Người thân kiểm thử',
        phone: '',
        dateOfBirth: DateTime(2000),
        relationship: 'Em');
    d.addFamilyMember(relative);
    await pumpShell(tester, d);
    d.focusAppointmentsFor(relative.id);
    await tester.pumpAndSettle();
    await open(tester, 'Lịch hẹn');
    expect(find.text('Chưa có lịch hẹn.'), findsOneWidget);
    final count = d.appointments.length;
    await open(tester, 'Đặt lịch khám');
    expect(find.text('${relative.fullName} (${relative.relationship})'),
        findsOneWidget);
    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);
    expect(d.appointments.length, count);
    expect(d.selectedPatientId, d.patients.first.id);
  });
  testWidgets(
      'past followup passes relative only, retains stack, does not create an appointment',
      (tester) async {
    final d = _PastFollowupData();
    await pumpShell(tester, d);
    d.focusAppointmentsFor(d.patients.last.id);
    await tester.pumpAndSettle();
    await open(tester, 'Lịch tái khám');
    expect(find.text('Ngày đề xuất đã qua'), findsOneWidget);
    final count = d.appointments.length;
    await open(tester, 'Đặt lịch tái khám');
    expect(
        find.text(
            '${d.patients.last.fullName} (${d.patients.last.relationship})'),
        findsOneWidget);
    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);
    expect(d.appointments.length, count);
    await tester.tap(find.text('Hồ sơ').last);
    await tester.pumpAndSettle();
    expect(find.text('Lịch tái khám'), findsOneWidget);
    expect(find.text('Ngày đề xuất đã qua'), findsOneWidget);
    await back(tester);
    expect(find.text('Hồ sơ nha khoa'), findsOneWidget);
  });
  testWidgets('multiple treatment plans open the matching detail and progress',
      (tester) async {
    final d = _MultiplePlansData();
    await pumpShell(tester, d);
    await open(tester, 'Liệu trình điều trị');
    await open(tester, 'Liệu trình kiểm thử');
    expect(find.text('Chi tiết liệu trình'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .25);
    await open(tester, 'Xem ảnh trước – sau');
    expect(find.text('Ảnh minh họa chưa được tải lên.'), findsOneWidget);
    await back(tester);
    expect(find.text('Chi tiết liệu trình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PastFollowupData extends PatientDataProvider {
  @override
  List<Followup> get followups => [
        Followup(
            id: 'past-followup',
            patientId: patients.last.id,
            doctorId: doctors.first.id,
            scheduledAt: DateTime(2020),
            note: 'Tái khám kiểm thử')
      ];
}

class _MultiplePlansData extends PatientDataProvider {
  @override
  List<TreatmentPlan> get treatmentPlans => [
        ...super.treatmentPlans,
        TreatmentPlan(
            id: 'plan-test',
            patientId: patients.first.id,
            title: 'Liệu trình kiểm thử',
            description: 'Mô tả kiểm thử',
            completedVisits: 3,
            totalVisits: 12)
      ];
}
