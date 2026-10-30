import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/app/patient_navigation.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/availability_slot.dart';
import 'package:frontend/data/models/dental_service.dart';
import 'package:frontend/data/models/doctor.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/booking_service.dart'
    hide AvailabilitySlot;
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/features/booking/booking_screen.dart';
import 'package:frontend/features/doctors/doctor_detail_screen.dart';
import 'package:frontend/features/services/service_detail_screen.dart';
import 'package:frontend/features/shared/catalog_navigation.dart';
import 'package:frontend/providers/catalog_provider.dart';

import 'catalog_search_test.dart' show backend;
import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';

/// Giống MainShell nhưng chỉ có tab 0 (nơi bấm nút) và tab 1 (Đặt lịch).
class _Shell extends StatefulWidget {
  const _Shell({super.key});
  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int index = 1;
  void select(int i) => setState(() => index = i);
  @override
  Widget build(BuildContext context) => MainShellScope(
      onSelectTab: select,
      selectedIndex: index,
      child: Scaffold(
          body: IndexedStack(index: index, children: [
        Builder(
            builder: (context) => Center(
                child: TextButton(
                    onPressed: () => PatientNavigation.openBooking(context,
                        serviceIds: ['svc_02']),
                    child: const Text('Đặt lịch Lấy cao răng')))),
        const BookingScreen(),
      ])));
}

/// Mở [page] như từ một tab của MainShell (tab [tab]); trả về các tab đã chọn.
Future<(CatalogProvider, List<int>)> pumpInShell(
    WidgetTester tester, Widget Function(CatalogProvider) page,
    {int tab = 0, bool shell = true}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final catalog = backend().provider();
  await catalog.load();
  final selected = <int>[];
  final navigator = GlobalKey<NavigatorState>();
  final app = MaterialApp(
      navigatorKey: navigator,
      theme: AppTheme.light,
      home: const Scaffold(body: Text('Trang gốc')));
  await tester.pumpWidget(ChangeNotifierProvider.value(
      value: catalog,
      child: shell
          ? MainShellScope(
              onSelectTab: selected.add, selectedIndex: tab, child: app)
          : app));
  navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => CatalogPage(title: 'Chi tiết', body: page(catalog))));
  await tester.pumpAndSettle();
  return (catalog, selected);
}

Finder bookingButton(String label) => find.widgetWithText(FilledButton, label);

void main() {
  setUp(() => PatientNavigation.pendingBookingRequest = null);
  tearDown(() => PatientNavigation.pendingBookingRequest = null);

  testWidgets('doctor detail books with that doctor and drops "Chuyên môn"',
      (tester) async {
    final (_, selected) = await pumpInShell(tester,
        (c) => DoctorDetailScreen(doctor: c.doctors.first)); // doc_01
    // Chuyên khoa chỉ còn ở dòng dưới tên, không lặp lại thành mục riêng.
    expect(find.text('Chuyên môn'), findsNothing);
    expect(find.text('Nha khoa tổng quát'), findsOneWidget);

    await tester.tap(bookingButton('Đặt lịch với bác sĩ này'));
    await tester.pumpAndSettle();
    final r = PatientNavigation.pendingBookingRequest!;
    expect(r.doctorId, 'doc_01');
    expect(r.serviceIds, isNull);
    expect(r.comboId, isNull);
    expect(r.replaceSelection, isTrue);
    expect(selected, [1]);
    // Đóng chi tiết, quay về gốc của tab trước khi sang Đặt lịch.
    expect(find.text('Trang gốc'), findsOneWidget);
  });

  testWidgets('single service books with serviceIds', (tester) async {
    final (_, selected) = await pumpInShell(
        tester,
        (c) => ServiceDetailScreen(
            service: c.services.firstWhere((s) => s.id == 'svc_02')));
    expect(bookingButton('Đặt lịch combo này'), findsNothing);
    await tester.tap(bookingButton('Đặt lịch dịch vụ này'));
    await tester.pumpAndSettle();
    final r = PatientNavigation.pendingBookingRequest!;
    expect(r.serviceIds, ['svc_02']);
    expect(r.comboId, isNull);
    expect(r.doctorId, isNull);
    expect(selected, [1]);
  });

  testWidgets('combo books with comboId', (tester) async {
    await pumpInShell(
        tester,
        (c) => ServiceDetailScreen(
            service: c.combos.firstWhere((s) => s.id == 'combo_01')));
    expect(bookingButton('Đặt lịch dịch vụ này'), findsNothing);
    await tester.tap(bookingButton('Đặt lịch combo này'));
    await tester.pumpAndSettle();
    final r = PatientNavigation.pendingBookingRequest!;
    expect(r.comboId, 'combo_01');
    expect(r.serviceIds, isNull);
    expect(r.doctorId, isNull);
  });

  testWidgets('service opened from a doctor keeps that doctor', (tester) async {
    await pumpInShell(
        tester,
        (c) => DoctorDetailScreen(
            doctor: c.doctors.firstWhere((d) => d.id == 'doc_02')));
    await tester.tap(find.widgetWithText(ActionChip, 'Tẩy trắng răng'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết dịch vụ'), findsOneWidget);

    await tester.tap(bookingButton('Đặt lịch dịch vụ này'));
    await tester.pumpAndSettle();
    final r = PatientNavigation.pendingBookingRequest!;
    expect(r.serviceIds, ['svc_04']);
    expect(r.doctorId, 'doc_02');
    // Hai trang chi tiết đều được đóng.
    expect(find.text('Trang gốc'), findsOneWidget);
  });

  testWidgets('hidden for mock data, inside the booking tab and outside shell',
      (tester) async {
    const mockDoctor = Doctor(
        id: 'doctor-demo',
        fullName: 'BS. Demo',
        specialty: 'Nha khoa tổng quát',
        experienceYears: 5,
        rating: 0,
        reviewCount: 0,
        introduction: '');
    const mockService = DentalService(
        id: 'service-checkup',
        name: 'Khám demo',
        description: '',
        price: 100000,
        durationMinutes: 30,
        icon: Icons.medical_services_outlined,
        category: 'Tổng quát');
    await pumpInShell(tester, (_) => const DoctorDetailScreen(doctor: mockDoctor));
    expect(find.byType(FilledButton), findsNothing);
    await pumpInShell(
        tester, (_) => const ServiceDetailScreen(service: mockService));
    expect(find.byType(FilledButton), findsNothing);

    // Chi tiết mở ngay trong bước chọn của tab Đặt lịch.
    await pumpInShell(tester, (c) => DoctorDetailScreen(doctor: c.doctors.first),
        tab: 1);
    expect(find.byType(FilledButton), findsNothing);
    await pumpInShell(
        tester, (c) => ServiceDetailScreen(service: c.services.first),
        tab: 1);
    expect(find.byType(FilledButton), findsNothing);

    await pumpInShell(tester, (c) => DoctorDetailScreen(doctor: c.doctors.first),
        shell: false);
    expect(find.byType(FilledButton), findsNothing);
    expect(PatientNavigation.pendingBookingRequest, isNull);
  });

  testWidgets('shortcut replaces the old booking cart instead of adding to it',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final shell = GlobalKey<_ShellState>();
    await tester.pumpWidget(MultiProvider(providers: [
      ChangeNotifierProvider(create: (_) => PatientDataProvider()),
      ChangeNotifierProvider(create: (_) => FakeProfileBackend().provider()),
      ChangeNotifierProvider(create: (_) => FakeCatalogBackend().provider()),
    ], child: MaterialApp(theme: AppTheme.light, home: _Shell(key: shell))));
    await tester.pumpAndSettle();

    // Giỏ cũ: đang chọn dở "Khám răng tổng quát" ở tab Đặt lịch.
    await tester.ensureVisible(find.text('Khám răng tổng quát').first);
    await tester.tap(find.text('Khám răng tổng quát').first);
    await tester.pumpAndSettle();
    expect(find.text('1 dịch vụ đã chọn'), findsOneWidget);

    // Sang tab khác rồi bấm nút đặt lịch "Lấy cao răng".
    shell.currentState!.select(0);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt lịch Lấy cao răng'));
    await tester.pumpAndSettle();

    expect(shell.currentState!.index, 1);
    expect(PatientNavigation.pendingBookingRequest, isNull);
    // Chỉ còn dịch vụ mới (gộp giỏ cũ sẽ là 2), đi thẳng tới bước chọn bác sĩ.
    expect(find.text('1 dịch vụ đã chọn'), findsOneWidget);
    expect(find.text('Chọn bác sĩ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('after a successful booking the shortcut asks for a fresh draft',
      () async {
    // Đặt thành công một lịch (mock, MockClient, không gọi mạng).
    final data = PatientDataProvider();
    final service =
        BookingService(client: ApiClient(client: MockClient((r) async {
      return http.Response(
          jsonEncode({
            'id': 'created',
            'patientId': data.primaryPatient.id,
            'doctorId': data.doctors.first.id,
            'serviceIds': [data.services.first.id],
            'date': '2099-01-01',
            'startTime': '09:00',
            'endTime': '09:45',
            'durationMinutes': 45,
            'status': 'booked'
          }),
          201);
    })));
    final c = BookingController(data, bookingService: service)
      ..serviceIds.add(data.services.first.id)
      ..doctorChosen = true
      ..doctorId = data.doctors.first.id
      ..date = DateTime(2099, 1, 1)
      ..time = '09:00'
      ..availabilitySlots = [
        AvailabilitySlot(
            doctorId: data.doctors.first.id,
            doctorName: '',
            date: '2099-01-01',
            startTime: '09:00',
            endTime: '09:45',
            durationMinutes: 45)
      ];
    await c.submit();
    expect(c.created, isNotNull);

    // Controller đã đặt xong bỏ qua mọi lựa chọn mới, nên BookingScreen chỉ
    // áp được yêu cầu khi tạo controller mới, việc nó làm khi
    // replaceSelection = true (openBooking luôn đặt, xem test chi tiết bác sĩ).
    c.applyInitialValues(doctorId: 'doc_99', serviceIds: ['svc_99']);
    expect(c.doctorId, data.doctors.first.id);
    expect(c.serviceIds, {data.services.first.id});
    c.dispose();
    data.dispose();
  });
}
