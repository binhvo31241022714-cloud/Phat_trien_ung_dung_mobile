import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/family_member.dart';
import 'package:frontend/data/models/user_profile.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/records/appointments_screen.dart';
import 'package:frontend/features/records/visit_history_screen.dart';
import 'package:frontend/features/records/treatment_list_screen.dart';
import 'package:frontend/features/records/followup_screen.dart';
import 'package:frontend/features/records/records_widgets.dart';
import 'support/data_source_scope.dart';

const patientNameKey = ValueKey('records-patient-name');
const ownerName = 'Nguyễn Hoàng An';
const relativeName = 'Trần Minh Bình';

PatientDataProvider patients() => PatientDataProvider(seedDemo: false)
  ..syncPatients(
      const UserProfile(id: 'owner', email: '', fullName: ownerName, phone: ''),
      const [
        FamilyMember(
            id: 'relative', fullName: relativeName, relationship: 'Con')
      ]);

class LoadingPatients extends PatientDataProvider {
  LoadingPatients() : super(seedDemo: false);
  @override
  bool get recordsLoading => true;
}

void main() {
  // No auth service, Firebase initialization or network-backed provider is used.
  setUp(() => useDataSourceForTest(DataSource.mock));
  final screens = <String, Widget Function(String)>{
    'Lịch hẹn': (id) => AppointmentsScreen(patientId: id),
    'Lịch sử khám': (id) => VisitHistoryScreen(patientId: id),
    'Liệu trình điều trị': (id) => TreatmentListScreen(patientId: id),
    'Lịch tái khám': (id) => FollowupScreen(patientId: id),
  };
  for (final entry in screens.entries) {
    for (final width in [320.0, 360.0, 411.0]) {
      for (final scale in [1.0, 1.3, 1.5]) {
        testWidgets('${entry.key}: correct title and patient at $width/$scale',
            (t) async {
          final data = patients();
          addTearDown(data.dispose);
          t.view.physicalSize = Size(width, 800);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          await t.pumpWidget(ChangeNotifierProvider.value(
              value: data,
              child: MaterialApp(
                  theme: AppTheme.light,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!),
                  home: Builder(
                      builder: (context) => Scaffold(
                          body: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => Consumer<PatientDataProvider>(
                                          builder: (_, current, __) => entry
                                              .value(current.recordsPatient.id)))),
                              child: const Text('Mở hồ sơ')))))));
          await t.tap(find.text('Mở hồ sơ'));
          await t.pumpAndSettle();
          final appBar = find.byType(AppBar);
          expect(find.descendant(of: appBar, matching: find.text(entry.key)),
              findsOneWidget);
          expect(find.descendant(of: appBar, matching: find.text(ownerName)),
              findsNothing);
          expect(find.text(entry.key), findsOneWidget);
          expect(t.widget<Text>(find.byKey(patientNameKey)).data, ownerName);
          expect(t.getTopLeft(find.byKey(patientNameKey)).dy,
              greaterThanOrEqualTo(t.getBottomLeft(appBar).dy));
          if (entry.key == 'Lịch hẹn') {
            for (final tab in ['Chờ xác nhận', 'Đã xác nhận', 'Đã hủy']) {
              await t.ensureVisible(find.text(tab));
              await t.tap(find.text(tab));
              await t.pumpAndSettle();
              expect(
                  t.widget<Text>(find.byKey(patientNameKey)).data, ownerName);
            }
          }
          data.selectPatient('relative', reload: false);
          await t.pumpAndSettle();
          expect(t.widget<Text>(find.byKey(patientNameKey)).data, relativeName);
          expect(find.text(ownerName), findsNothing);
          data.selectPatient('owner', reload: false);
          await t.pumpAndSettle();
          expect(t.widget<Text>(find.byKey(patientNameKey)).data, ownerName);
          expect(find.text(relativeName), findsNothing);
          const longName =
              'Nguyễn Hoàng An với họ tên dài để kiểm tra bố cục khi phóng lớn chữ';
          data.syncPatients(
              const UserProfile(
                  id: 'owner', email: '', fullName: longName, phone: ''),
              const []);
          await t.pumpAndSettle();
          expect(t.widget<Text>(find.byKey(patientNameKey)).data, longName);
          expect(t.takeException(), isNull);
          await t.pageBack();
          await t.pumpAndSettle();
          expect(find.text('Mở hồ sơ'), findsOneWidget);
          expect(find.byKey(patientNameKey), findsNothing);
        });
      }
    }

    testWidgets('${entry.key}: missing profile/name never uses another patient',
        (t) async {
      final data = patients();
      addTearDown(data.dispose);
      final id = ValueNotifier('unavailable');
      addTearDown(id.dispose);
      await t.pumpWidget(ChangeNotifierProvider.value(
          value: data,
          child: MaterialApp(
              theme: AppTheme.light,
              home: ValueListenableBuilder<String>(
                  valueListenable: id,
                  builder: (_, value, __) => entry.value(value)))));
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(patientNameKey)).data,
          'Chưa có tên người khám');
      expect(find.text(ownerName), findsNothing);
      data.syncPatients(
          const UserProfile(id: 'owner', email: '', fullName: '', phone: ''),
          const []);
      id.value = 'owner';
      await t.pumpAndSettle();
      expect(t.widget<Text>(find.byKey(patientNameKey)).data,
          'Chưa có tên người khám');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('patient header handles loading without reading an account name',
      (t) async {
    final data = LoadingPatients();
    addTearDown(data.dispose);
    await t.pumpWidget(ChangeNotifierProvider<PatientDataProvider>.value(
        value: data,
        child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
                body: RecordPatientName(patientId: 'not-loaded')))));
    expect(t.widget<Text>(find.byKey(patientNameKey)).data, 'Đang tải…');
    expect(find.text(ownerName), findsNothing);
    expect(t.takeException(), isNull);
  });
}
