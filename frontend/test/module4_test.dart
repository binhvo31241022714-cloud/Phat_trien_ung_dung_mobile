import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/article.dart';
import 'package:frontend/data/models/content_date.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/data/services/catalog_service.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/appointments_provider.dart';
import 'package:frontend/features/articles/article_list_screen.dart';
import 'package:frontend/features/articles/article_detail_screen.dart';
import 'package:frontend/features/me/api_notifications_view.dart';
import 'package:frontend/features/me/saved_items_screen.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'support/fake_profile_backend.dart';
import 'support/fake_appointments_provider.dart';

const row = <String, dynamic>{
  'id': 'article_01',
  'title': 'Bài thật API',
  'summary': 'Tóm tắt',
  'content': 'Nội dung API',
  'category': 'Chăm sóc',
  'publishedAt': {'_seconds': 1790812800, '_nanoseconds': 0},
  'imageUrl': ''
};

class Backend {
  final requests = <http.Request>[];
  final favorites = <Map<String, dynamic>>[];
  int? failure;
  bool empty = false;
  final notices = <Map<String, dynamic>>[
    {
      'id': 'n1',
      'title': 'Thông báo API',
      'body': 'Nội dung thông báo',
      'type': 'system',
      'refId': '',
      'isRead': false,
      'createdAt': {'_seconds': 1790812800}
    }
  ];
  late final client = ApiClient(client: MockClient((request) async {
    requests.add(request);
    if (failure != null) {
      return http.Response(jsonEncode({'message': 'Lỗi kiểm thử'}), failure!,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    final path = request.url.path;
    Object result;
    if (path == '/api/articles') {
      result = empty ? [] : [row];
    } else if (path == '/api/articles/article_01') {
      result = row;
    } else if (path == '/api/home') {
      result = {
        'featuredServices': [],
        'featuredDoctors': [],
        'latestArticles': empty ? [] : [row],
        'upcomingAppointment': null
      };
    } else if (path == '/api/notifications/unread-count') {
      result = {
        'count': empty ? 0 : notices.where((n) => n['isRead'] == false).length
      };
    } else if (path == '/api/notifications') {
      result = empty ? [] : notices;
    } else if (path == '/api/notifications/read-all') {
      for (final n in notices) {
        n['isRead'] = true;
      }
      result = {'updatedCount': notices.length};
    } else if (path == '/api/notifications/n1/read') {
      notices.first['isRead'] = true;
      result = {'id': 'n1', 'isRead': true};
    } else if (path == '/api/favorites' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      favorites.add({...body, 'id': '${body['type']}_${body['itemId']}'});
      result = {'id': favorites.last['id']};
    } else if (path.startsWith('/api/favorites/') &&
        request.method == 'DELETE') {
      favorites.removeWhere((f) => path.endsWith(f['id']));
      result = {'message': 'Đã xóa'};
    } else if (path == '/api/favorites') {
      result = favorites;
    } else {
      return http.Response('{}', 404);
    }
    return http.Response(jsonEncode(result), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }));
  ContentProvider provider() =>
      ContentProvider(service: ContentService(client: client));
  CatalogProvider catalog() =>
      CatalogProvider(service: CatalogService(client: client));
}

Future<void> settle() => Future<void>.delayed(Duration.zero);
Future<ContentProvider> ready(Backend b) async {
  final p = b.provider();
  p.setAccount('a');
  await p.loadHome();
  await p.loadUnread();
  await p.loadNotifications();
  return p;
}

Future<void> mount(
    WidgetTester tester, Backend b, ContentProvider p, Widget page) async {
  await tester.pumpWidget(MultiProvider(providers: [
    ChangeNotifierProvider.value(value: p),
    ChangeNotifierProvider(create: (_) => PatientDataProvider()),
    ChangeNotifierProvider(create: (_) => b.catalog()),
    ChangeNotifierProvider(create: (_) => UserProvider()..signInDemo('a')),
    ChangeNotifierProvider<ProfileProvider>(
        create: (_) => FakeProfileBackend().provider()),
    ChangeNotifierProvider<AppointmentsProvider>(
        create: (_) => FakeAppointmentsProvider()),
  ], child: MaterialApp(home: Scaffold(body: page))));
  await tester.pumpAndSettle();
}

void main() {
  test('Timestamp JSON, ISO, missing and malformed dates are safe', () {
    expect(
        contentDate({'_seconds': 1, '_nanoseconds': 500000000})!
            .toUtc()
            .millisecondsSinceEpoch,
        1500);
    expect(contentDate({'seconds': 1})!.toUtc().millisecondsSinceEpoch, 1000);
    expect(contentDate('2026-10-01T00:00:00Z'), isNotNull);
    for (final input in [
      null,
      {},
      {'_seconds': 'bad'},
      {'_seconds': double.infinity},
      {'_seconds': 1e100},
      'bad'
    ]) {
      expect(contentDate(input), isNull);
    }
  });
  test('article mapping does not invent reading minutes or date', () {
    final a = Article.fromJson(row);
    expect(a.id, 'article_01');
    expect(a.body, 'Nội dung API');
    expect(a.readingMinutes, isNull);
    expect(Article.fromJson({}).hasPublishedDate, isFalse);
    expect(Article.fromJson({...row, 'readingMinutes': 4}).readingMinutes, 4);
  });
  test('service uses current article endpoints', () async {
    final b = Backend();
    final s = ContentService(client: b.client);
    expect((await s.articles()).single.id, 'article_01');
    expect((await s.article('article_01')).title, 'Bài thật API');
    expect(b.requests.map((r) => r.url.path),
        ['/api/articles', '/api/articles/article_01']);
  });
  test('malformed responses are errors', () async {
    final s = ContentService(
        client: ApiClient(
            client: MockClient((_) async => http.Response('{}', 200))));
    await expectLater(s.articles(), throwsA(isA<ApiException>()));
    await expectLater(s.unreadCount(), throwsA(isA<ApiException>()));
  });
  test('guest never requests private endpoints', () async {
    final b = Backend();
    final p = b.provider();
    await p.loadHome();
    await p.loadUnread();
    await p.loadNotifications();
    await p.markRead('n1');
    await p.readAll();
    expect(b.requests, isEmpty);
    p.dispose();
  });
  test('articles error has no mock fallback and supports retry', () async {
    final b = Backend()..failure = 500;
    final p = b.provider();
    await p.loadArticles();
    expect(p.errors['articles'], isNotNull);
    expect(p.articles, isEmpty);
    b.failure = null;
    await p.loadArticles();
    expect(p.errors['articles'], isNull);
    expect(p.articles.single.id, 'article_01');
    p.dispose();
  });
  test('empty articles remain empty', () async {
    final b = Backend()..empty = true;
    final p = b.provider();
    await p.loadArticles();
    expect(p.articles, isEmpty);
    expect(p.loaded, contains('articles'));
    p.dispose();
  });
  test('home has no mock appointment or catalog fallback', () async {
    final b = Backend();
    final p = await ready(b);
    expect(p.home!.appointment, isNull);
    expect(p.home!.services, isEmpty);
    expect(p.home!.articles.single.id, 'article_01');
    p.dispose();
  });
  test('failed PATCH preserves count, successful PATCH updates idempotently',
      () async {
    final b = Backend();
    final p = await ready(b);
    b.failure = 500;
    await p.markRead('n1');
    expect(p.errors['read'], isNotNull);
    expect(p.notifications.single.isRead, isFalse);
    expect(p.unreadCount, 1);
    b.failure = null;
    await p.markRead('n1');
    expect(p.notifications.single.isRead, isTrue);
    expect(p.unreadCount, 0);
    await p.markRead('n1');
    expect(p.unreadCount, 0);
    p.dispose();
  });
  test('read-all failure preserves state; success updates all', () async {
    final b = Backend();
    final p = await ready(b);
    b.failure = 403;
    await p.readAll();
    expect(p.unreadCount, 1);
    expect(p.notifications.single.isRead, isFalse);
    b.failure = null;
    await p.readAll();
    expect(p.unreadCount, 0);
    expect(p.notifications.single.isRead, isTrue);
    p.dispose();
  });
  test('account switch clears private state and rejects old response',
      () async {
    final pending = Completer<http.Response>();
    final client = ApiClient(client: MockClient((r) async {
      if (r.url.path == '/api/notifications') return pending.future;
      if (r.url.path.endsWith('unread-count')) {
        return http.Response('{"count":0}', 200);
      }
      return http.Response(
          '{"featuredServices":[],"featuredDoctors":[],"latestArticles":[],"upcomingAppointment":null}',
          200);
    }));
    final p = ContentProvider(service: ContentService(client: client));
    p.setAccount('a');
    await settle();
    final job = p.loadNotifications();
    p.setAccount('b');
    pending.complete(http.Response('[{"id":"old","isRead":false}]', 200));
    await job;
    expect(p.notifications, isEmpty);
    expect(p.unreadCount, 0);
    p.setAccount(null);
    await settle();
    expect(p.home, isNull);
    expect(p.details, isEmpty);
    p.dispose();
  });
  test('in-flight article requests are deduplicated', () async {
    final pending = Completer<http.Response>();
    int calls = 0;
    final p = ContentProvider(
        service: ContentService(client: ApiClient(client: MockClient((_) {
      calls++;
      return pending.future;
    }))));
    final first = p.loadArticles();
    final second = p.loadArticles();
    expect(p.loading('articles'), isTrue);
    pending.complete(http.Response('[]', 200));
    await Future.wait([first, second]);
    expect(calls, 1);
    expect(p.loading('articles'), isFalse);
    p.dispose();
  });
  test('favorite uses article type and real id, shared state add/remove',
      () async {
    final b = Backend();
    final c = b.catalog();
    await c.loadFavorites();
    await c.toggleFavorite('article', 'article_01');
    expect(c.isSaved('article', 'article_01'), isTrue);
    expect(b.favorites.single['itemId'], 'article_01');
    await c.toggleFavorite('article', 'article_01');
    expect(c.isSaved('article', 'article_01'), isFalse);
    expect(b.requests.any((r) => r.body.contains('article-brushing')), isFalse);
    c.dispose();
  });
  test('late favorite write cannot cross account sessions', () async {
    final pending = Completer<http.Response>();
    final c = CatalogProvider(
        service: CatalogService(
            client: ApiClient(client: MockClient((_) => pending.future))));
    final write = c.toggleFavorite('article', 'article_01');
    c.clear();
    pending.complete(http.Response('{}', 200));
    await write;
    expect(c.favorites, isEmpty);
    c.dispose();
  });
  test('late unread response cannot undo a successful PATCH', () async {
    final pending = Completer<http.Response>();
    final p = ContentProvider(
        service: ContentService(client: ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('unread-count')) return pending.future;
      return http.Response(
          r.method == 'PATCH'
              ? '{}'
              : '{"featuredServices":[],"featuredDoctors":[],"latestArticles":[],"upcomingAppointment":null}',
          200);
    }))));
    p.setAccount('a');
    await settle();
    p.notifications = [
      ContentNotification.fromJson({'id': 'n1', 'isRead': false})
    ];
    p.unreadCount = 1;
    final count = p.loadUnread();
    await p.markRead('n1');
    pending.complete(http.Response('{"count":1}', 200));
    await count;
    expect(p.unreadCount, 0);
    p.dispose();
  });
  test('user lifecycle clears favorites and private content', () async {
    final b = Backend();
    final p = b.provider();
    final c = b.catalog();
    final users = UserProvider();
    p.bindUser(users, c);
    users.signInDemo('a');
    await p.loadHome();
    await p.loadNotifications();
    await c.toggleFavorite('article', 'article_01');
    users.signInDemo('b');
    expect(c.favorites, isEmpty);
    expect(p.notifications, isEmpty);
    expect(p.home, isNull);
    users.signOutDemo();
    await settle();
    expect(p.signedIn, isFalse);
    expect(p.unreadCount, 0);
    p.dispose();
    c.dispose();
    users.dispose();
  });
  test('home refreshes after appointments change', () async {
    final b = Backend();
    final p = await ready(b);
    p.appointmentsChanged('old');
    final before = b.requests.where((r) => r.url.path == '/api/home').length;
    p.appointmentsChanged('new');
    await settle();
    expect(
        b.requests.where((r) => r.url.path == '/api/home').length, before + 1);
    p.dispose();
  });
  testWidgets('notifications Retry then read-all UI', (tester) async {
    final b = Backend();
    final p = await ready(b);
    b.failure = 500;
    await mount(tester, b, p, const ApiNotificationsView());
    expect(find.text('Thử lại'), findsOneWidget);
    b.failure = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Thông báo API'), findsOneWidget);
    expect(find.text('Chưa đọc'), findsOneWidget);
    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Đã đọc'), findsOneWidget);
    expect(p.unreadCount, 0);
  });
  testWidgets('notifications empty UI', (tester) async {
    final b = Backend()..empty = true;
    final p = await ready(b);
    await mount(tester, b, p, const ApiNotificationsView());
    expect(find.text('Chưa có thông báo trong danh mục này.'), findsOneWidget);
  });
  group('API mode widgets', () {
    testWidgets('article list to detail shares bookmark', (tester) async {
      final b = Backend();
      final p = await ready(b);
      await mount(tester, b, p, const ArticleListScreen());
      expect(find.text('Bài thật API'), findsOneWidget);
      await tester.tap(find.byTooltip('Lưu bài viết'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bài thật API'));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung API'), findsOneWidget);
      expect(find.text('Đã lưu · Bỏ lưu'), findsOneWidget);
      expect(find.textContaining('phút'), findsNothing);
    });
    testWidgets('article list error Retry and empty API states',
        (tester) async {
      final b = Backend()..failure = 500;
      final p = b.provider();
      await mount(tester, b, p, const ArticleListScreen());
      expect(find.text('Thử lại'), findsOneWidget);
      b.failure = null;
      b.empty = true;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có bài viết.'), findsOneWidget);
      expect(find.text('Bài thật API'), findsNothing);
    });
    testWidgets('network article image failure uses placeholder',
        (tester) async {
      final b = Backend();
      final p = ContentProvider(
          service: ContentService(
              client: ApiClient(
                  client: MockClient((_) async => http.Response(
                          jsonEncode({
                            ...row,
                            'imageUrl': 'http://invalid.test/image.png'
                          }),
                          200,
                          headers: {
                            'content-type': 'application/json; charset=utf-8'
                          })))));
      await mount(
          tester, b, p, ArticleDetailScreen(article: Article.fromJson(row)));
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('detail 404 shows Retry without fallback', (tester) async {
      final b = Backend()..failure = 404;
      final p = b.provider();
      await mount(
          tester, b, p, ArticleDetailScreen(article: Article.fromJson(row)));
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Nội dung API'), findsNothing);
    });
    testWidgets('saved articles use real favorites', (tester) async {
      final b = Backend();
      b.favorites.add({
        'id': 'article_article_01',
        'type': 'article',
        'itemId': 'article_01'
      });
      final p = await ready(b);
      await mount(tester, b, p, const SavedItemsScreen());
      expect(find.text('Bài thật API'), findsOneWidget);
      expect(find.text('Bài viết (1)'), findsOneWidget);
    });
    testWidgets('home uses API and unread badge', (tester) async {
      final b = Backend();
      final p = await ready(b);
      await mount(tester, b, p, const HomeScreen());
      expect(find.text('1'), findsOneWidget);
      expect(find.text('Chưa có dịch vụ nổi bật.'), findsOneWidget);
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Bài thật API'), findsOneWidget);
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
}
