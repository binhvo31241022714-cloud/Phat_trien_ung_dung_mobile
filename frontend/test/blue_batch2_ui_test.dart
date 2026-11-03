import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/widgets/error_state.dart';
import 'package:frontend/data/models/article.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/features/articles/article_list_screen.dart';
import 'package:frontend/features/me/api_notifications_view.dart';
import 'package:frontend/features/me/notification_widgets.dart';
import 'package:frontend/features/shared/article_card.dart';
import 'support/api_app_fixture.dart';
import 'support/data_source_scope.dart';
import 'support/fake_catalog_backend.dart';

class PendingArticles extends ContentService {
  final result = Completer<List<Article>>();
  @override
  Future<List<Article>> articles() => result.future;
}

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
}

void main() {
  setUp(() => useDataSourceForTest(DataSource.api));
  for (final width in [320.0, 360.0, 411.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('article list/detail/save at $width/$scale', (t) async {
        final f = ApiAppFixture();
        f.articles.first['title'] =
            'Chăm sóc răng miệng để bảo vệ nụ cười mỗi ngày';
        f.articles.first['summary'] =
            'Hướng dẫn chăm sóc răng và nướu, cùng thông tin nha khoa.';
        f.articles.first['content'] =
            'Nội dung nha khoa đầy đủ và dễ đọc. ' * 12;
        await f.mount(t,
            width: width,
            height: 800,
            scale: scale,
            home: const Scaffold(body: ArticleListScreen()));
        expect(find.byType(ArticleCard), findsOneWidget);
        final title = find.text(f.articles.first['title'] as String);
        await t.ensureVisible(title);
        await t.tap(title);
        await t.pumpAndSettle();
        expect(find.text('Chi tiết bài viết'), findsOneWidget);
        expect(
            find.text(f.articles.first['content'] as String), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
        final save = find.text('Lưu để xem sau');
        await t.ensureVisible(save);
        await t.pumpAndSettle();
        await t.tap(save);
        await t.pumpAndSettle();
        expect(f.catalog.isSaved('article', 'article-api'), isTrue);
        expect(f.favorites.single['itemId'], 'article-api');
        await t.pageBack();
        await t.pumpAndSettle();
        expect(find.byType(ArticleCard), findsOneWidget);
        expect(t.takeException(), isNull);
      });

      testWidgets('notification filters and read actions at $width/$scale',
          (t) async {
        final f = ApiAppFixture();
        f.notices.clear();
        final names = [
          'Nhắc lịch hẹn',
          'Nhắc tái khám',
          'Ưu đãi nha khoa',
          'Tin hệ thống'
        ];
        final types = [
          'appointment_reminder',
          'follow_up_reminder',
          'offer',
          'system'
        ];
        for (var i = 0; i < types.length; i++) {
          f.notices.add({
            'id': 'n$i',
            'title': names[i],
            'body': 'Thông tin chi tiết để theo dõi sức khỏe răng miệng. ' * 2,
            'type': types[i],
            'refId': '',
            'isRead': false
          });
        }
        await f.mount(t,
            width: width,
            height: 800,
            scale: scale,
            home: const ApiNotificationsView());
        Future<void> filter(String label) async {
          final chip = find.widgetWithText(ChoiceChip, label);
          await t.ensureVisible(chip);
          await t.tap(chip);
          await t.pumpAndSettle();
        }

        await filter('Lịch hẹn');
        expect(find.text(names[0]), findsOneWidget);
        expect(find.text(names[1]), findsOneWidget);
        expect(find.text(names[2]), findsNothing);
        await filter('Ưu đãi');
        expect(find.text(names[2]), findsOneWidget);
        expect(find.text(names[0]), findsNothing);
        await filter('Hệ thống');
        final notice = find.text(names[3]);
        await t.ensureVisible(notice);
        await t.tap(notice);
        await t.pumpAndSettle();
        expect(f.notices[3]['isRead'], isTrue);
        expect(
            t
                .widget<NotificationCard>(
                    find.byKey(const ValueKey('notification-n3')))
                .isRead,
            isTrue);
        await filter('Tất cả');
        final readAll = find.text('Đọc tất cả');
        await t.ensureVisible(readAll);
        await t.tap(readAll);
        await t.pumpAndSettle();
        expect(f.notices.every((n) => n['isRead'] == true), isTrue);
        expect(f.content.unreadCount, 0);
        expect(
            f.requests.where((r) =>
                r.method == 'PATCH' &&
                r.url.path == '/api/notifications/read-all'),
            hasLength(1));
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'Home hero contrast, article callback and notification destination survive',
      (t) async {
    final f = ApiAppFixture();
    await f.mount(t, app: true, width: 320, scale: 1.5);
    final hero =
        t.widget<DecoratedBox>(find.byKey(const ValueKey('home-hero')));
    final gradient =
        (hero.decoration as BoxDecoration).gradient as LinearGradient;
    final scrim = t.widget<DecoratedBox>(find
        .descendant(
            of: find.byKey(const ValueKey('home-hero')),
            matching: find.byType(DecoratedBox))
        .first);
    final tint = (scrim.decoration as BoxDecoration).color!;
    for (final base in gradient.colors) {
      expect(contrast(Colors.white, Color.alphaBlend(tint, base)),
          greaterThanOrEqualTo(4.5));
    }
    final bar = t.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(4));
    expect(bar.indicatorColor, AppColors.accent);
    for (final destination in bar.destinations.cast<NavigationDestination>()) {
      expect((destination.selectedIcon as Icon).color, AppColors.sky);
      expect((destination.icon as Icon).color, AppColors.textSecondary);
    }
    final carousel = find.byKey(const ValueKey('home-articles-carousel'));
    final footer =
        find.descendant(of: carousel, matching: find.byType(Text)).last;
    await t.ensureVisible(footer);
    await t.pumpAndSettle();
    expect(t.getRect(footer).bottom,
        lessThanOrEqualTo(t.getRect(find.byType(NavigationBar)).top));
    final article = find.text('Bài viết API');
    await t.ensureVisible(article);
    await t.tap(article);
    await t.pumpAndSettle();
    expect(find.text('Chi tiết bài viết'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    final bell = find.byTooltip('Thông báo');
    await t.ensureVisible(bell);
    await t.tap(bell);
    await t.pumpAndSettle();
    expect(find.byType(ApiNotificationsView), findsOneWidget);
    final notice = find.text('Thông báo lịch API');
    await t.ensureVisible(notice);
    await t.tap(notice);
    await t.pumpAndSettle();
    expect(f.notices.first['isRead'], isTrue);
    expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2);
    expect(find.text('Chi tiết lịch hẹn'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('articles error retries the same endpoint; empty stays empty',
      (t) async {
    final f = ApiAppFixture();
    f.articleFailure = 500;
    await f.mount(t, home: const Scaffold(body: ArticleListScreen()));
    expect(find.byType(ErrorState), findsOneWidget);
    f.articleFailure = null;
    await t.tap(find.text('Thử lại'));
    await t.pumpAndSettle();
    expect(find.byType(ArticleCard), findsOneWidget);
    expect(f.requests.where((r) => r.url.path == '/api/articles').length, 2);
    f.articles.clear();
    await f.content.loadArticles();
    await t.pumpAndSettle();
    expect(find.text('Chưa có bài viết.'), findsOneWidget);
    expect(find.byType(ArticleCard), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('empty Home keeps its empty states and booking CTA', (t) async {
    final f = ApiAppFixture();
    f.services.clear();
    f.doctors.clear();
    f.articles.clear();
    f.appointmentRows.clear();
    await f.mount(t, app: true, width: 320, scale: 1.5);
    expect(find.text('Bạn chưa có lịch hẹn nào trong thời gian tới.'),
        findsOneWidget);
    expect(find.text('Chưa có dịch vụ nổi bật.'), findsOneWidget);
    expect(find.text('Chưa có thông tin bác sĩ.'), findsOneWidget);
    expect(find.text('Chưa có bài viết.'), findsOneWidget);
    final book = find.text('Đặt lịch ngay');
    await t.ensureVisible(book);
    await t.pumpAndSettle();
    await t.tap(book);
    await t.pumpAndSettle();
    expect(
        t.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    expect(
        f.requests.where(
            (r) => r.method == 'POST' && r.url.path == '/api/appointments'),
        isEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('pending articles shows loading then the empty state', (t) async {
    final service = PendingArticles();
    final content = ContentProvider(service: service)
      ..setAccount('offline-user');
    final catalog = FakeCatalogBackend().provider();
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      content.dispose();
      catalog.dispose();
    });
    await t.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: content),
          ChangeNotifierProvider<CatalogProvider>.value(value: catalog),
        ],
        child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: ArticleListScreen()))));
    await t.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.result.complete([]);
    await t.pumpAndSettle();
    expect(find.text('Chưa có bài viết.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
