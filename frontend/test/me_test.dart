import 'support/data_source_scope.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'support/fake_appointments_provider.dart';

import 'package:frontend/app.dart';
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/utils/validators.dart';
import 'package:frontend/data/models/patient.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/data/services/settings_store.dart';
import 'package:frontend/features/me/me_widgets.dart';

import 'support/fake_auth_service.dart';
import 'support/empty_content_provider.dart';
import 'package:frontend/providers/content_provider.dart';
import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';

Widget providers(
  UserProvider users,
  PatientDataProvider data,
  Widget child, {
  ProfileProvider? profile,
  CatalogProvider? catalog,
}) {
  final resolvedCatalog = catalog ?? FakeCatalogBackend().provider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ContentProvider>(create: (_) {
        final content = emptyContentProvider();
        if (AppConfig.current.dataSource == DataSource.api) {
          content.bindUser(users, resolvedCatalog);
        }
        return content;
      }),
      ChangeNotifierProvider.value(value: users),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profile ?? FakeProfileBackend().provider(),
      ),
      ChangeNotifierProvider<CatalogProvider>.value(
        value: resolvedCatalog,
      ),
      // PatientNavigation.logout đọc AppointmentsProvider trực tiếp.
      // Dùng fake để test không gọi API thật.
      ChangeNotifierProvider<AppointmentsProvider>(
        create: (_) => FakeAppointmentsProvider(),
      ),
    ],
    child: child,
  );
}

Future<void> pumpMe(
  WidgetTester tester,
  UserProvider users,
  PatientDataProvider data, {
  double width = 390,
  ProfileProvider? profile,
  CatalogProvider? catalog,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    providers(
      users,
      data,
      MaterialApp(
        theme: AppTheme.light,
        home: const MainShell(),
      ),
      profile: profile,
      catalog: catalog,
    ),
  );

  await tester.tap(find.text('Tôi').last);
  await tester.pumpAndSettle();
}

Future<void> openMe(WidgetTester tester, String text) async {
  final base = find.text(text);
  if (base.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      180,
      scrollable: find.byType(Scrollable).first,
    );
  }

  // Ẩn bàn phím trước khi cuộn để phần tử không tự dịch chuyển lại.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(base.last),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(base.last);
  await tester.pumpAndSettle();
}

Future<void> backMe(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// Bấm nút "Đổi mật khẩu" (tiêu đề màn hình cũng có chữ này nên tìm theo nút).
Future<void> tapChangePassword(WidgetTester tester) async {
  final button = find.widgetWithText(PrimaryButton, 'Đổi mật khẩu');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

UserProvider demoUsers() =>
    UserProvider(auth: FakeAuthService())..signInDemo('patient@example.com');

Future<void> setBirthday(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(
    tester.element(find.byType(BirthdayField)),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BirthdayField));
  await tester.pumpAndSettle();
  final picker = tester.widget<CalendarDatePicker>(
    find.byType(CalendarDatePicker),
  );
  expect(picker.lastDate.isAfter(DateTime.now()), isFalse);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  test('session sign-in/out has stable account id and retains no password', () {
    final u = UserProvider();
    expect(u.currentUser, isNull);
    u.signInDemo('patient@example.com');
    final id = u.currentUser!.id;
    u.setReceiveNotifications(false);
    u.signOutDemo();
    expect(u.isAuthenticated, isFalse);
    expect(u.currentUser, isNull);
    u.signInDemo('patient@example.com');
    expect(u.currentUser!.id, id);
    expect(u.receiveNotifications, isFalse);
  });

  test('settings are saved to the device store and read back on start',
      () async {
    final store = MemorySettingsStore();
    final first = UserProvider(settings: store);
    await first.loadSettings();
    expect(first.receiveNotifications, isTrue);
    expect(first.languageCode, 'vi');
    first.setReceiveNotifications(false);
    first.setLanguage('en'); // Chưa hỗ trợ: bỏ qua.
    await Future<void>.delayed(Duration.zero);
    expect(store.values['settings.receiveNotifications'], isFalse);

    final reopened = UserProvider(settings: store);
    await reopened.loadSettings();
    expect(reopened.receiveNotifications, isFalse);
    expect(reopened.languageCode, 'vi');

    final legacy = UserProvider(
      settings: MemorySettingsStore({'settings.languageCode': 'en'}),
    );
    await legacy.loadSettings();
    expect(legacy.languageName, 'Tiếng Việt');
  });

  test('family rules preserve records, ids and selection fallbacks', () {
    final d = PatientDataProvider();
    final appointments = d.appointments.toList();
    expect(d.removeFamilyMember(d.primaryPatient.id), isNotNull);
    expect(d.removeFamilyMember(d.patients.last.id), contains('liên kết'));
    final p = d.addRelative(
      name: 'Người thân kiểm thử',
      relationship: 'Em',
      dateOfBirth: DateTime(2000),
    );
    d.updatePatient(
      Patient(
        id: p.id,
        fullName: 'Tên đã sửa',
        phone: '',
        dateOfBirth: p.dateOfBirth,
        relationship: 'Khác',
      ),
    );
    expect(d.patients.last.id, p.id);
    expect(d.patients.last.fullName, 'Tên đã sửa');
    d.selectPatient(p.id);
    d.focusAppointmentsFor(p.id);
    d.requestBookingFor(p.id);
    expect(d.removeFamilyMember(p.id), isNull);
    expect(d.selectedPatientId, d.primaryPatient.id);
    expect(d.recordsPatient.id, d.primaryPatient.id);
    expect(d.takeBookingPatientRequest(), d.primaryPatient.id);
    expect(d.appointments, appointments);
  });

  test(
    'optional phone and email validation accepts VN numbers and rejects malformed values',
    () {
      expect(Validators.vietnamesePhone('0903 456 789'), isNull);
      expect(Validators.vietnamesePhone('+84903456789'), isNull);
      expect(Validators.vietnamesePhone('1234'), isNotNull);
      expect(Validators.optionalEmail(''), isNull);
      expect(Validators.optionalEmail('bad'), isNotNull);
    },
  );

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets(
      'all six account destinations, settings, password and FAQ fit $width',
      (tester) async {
        final u = demoUsers();
        final d = PatientDataProvider();
        final backend = FakeProfileBackend(
          family: [
            {'id': 'fam-1', 'fullName': 'Nguyễn Thị Mẹ', 'relationship': 'Mẹ'}
          ],
        );
        await pumpMe(tester, u, d, width: width, profile: backend.provider());
        d.focusAppointmentsFor(d.patients.last.id);
        await tester.pumpAndSettle();
        expect(find.text('Trần Thị Test'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        await openMe(tester, 'Thông tin cá nhân');
        expect(find.text('Thay ảnh (demo)'), findsOneWidget);
        await backMe(tester);
        await openMe(tester, 'Quản lý người thân');
        expect(find.text('Nguyễn Thị Mẹ'), findsOneWidget);
        expect(find.text('Mẹ · Chưa có ngày sinh'), findsOneWidget);
        await backMe(tester);
        await openMe(tester, 'Thông báo');
        expect(find.text('Tất cả'), findsOneWidget);
        await backMe(tester);
        await openMe(tester, 'Cài đặt');
        await openMe(tester, 'Nhận thông báo');
        expect(u.receiveNotifications, isFalse);
        await openMe(tester, 'Ngôn ngữ');
        expect(find.text('Tiếng Việt'), findsOneWidget);
        expect(find.text('English'), findsNothing);
        expect(find.text('Sắp có thêm ngôn ngữ.'), findsOneWidget);
        await backMe(tester);
        expect(find.textContaining('sinh trắc học'), findsNothing);
        await openMe(tester, 'Đổi mật khẩu');
        await tester.enterText(find.byType(TextFormField).at(0), 'secret123');
        await tester.enterText(find.byType(TextFormField).at(1), 'newsecret1');
        await tester.enterText(find.byType(TextFormField).at(2), 'newsecret1');
        await tapChangePassword(tester);
        expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
        expect(find.text('Nhận thông báo'), findsOneWidget);
        expect(u.isAuthenticated, isTrue);
        await openMe(tester, 'Quyền riêng tư');
        expect(find.text('Ai có thể xem hồ sơ?'), findsOneWidget);
        expect(
          find.textContaining('chỉ chủ tài khoản mới xem, sửa được'),
          findsOneWidget,
        );
        await backMe(tester);
        await backMe(tester);
        await openMe(tester, 'Trợ giúp');
        for (final q in [
          'Làm thế nào để đặt lịch?',
          'Có thể đặt nhiều dịch vụ không?',
          'Có thể đặt cho người thân không?',
          'Xem kết quả điều trị ở đâu?',
        ]) {
          if (find.text(q).evaluate().isEmpty) {
            await tester.scrollUntilVisible(
              find.text(q),
              150,
              scrollable: find.byType(Scrollable).first,
            );
          }
          expect(find.text(q), findsOneWidget);
        }
        await backMe(tester);
        await openMe(tester, 'Đã lưu');
        expect(find.text('Chưa có nội dung đã lưu.'), findsOneWidget);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'profile validation, keyboard and PATCH /api/users/me at $width',
      (tester) async {
        final u = demoUsers();
        final d = PatientDataProvider();
        final backend = FakeProfileBackend();
        final relative = d.patients.last;
        final ids = d.appointments.map((a) => a.id).toList();
        await pumpMe(tester, u, d, width: width, profile: backend.provider());
        // Tên "Bản thân" trong dữ liệu đặt lịch đổi theo hồ sơ API.
        expect(d.primaryPatient.fullName, 'Trần Thị Test');
        await openMe(tester, 'Thông tin cá nhân');
        expect(find.text('patient@example.com'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).at(0), '');
        await tester.enterText(find.byType(TextFormField).at(1), '123');
        await openMe(tester, 'Lưu thay đổi');
        expect(find.text('Họ và tên không được để trống'), findsOneWidget);
        expect(
            find.text('Số điện thoại Việt Nam không hợp lệ'), findsOneWidget);
        // Ngày sinh không bắt buộc.
        expect(find.text('Vui lòng chọn ngày sinh'), findsNothing);
        expect(backend.me['fullName'], 'Trần Thị Test');
        await tester.enterText(
          find.byType(TextFormField).at(0),
          'Tên tài khoản mới',
        );
        await tester.enterText(find.byType(TextFormField).at(1), '0901234567');
        await setBirthday(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.pump();
        await tester.ensureVisible(find.text('Lưu thay đổi'));
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await openMe(tester, 'Lưu thay đổi');
        expect(backend.me['fullName'], 'Tên tài khoản mới');
        expect(backend.me['phone'], '0901234567');
        expect(
          backend.me['birthday'],
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
        );
        expect(find.text('Tên tài khoản mới'), findsOneWidget);
        expect(d.primaryPatient.fullName, 'Tên tài khoản mới');
        expect(
            d.primaryPatient.id,
            AppConfig.current.dataSource == DataSource.api
                ? backend.me['id']
                : 'patient-001');
        if (AppConfig.current.dataSource == DataSource.api) {
          expect(d.patients, hasLength(1));
        } else {
          expect(d.patients.last, same(relative));
        }
        if (AppConfig.current.dataSource == DataSource.api) {
          expect(d.appointments, isEmpty);
        } else {
          expect(d.appointments.map((a) => a.id).toList(), ids);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('family list states and add/edit/delete via API', (tester) async {
    final u = demoUsers();
    final d = PatientDataProvider();
    final backend = FakeProfileBackend();
    final mockPatients = d.patients.length;
    await pumpMe(tester, u, d, profile: backend.provider());
    await openMe(tester, 'Quản lý người thân');
    expect(find.text('Chưa có người thân'), findsOneWidget);
    expect(find.text('Xóa người thân'), findsNothing);

    await openMe(tester, 'Thêm người thân');
    await openMe(tester, 'Lưu người thân');
    // Chỉ họ tên bắt buộc; ngày sinh không bắt buộc.
    expect(find.text('Họ và tên không được để trống'), findsOneWidget);
    expect(find.text('Vui lòng chọn ngày sinh'), findsNothing);
    expect(backend.family, isEmpty);
    await tester.enterText(find.byType(TextFormField).first, 'Người thân mới');
    await setBirthday(tester);
    await openMe(tester, 'Lưu người thân');
    expect(backend.family.length, 1);
    expect(backend.family.first['fullName'], 'Người thân mới');
    expect(backend.family.first['relationship'], 'Con');
    expect(find.text('Người thân mới'), findsOneWidget);

    final card = find
        .ancestor(of: find.text('Người thân mới'), matching: find.byType(Card))
        .first;
    await tester.tap(find.descendant(of: card, matching: find.text('Sửa')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Người thân đã sửa',
    );
    await openMe(tester, 'Lưu người thân');
    expect(backend.family.single['fullName'], 'Người thân đã sửa');
    expect(find.text('Người thân đã sửa'), findsOneWidget);

    final editedCard = find
        .ancestor(
          of: find.text('Người thân đã sửa'),
          matching: find.byType(Card),
        )
        .first;
    await tester.tap(
      find.descendant(
        of: editedCard,
        matching: find.text('Xóa người thân'),
      ),
    );
    await tester.pumpAndSettle();
    await openMe(tester, 'Hủy');
    expect(backend.family.length, 1);
    await tester.tap(
      find.descendant(
        of: editedCard,
        matching: find.text('Xóa người thân'),
      ),
    );
    await tester.pumpAndSettle();
    await openMe(tester, 'Xác nhận xóa');
    expect(backend.family, isEmpty);
    expect(find.text('Chưa có người thân'), findsOneWidget);
    // Người thân API không trộn vào dữ liệu mock của đặt lịch/hồ sơ khám.
    expect(d.patients.length,
        AppConfig.current.dataSource == DataSource.api ? 1 : mockPatients);
    expect(tester.takeException(), isNull);
  });

  testWidgets('family and profile errors show retry', (tester) async {
    final u = demoUsers();
    final d = PatientDataProvider();
    final backend = FakeProfileBackend()..failStatus = 404;
    await pumpMe(tester, u, d, profile: backend.provider());
    expect(find.textContaining('Chưa tải được hồ sơ'), findsOneWidget);
    expect(find.text('patient@example.com'), findsOneWidget);
    await openMe(tester, 'Quản lý người thân');
    expect(find.text('Lỗi giả lập'), findsOneWidget);
    backend.failStatus = null;
    backend.family.add(
      {'id': 'fam-9', 'fullName': 'Bé Na', 'relationship': 'Con'},
    );
    await openMe(tester, 'Thử lại');
    expect(find.text('Bé Na'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notifications filter, mark read, preserve category and open linked appointment',
    (tester) async {
      // This test asserts local demo article/notification state, not API state.
      useDataSourceForTest(DataSource.mock);
      final u = demoUsers();
      final d = PatientDataProvider();
      await pumpMe(tester, u, d);
      await openMe(tester, 'Thông báo');
      await openMe(tester, 'Ưu đãi');
      expect(
          find.text('Chưa có thông báo trong danh mục này.'), findsOneWidget);
      await openMe(tester, 'Hệ thống');
      expect(find.text(d.notifications.last.title), findsOneWidget);
      expect(find.text(d.notifications.first.title), findsNothing);
      await openMe(tester, d.notifications.last.title);
      expect(d.notifications.last.isRead, isTrue);
      expect(d.notifications.last.category, NotificationCategory.system);
      await openMe(tester, 'Lịch hẹn');
      await openMe(tester, d.notifications.first.title);
      expect(d.notifications.first.isRead, isTrue);
      expect(d.notifications.first.appointmentId, isNotNull);
      expect(find.text('Chi tiết lịch hẹn'), findsOneWidget);
      expect(
        find.text('Mã lịch hẹn: ${d.notifications.first.appointmentId}'),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('saved items load from /api/favorites, open details and remove',
      (tester) async {
    // This test asserts local demo article/notification state, not API state.
    useDataSourceForTest(DataSource.mock);
    final u = demoUsers();
    final d = PatientDataProvider();
    final backend = FakeCatalogBackend();
    await pumpMe(tester, u, d, catalog: backend.provider());
    await openMe(tester, 'Đã lưu');
    expect(find.text('Chưa có nội dung đã lưu.'), findsOneWidget);
    await backMe(tester);

    backend.favorites.addAll([
      {'id': 'service_svc_01', 'type': 'service', 'itemId': 'svc_01'},
      {'id': 'combo_combo_01', 'type': 'combo', 'itemId': 'combo_01'},
      {'id': 'doctor_doc_01', 'type': 'doctor', 'itemId': 'doc_01'},
      // Mục đã bị xóa khỏi máy chủ: bỏ qua, không làm lỗi màn hình.
      {'id': 'service_svc_99', 'type': 'service', 'itemId': 'svc_99'},
    ]);
    // Bài viết vẫn lưu theo dữ liệu mock của module Nội dung.
    d.toggleSavedArticle(d.articles.first.id);
    await openMe(tester, 'Đã lưu');
    for (final name in [
      d.articles.first.title,
      'Khám răng tổng quát',
      'Combo chăm sóc răng miệng cơ bản',
      'BS. Nguyễn Văn API',
    ]) {
      expect(find.text(name), findsOneWidget);
    }

    await openMe(tester, 'Khám răng tổng quát');
    expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
    await openMe(tester, 'Đã lưu · Bỏ lưu');
    expect(backend.favorites.any((f) => f['id'] == 'service_svc_01'), isFalse);
    expect(find.text('Lưu để xem sau'), findsOneWidget);
    await backMe(tester);
    expect(find.text('Khám răng tổng quát'), findsNothing);

    await openMe(tester, 'Combo chăm sóc răng miệng cơ bản');
    expect(find.text('Gồm các dịch vụ'), findsOneWidget);
    expect(find.text('• Lấy cao răng'), findsOneWidget);
    await backMe(tester);

    await tester.tap(find.byTooltip('Bỏ lưu BS. Nguyễn Văn API'));
    await tester.pumpAndSettle();
    expect(backend.favorites.any((f) => f['id'] == 'doctor_doc_01'), isFalse);
    expect(find.text('BS. Nguyễn Văn API'), findsNothing);

    await openMe(tester, d.articles.first.title);
    await openMe(tester, 'Đã lưu · Bỏ lưu');
    expect(d.savedArticles, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved tabs filter, show counts and update after removal',
      (tester) async {
    // This test asserts local demo article/notification state, not API state.
    useDataSourceForTest(DataSource.mock);
    final u = demoUsers();
    final d = PatientDataProvider();
    final backend = FakeCatalogBackend();
    backend.favorites.addAll([
      {'id': 'service_svc_01', 'type': 'service', 'itemId': 'svc_01'},
      {'id': 'combo_combo_01', 'type': 'combo', 'itemId': 'combo_01'},
      {'id': 'doctor_doc_01', 'type': 'doctor', 'itemId': 'doc_01'},
    ]);
    await pumpMe(tester, u, d, catalog: backend.provider());
    await openMe(tester, 'Đã lưu');
    // Chưa có bài viết đã lưu thì không có tab Bài viết.
    expect(find.text('Tất cả (3)'), findsOneWidget);
    expect(find.text('Dịch vụ (2)'), findsOneWidget);
    expect(find.text('Bác sĩ (1)'), findsOneWidget);
    expect(find.textContaining('Bài viết ('), findsNothing);

    await openMe(tester, 'Dịch vụ (2)');
    expect(find.text('Khám răng tổng quát'), findsOneWidget);
    expect(find.text('Combo chăm sóc răng miệng cơ bản'), findsOneWidget);
    expect(find.text('BS. Nguyễn Văn API'), findsNothing);

    await openMe(tester, 'Bác sĩ (1)');
    expect(find.text('BS. Nguyễn Văn API'), findsOneWidget);
    expect(find.text('Khám răng tổng quát'), findsNothing);
    // Bỏ lưu ở tab Bác sĩ: số lượng mọi tab đổi ngay, hiện trạng thái trống.
    await tester.tap(find.byTooltip('Bỏ lưu BS. Nguyễn Văn API'));
    await tester.pumpAndSettle();
    expect(backend.favorites.any((f) => f['id'] == 'doctor_doc_01'), isFalse);
    expect(find.text('Bác sĩ (0)'), findsOneWidget);
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Bạn chưa lưu bác sĩ nào.'), findsOneWidget);

    await openMe(tester, 'Dịch vụ (2)');
    await tester.tap(find.byTooltip('Bỏ lưu Khám răng tổng quát'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bỏ lưu Combo chăm sóc răng miệng cơ bản'));
    await tester.pumpAndSettle();
    expect(find.text('Dịch vụ (0)'), findsOneWidget);
    expect(find.text('Bạn chưa lưu dịch vụ nào.'), findsOneWidget);

    // Có bài viết đã lưu thì tab Bài viết xuất hiện kèm số lượng.
    d.toggleSavedArticle(d.articles.first.id);
    await tester.pumpAndSettle();
    expect(find.text('Bài viết (1)'), findsOneWidget);
    expect(find.text('Tất cả (1)'), findsOneWidget);
    await openMe(tester, 'Bài viết (1)');
    expect(find.text(d.articles.first.title), findsOneWidget);
    // Bỏ lưu bài viết cuối cùng: tab Bài viết biến mất, quay về Tất cả.
    await tester.tap(find.byTooltip('Bỏ lưu ${d.articles.first.title}'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bài viết ('), findsNothing);
    expect(find.text('Tất cả (0)'), findsOneWidget);
    expect(find.text('Chưa có nội dung đã lưu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'logout cancellation, confirmed session clearing, no Back to shell and login again',
    (tester) async {
      final u = UserProvider(auth: FakeAuthService());
      final d = PatientDataProvider();
      await tester.pumpWidget(providers(u, d, const App()));

      Future<void> login() async {
        await openMe(tester, 'Đăng nhập');
        await tester.enterText(
          find.byType(TextFormField).first,
          'patient@example.com',
        );
        await tester.enterText(find.byType(TextFormField).last, 'secret123');
        await openMe(tester, 'Đăng nhập');
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(u.isAuthenticated, isTrue);
      }

      await login();
      await tester.tap(find.text('Tôi').last);
      await tester.pumpAndSettle();
      await openMe(tester, 'Đăng xuất');
      await openMe(tester, 'Hủy');
      expect(u.isAuthenticated, isTrue);
      await openMe(tester, 'Đăng xuất');
      await openMe(tester, 'Đăng xuất');
      expect(u.currentUser, isNull);
      expect(find.text('Chăm sóc nụ cười của bạn'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(MainShell), findsNothing);
      expect(
          d.appointments,
          AppConfig.current.dataSource == DataSource.api
              ? isEmpty
              : isNotEmpty);
      await login();
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('change password validates, reports errors and succeeds',
      (tester) async {
    final auth = FakeAuthService();
    final u = UserProvider(auth: auth)..signInDemo('patient@example.com');
    final d = PatientDataProvider();
    await pumpMe(tester, u, d);
    await openMe(tester, 'Cài đặt');
    await openMe(tester, 'Đổi mật khẩu');
    expect(find.textContaining('demo'), findsNothing);
    await tapChangePassword(tester);
    expect(find.text('Mật khẩu không được để trống'), findsNWidgets(3));

    await tester.enterText(find.byType(TextFormField).at(0), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await tapChangePassword(tester);
    expect(
      find.text('Mật khẩu mới phải khác mật khẩu hiện tại'),
      findsOneWidget,
    );
    expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);

    // Sai mật khẩu hiện tại: báo lỗi, vẫn ở lại màn hình.
    await tester.enterText(find.byType(TextFormField).at(0), 'wrongpass');
    await tester.enterText(find.byType(TextFormField).at(1), 'newsecret1');
    await tester.enterText(find.byType(TextFormField).at(2), 'newsecret1');
    await tapChangePassword(tester);
    expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
    expect(find.text('Mật khẩu hiện tại'), findsOneWidget);
    expect(auth.password, 'secret123');

    await tester.ensureVisible(find.byTooltip('Hiện mật khẩu').first);
    await tester.tap(find.byTooltip('Hiện mật khẩu').first);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).obscureText,
      isFalse,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'secret123');
    await tapChangePassword(tester);
    expect(auth.password, 'newsecret1');
    expect(find.text('Đã đổi mật khẩu'), findsOneWidget);
    expect(find.text('Mật khẩu hiện tại'), findsNothing);
    expect(u.isAuthenticated, isTrue);
  });
}
