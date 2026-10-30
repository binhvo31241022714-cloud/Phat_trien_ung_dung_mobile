import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/api_client.dart';
import 'package:frontend/data/models/article.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/providers/content_provider.dart';
import 'package:frontend/providers/catalog_provider.dart';
import 'package:frontend/providers/profile_provider.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/features/articles/article_detail_screen.dart';
import 'package:frontend/features/shared/favorite_button.dart';
import 'package:frontend/features/me/saved_items_screen.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'support/fake_catalog_backend.dart';
import 'support/fake_profile_backend.dart';
import 'module4_test.dart' as fixture;

void main() {
  test('wrong detail response ID is an error, never a cached article',
      () async {
    final p = ContentProvider(
        service: ContentService(
            client: ApiClient(
                client: MockClient((_) async => http.Response(
                        jsonEncode({...fixture.row, 'id': 'wrong-id'}), 200,
                        headers: {
                          'content-type': 'application/json; charset=utf-8'
                        })))));
    await p.loadArticle('article_01');
    expect(p.errors['article:article_01'], isNotNull);
    expect(p.details, isEmpty);
    p.dispose();
  });
  test('unread-count failure makes notifications load fail explicitly',
      () async {
    final p = ContentProvider(
        service: ContentService(client: ApiClient(client: MockClient((r) async {
      if (r.url.path.endsWith('unread-count')) {
        return http.Response('{"message":"count unavailable"}', 500);
      }
      if (r.url.path.endsWith('/notifications')) {
        return http.Response('[]', 200);
      }
      return http.Response(
          '{"featuredServices":[],"featuredDoctors":[],"latestArticles":[],"upcomingAppointment":null}',
          200);
    }))));
    p.setAccount('test');
    await p.loadNotifications();
    expect(p.errors['unread'], isNotNull);
    expect(p.errors['notifications'], isNotNull);
    expect(p.loaded.contains('notifications'), isFalse);
    p.dispose();
  });
  group('API isolation widgets', () {
    testWidgets(
        'detail never renders the input article if API cache is missing',
        (tester) async {
      final b = fixture.Backend();
      final p = b.provider();
      p.loaded.add('article:article_01');
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: p),
            ChangeNotifierProvider<CatalogProvider>(create: (_) => b.catalog()),
            ChangeNotifierProvider(create: (_) => PatientDataProvider()),
          ],
          child: MaterialApp(
              home: Scaffold(
                  body: ArticleDetailScreen(
                      article: Article.fromJson(fixture.row))))));
      // The first build must show an error, not the route's snapshot; initState then requests the API.
      expect(find.text('Nội dung API'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Nội dung API'), findsOneWidget);
    });
    testWidgets(
        'favorite load failure shows Retry instead of a false unsaved button',
        (tester) async {
      final b = fixture.Backend()..failure = 500;
      final c = b.catalog();
      await c.loadFavorites();
      await tester.pumpWidget(MultiProvider(
          providers: [ChangeNotifierProvider.value(value: c)],
          child: const MaterialApp(
              home: Scaffold(
                  body:
                      FavoriteButton(type: 'article', itemId: 'article_01')))));
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Lưu để xem sau'), findsNothing);
      b.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Lưu để xem sau'), findsOneWidget);
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
  group('Mock isolation widgets', () {
    testWidgets('demo home does not depend on live catalog availability',
        (tester) async {
      final backend = FakeCatalogBackend()..failStatus = 500;
      final catalog = backend.provider();
      await catalog.load();
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider(create: (_) => PatientDataProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider<ProfileProvider>(
            create: (_) => FakeProfileBackend().provider()),
      ], child: const MaterialApp(home: HomeScreen())));
      await tester.pumpAndSettle();
      expect(find.text('Khám tổng quát'), findsWidgets);
      expect(find.text('Thử lại'), findsNothing);
    });
    testWidgets(
        'demo saved article remains visible if Module 1 catalog is offline',
        (tester) async {
      final data = PatientDataProvider()
        ..toggleSavedArticle('article-brushing');
      final backend = FakeCatalogBackend()..failStatus = 500;
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider.value(value: data),
        ChangeNotifierProvider(create: (_) => backend.provider()),
      ], child: const MaterialApp(home: Scaffold(body: SavedItemsScreen()))));
      await tester.pumpAndSettle();
      expect(
          find.text('Chải răng đúng cách để bảo vệ nụ cười'), findsOneWidget);
    });
  }, skip: AppConfig.current.dataSource != DataSource.mock);
}
