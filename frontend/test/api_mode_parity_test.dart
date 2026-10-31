import 'package:frontend/features/articles/article_list_screen.dart';
import 'package:frontend/features/me/api_notifications_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/theme/app_scroll_behavior.dart';
import 'package:frontend/features/booking/booking_controller.dart';
import 'package:frontend/data/services/booking_service.dart';
import 'package:frontend/data/services/availability_service.dart';
import 'support/api_app_fixture.dart';
import 'support/data_source_scope.dart';
import 'me_test.dart' show openMe, backMe;

void main() {
  // API counterparts of legacy MockData scenarios. Run even in the default
  // command: the fixture declares API explicitly and restores it after each test.
  setUp(() => useDataSourceForTest(DataSource.api));

  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('API shell: four tabs, large text, short viewport at $width',
        (t) async {
      final f = ApiAppFixture();
      await f.mount(t, width: width, height: 640, scale: 1.5);
      expect(f.records.primaryPatient.id, ApiAppFixture.owner);
      expect(f.records.recordsError, isNull);
      expect(f.content.errors, isEmpty);
      for (final label in ['Trang chủ', 'Đặt lịch', 'Hồ sơ', 'Tôi']) {
        await t.tap(find.text(label).last);
        await t.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text('Quản lý người dùng'), findsNothing);
        expect(t.takeException(), isNull, reason: label);
      }
      expect(f.requests.any((r) => r.url.path == '/api/home'), isTrue);
    });

    testWidgets(
        'API article: scroll, server bookmark, Saved and removal at $width',
        (t) async {
      final f = ApiAppFixture();
      f.articles.single['content'] =
          List.filled(80, 'Văn bản API kiểm thử cuộn.').join('\n');
      await f.mount(t, width: width);
      await openMe(t, 'Bài viết API');
      expect(find.text(f.articles.single['content'] as String), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      await t.drag(scrollable, const Offset(0, -250));
      await t.pumpAndSettle();
      expect(
          t.state<ScrollableState>(scrollable).position.pixels, greaterThan(0));
      await openMe(t, 'Lưu để xem sau');
      expect(f.favorites.single['itemId'], 'article-api');
      expect(f.records.savedArticleIds, isEmpty,
          reason: 'API saves must not write local demo state');
      await t.tap(find.text('Tôi').last);
      await t.pumpAndSettle();
      await openMe(t, 'Đã lưu');
      expect(find.text('Bài viết API'), findsOneWidget);
      await openMe(t, 'Bài viết API');
      await openMe(t, 'Đã lưu · Bỏ lưu');
      expect(f.favorites, isEmpty);
      expect(
          f.requests
              .any((r) => r.method == 'POST' && r.url.path == '/api/favorites'),
          isTrue);
      expect(
          f.requests.any((r) =>
              r.method == 'DELETE' &&
              r.url.path == '/api/favorites/article_article-api'),
          isTrue);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets(
      'API Records selector loads relative history keeps account identity while changing selected patient',
      (t) async {
    final f = ApiAppFixture();
    await f.mount(t);
    await t.tap(find.text('Hồ sơ').last);
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Người thân API (Con)').last);
    await t.pumpAndSettle();
    expect(f.records.recordsPatient.id, 'relative-api');
    expect(f.records.selectedPatientId, 'relative-api');
    expect(f.records.primaryPatient.id, ApiAppFixture.owner);
    expect(f.records.visitsFor('relative-api').single.id, 'visit-relative');
    expect(f.records.visitsFor(ApiAppFixture.owner), isEmpty);
    await openMe(t, 'Lịch sử khám');
    expect(find.text('Trạng thái chưa cập nhật'), findsOneWidget);
    expect(find.text('Đã hoàn thành'), findsNothing);
    await openMe(t, 'Dịch vụ API');
    expect(find.text('Chẩn đoán visit-relative'), findsOneWidget);
    await openMe(t, 'Xem đơn thuốc');
    expect(find.text('Dặn dò đơn thuốc'), findsOneWidget);
    await backMe(t);
    await openMe(t, 'Xem phiếu thanh toán');
    expect(find.textContaining('invoice-visit-relative'), findsOneWidget);
    expect(find.textContaining('Người thân API'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'API Records: patient-specific counts, progress and treatment detail',
      (t) async {
    final f = ApiAppFixture();
    await f.mount(t);
    await t.tap(find.text('Hồ sơ').last);
    await t.pumpAndSettle();
    expect(f.records.visitsFor(ApiAppFixture.owner), hasLength(1));
    expect(f.records.treatmentsFor(ApiAppFixture.owner).single.progress, .5);
    await openMe(t, 'Liệu trình điều trị');
    expect(find.text('Trạng thái chưa cập nhật'), findsOneWidget);
    expect(find.text('Liệu trình visit-api'), findsOneWidget);
    expect(
        t
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        .5);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'API follow-up opens correct draft and service without submitting',
      (t) async {
    final f = ApiAppFixture();
    await f.mount(t);
    await t.tap(find.text('Hồ sơ').last);
    await t.pumpAndSettle();
    await openMe(t, 'Lịch tái khám');
    await openMe(t, 'Đặt lịch tái khám');
    expect(find.text('Đặt lịch khám'), findsOneWidget);
    expect(find.text('Tài khoản API (Bản thân)'), findsOneWidget);
    expect(
        f.requests.where(
            (r) => r.method == 'POST' && r.url.path == '/api/appointments'),
        isEmpty);
    expect(f.appointmentRows, hasLength(1));
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'API notification filters and mark-read open uncached appointment',
      (t) async {
    final f = ApiAppFixture();
    await f.mount(t);
    f.appointments.clear();
    f.records.replaceAppointments([]);
    await t.tap(find.text('Tôi').last);
    await t.pumpAndSettle();
    await openMe(t, 'Thông báo');
    await openMe(t, 'Ưu đãi');
    expect(find.text('Chưa có thông báo trong danh mục này.'), findsOneWidget);
    await openMe(t, 'Hệ thống');
    expect(find.text('Thông báo hệ thống API'), findsOneWidget);
    await openMe(t, 'Thông báo hệ thống API');
    expect(f.notices.last['isRead'], isTrue);
    await openMe(t, 'Lịch hẹn');
    await openMe(t, 'Thông báo lịch API');
    expect(find.text('Chi tiết lịch hẹn'), findsOneWidget);
    expect(f.notices.first['isRead'], isTrue);
    expect(f.records.recordsAppointmentId, 'appointment-api');
    expect(t.takeException(), isNull);
  });

  testWidgets('API empty articles and malformed optional content remain safe',
      (t) async {
    final f = ApiAppFixture();
    f.articles.single
      ..['content'] = ''
      ..['summary'] = ''
      ..['imageUrl'] = 'invalid';
    await f.mount(t);
    await openMe(t, 'Bài viết API');
    expect(find.text('Chưa có nội dung bài viết.'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'API login, shared scroll configuration, logout clears private state and Back',
      (t) async {
    final f = ApiAppFixture(signedIn: false);
    await f.mount(t, app: true);
    await openMe(t, 'Đăng nhập');
    await t.enterText(find.byType(TextFormField).first, ApiAppFixture.email);
    await t.enterText(find.byType(TextFormField).last, 'fixture-password');
    await openMe(t, 'Đăng nhập');
    await t.pump(const Duration(seconds: 1));
    await t.pumpAndSettle();
    expect(f.users.isAuthenticated, isTrue);
    expect(f.records.patients, hasLength(2));
    for (final label in ['Trang chủ', 'Đặt lịch', 'Hồ sơ', 'Tôi']) {
      await t.tap(find.text(label).last);
      await t.pumpAndSettle();
      for (final element in find.byType(Scrollable).evaluate()) {
        expect(ScrollConfiguration.of(element), isA<AppScrollBehavior>());
      }
    }
    await openMe(t, 'Đăng xuất');
    await openMe(t, 'Hủy');
    expect(f.users.isAuthenticated, isTrue);
    await openMe(t, 'Đăng xuất');
    await openMe(t, 'Đăng xuất');
    expect(f.records.patients, isEmpty);
    expect(f.records.appointments, isEmpty);
    expect(f.content.notifications, isEmpty);
    expect(f.catalog.isSaved('article', 'article-api'), isFalse);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Chăm sóc nụ cười của bạn'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  test('API booking quote comes from HTTP, not seeded demo prices', () async {
    final f = ApiAppFixture();
    await f.profiles.ensureLoaded();
    await f.catalog.load();
    final c = BookingController(f.records,
        profile: f.profiles,
        catalog: f.catalog,
        bookingService: BookingService(client: f.client),
        availabilityService: AvailabilityService(client: f.client));
    c.toggleService('service-api');
    await c.refreshQuote();
    expect(c.total, 125000);
    expect(c.quoteReady, isTrue);
    expect(f.requests.any((r) => r.url.path == '/api/bookings/quote'), isTrue);
    c.dispose();
    f.session.dispose();
    f.content.dispose();
    f.appointments.dispose();
    f.catalog.dispose();
    f.profiles.dispose();
    f.records.dispose();
    f.users.dispose();
    expect(f.unexpected, isEmpty);
  });
  testWidgets('API empty article list comes from GET rather than local fixture',
      (t) async {
    final f = ApiAppFixture()..articles.clear();
    await f.mount(t, home: const ArticleListScreen());
    expect(find.text('Chưa có bài viết.'), findsOneWidget);
    expect(f.requests.any((r) => r.url.path == '/api/articles'), isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('API missing notification text survives category changes',
      (t) async {
    final f = ApiAppFixture();
    f.notices
      ..clear()
      ..add({
        'id': 'missing-api',
        'title': '',
        'body': '',
        'type': 'system',
        'refId': '',
        'isRead': false
      });
    await f.mount(t, home: const ApiNotificationsView());
    expect(find.text('Chưa có nội dung thông báo.'), findsOneWidget);
    for (final label in [
      'Ưu đãi',
      'Lịch hẹn',
      'Tất cả',
      'Hệ thống',
      'Tất cả'
    ]) {
      await openMe(t, label);
      expect(f.content.notifications, hasLength(1));
    }
    expect(find.text('Chưa có nội dung thông báo.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'API Saved tabs reflect server article, service and doctor favorites',
      (t) async {
    final f = ApiAppFixture();
    f.favorites.addAll([
      {'id': 'service_service-api', 'type': 'service', 'itemId': 'service-api'},
      {'id': 'doctor_doctor-api', 'type': 'doctor', 'itemId': 'doctor-api'},
      {'id': 'article_article-api', 'type': 'article', 'itemId': 'article-api'},
    ]);
    await f.mount(t);
    await t.tap(find.text('Tôi').last);
    await t.pumpAndSettle();
    await openMe(t, 'Đã lưu');
    expect(find.text('Tất cả (3)'), findsOneWidget);
    expect(find.text('Dịch vụ (1)'), findsOneWidget);
    expect(find.text('Bác sĩ (1)'), findsOneWidget);
    await openMe(t, 'Bài viết (1)');
    expect(find.text('Bài viết API'), findsOneWidget);
    expect(find.text('Dịch vụ API'), findsNothing);
    await t.tap(find.byTooltip('Bỏ lưu Bài viết API'));
    await t.pumpAndSettle();
    expect(find.textContaining('Bài viết ('), findsNothing);
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(f.records.savedArticleIds, isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('API cancel sends PATCH and refreshes Home without a local write',
      (t) async {
    final f = ApiAppFixture();
    await f.mount(t);
    await t.tap(find.text('Hồ sơ').last);
    await t.pumpAndSettle();
    await openMe(t, 'Lịch hẹn');
    await t.tap(find.widgetWithText(Tab, 'Đã xác nhận'));
    await t.pumpAndSettle();
    await openMe(t, 'Dịch vụ API');
    await openMe(t, 'Hủy lịch');
    await openMe(t, 'Giữ lịch');
    expect(f.appointmentRows.single['status'], 'confirmed');
    await openMe(t, 'Hủy lịch');
    await openMe(t, 'Xác nhận hủy');
    expect(find.text('Đã hủy'), findsOneWidget);
    expect(
        f.requests.where((r) =>
            r.method == 'PATCH' &&
            r.url.path == '/api/appointments/appointment-api/cancel'),
        hasLength(1));
    await t.tap(find.text('Trang chủ').last);
    await t.pumpAndSettle();
    expect(find.text('Bạn chưa có lịch hẹn nào trong thời gian tới.'),
        findsOneWidget);
    expect(f.content.home!.appointment, isNull);
    expect(t.takeException(), isNull);
  });
}
