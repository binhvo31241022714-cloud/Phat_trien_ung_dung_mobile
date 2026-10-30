import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'module4_test.dart' as fixture;

void main() {
  group('API Home article image', () {
    Future<void> mount(WidgetTester tester, String? url) async {
      final b = fixture.Backend();
      final content = await fixture.ready(b);
      content.home = ContentHome({
        'featuredServices': [],
        'featuredDoctors': [],
        'latestArticles': [
          {...fixture.row, 'imageUrl': url}
        ],
        'upcomingAppointment': null,
      });
      await fixture.mount(tester, b, content, const HomeScreen());
      await tester.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
    }

    testWidgets('uses API URL with original image bounds and rounded corners',
        (tester) async {
      const url = 'https://example.test/article-real.jpg';
      await mount(tester, url);
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as NetworkImage).url, url);
      expect(image.fit, BoxFit.cover);
      final clip = find
          .ancestor(of: find.byType(Image), matching: find.byType(ClipRRect))
          .first;
      expect(tester.getSize(clip).height, 96);
      expect(tester.widget<ClipRRect>(clip).borderRadius,
          BorderRadius.circular(14));
      expect(tester.takeException(), isNull);
    });
    testWidgets('missing or blank URL uses book icon without an image request',
        (tester) async {
      for (final url in <String?>[null, '', '   ']) {
        await tester.pumpWidget(const SizedBox());
        await mount(tester, url);
        expect(find.byType(Image), findsNothing);
        expect(
            find.byWidgetPredicate((w) =>
                w is Icon && w.icon == Icons.menu_book_rounded && w.size == 38),
            findsOneWidget);
      }
    });
    testWidgets(
        'failed network image falls back and preserves article navigation',
        (tester) async {
      // Widget tests return HTTP 400 for image requests; no live URL is contacted.
      await mount(tester, 'https://example.test/broken.jpg');
      expect(
          find.byWidgetPredicate((w) =>
              w is Icon && w.icon == Icons.menu_book_rounded && w.size == 38),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bài thật API'));
      await tester.pumpAndSettle();
      expect(find.text('Nội dung API'), findsOneWidget);
    });
  }, skip: AppConfig.current.dataSource != DataSource.api);
}
