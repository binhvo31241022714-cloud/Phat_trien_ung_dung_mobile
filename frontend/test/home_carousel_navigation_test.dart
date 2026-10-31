import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/widgets/horizontal_card_carousel.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'support/api_app_fixture.dart';
import 'support/data_source_scope.dart';

void main() {
  setUp(() => useDataSourceForTest(DataSource.api));
  for (final section in ['services', 'doctors', 'articles']) {
    testWidgets('Home $section arrows, card and View all retain API navigation',
        (t) async {
      final f = ApiAppFixture();
      for (final rows in [f.services, f.doctors, f.articles]) {
        final sample = Map<String, dynamic>.from(rows.first);
        rows.addAll([
          for (var i = 1; i < 4; i++)
            {
              ...sample,
              'id': '${sample['id']}-$i',
              if (sample.containsKey('name')) 'name': '${sample['name']} $i',
              if (sample.containsKey('title')) 'title': '${sample['title']} $i',
            }
        ]);
      }
      await f.mount(t, width: 360, height: 700);
      final key = {
        'services': 'featuredServices',
        'doctors': 'doctors',
        'articles': 'articles'
      }[section]!;
      final carousel = find.byKey(ValueKey('home-$key-carousel'));
      await t.ensureVisible(carousel);
      await t.pumpAndSettle();
      final calls = f.requests.length;
      final next = find.descendant(
          of: carousel, matching: find.byKey(const ValueKey('carousel-next')));
      final previous = find.descendant(
          of: carousel,
          matching: find.byKey(const ValueKey('carousel-previous')));
      final scroll =
          find.descendant(of: carousel, matching: find.byType(Scrollable));
      final viewport = t.getRect(
          find.descendant(of: carousel, matching: find.byType(ListView)));
      final left = t.getRect(previous);
      final right = t.getRect(next);
      final bounds = t.getRect(carousel);
      final controlCenter =
          {'services': 43.0, 'doctors': 42.0, 'articles': 58.0}[section]!;
      expect(left.center.dy, closeTo(viewport.top + controlCenter, 0.1));
      expect(right.center.dy, closeTo(viewport.top + controlCenter, 0.1));
      expect(left.left, closeTo(bounds.left, 0.1));
      expect(right.right, closeTo(bounds.right, 0.1));
      expect(viewport.left, closeTo(bounds.left, 0.1));
      expect(viewport.right, closeTo(bounds.right, 0.1));
      expect(left.size, const Size(32, 32));
      expect(right.size, const Size(32, 32));
      expect(find.descendant(of: carousel, matching: find.byType(IconButton)),
          findsNWidgets(2));
      await t.tap(next);
      await t.pumpAndSettle();
      expect(t.state<ScrollableState>(scroll).position.pixels, greaterThan(0));
      await t.tap(previous);
      await t.pumpAndSettle();
      expect(t.state<ScrollableState>(scroll).position.pixels, 0);
      expect(f.requests.length, calls, reason: 'arrows must not fetch the API');
      final cardText = {
        'services': 'Dịch vụ API',
        'doctors': 'Bác sĩ API',
        'articles': 'Bài viết API'
      }[section]!;
      final card = find.descendant(of: carousel, matching: find.text(cardText));
      await t.ensureVisible(card);
      final titleBounds = t.getRect(card);
      final currentArrows = [t.getRect(previous), t.getRect(next)];
      for (final arrowBounds in currentArrows) {
        expect(arrowBounds.overlaps(titleBounds), isFalse,
            reason: 'floating controls must not cover the title/name');
      }
      final tile =
          find.ancestor(of: card, matching: find.byType(SizedBox)).first;
      expect(t.getSize(tile).width,
          {'services': 176.0, 'doctors': 120.0, 'articles': 180.0}[section]);
      await t.tap(card);
      await t.pumpAndSettle();
      final detail = {
        'services': 'Chi tiết dịch vụ',
        'doctors': 'Chi tiết bác sĩ',
        'articles': 'Chi tiết bài viết'
      }[section]!;
      expect(find.text(detail), findsOneWidget);
      await t.tap(find.byIcon(Icons.arrow_back).first);
      await t.pumpAndSettle();
      // Home keeps all three existing View-all actions; the arrows are separate.
      final action = find
          .text('Xem tất cả')
          .at({'services': 0, 'doctors': 1, 'articles': 2}[section]!);
      await t.ensureVisible(action);
      await t.tap(action);
      await t.pumpAndSettle();
      final title = {
        'services': 'Dịch vụ nha khoa',
        'doctors': 'Đội ngũ bác sĩ',
        'articles': 'Kiến thức nha khoa'
      }[section]!;
      expect(find.text(title), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Home single API cards show no extra arrows at small width',
      (t) async {
    final f = ApiAppFixture();
    await f.mount(t, width: 320, height: 700, scale: 1.5);
    expect(find.byType(HorizontalCardCarousel), findsNWidgets(3));
    expect(find.byKey(const ValueKey('carousel-next')), findsNothing);
    expect(find.byKey(const ValueKey('carousel-previous')), findsNothing);
    expect(t.takeException(), isNull);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  testWidgets(
      'original Home geometry at current emulator logical size 1080x2400 density420',
      (t) async {
    final f = ApiAppFixture();
    for (final rows in [f.services, f.doctors, f.articles]) {
      final sample = Map<String, dynamic>.from(rows.first);
      rows.addAll([
        for (var i = 1; i < 4; i++) {...sample, 'id': '${sample['id']}-$i'}
      ]);
    }
    // adb wm: 1080x2400 pixels at 420 dpi => density ratio 420/160.
    await f.mount(t, width: 1080 / (420 / 160), height: 2400 / (420 / 160));
    for (final entry in [
      ('featuredServices', 176.0, 182.0),
      ('doctors', 120.0, 156.0),
      ('articles', 180.0, 206.0),
    ]) {
      final carousel = find.byKey(ValueKey('home-${entry.$1}-carousel'));
      await t.ensureVisible(carousel);
      await t.pumpAndSettle();
      final viewport =
          find.descendant(of: carousel, matching: find.byType(ListView));
      expect(t.getSize(viewport).width, closeTo(1080 / (420 / 160) - 32, 0.1));
      expect(t.getSize(carousel).height, entry.$3);
      final tile = find.descendant(
          of: viewport,
          matching: find
              .byWidgetPredicate((w) => w is SizedBox && w.width == entry.$2));
      expect(tile, findsWidgets);
      expect(t.getSize(tile.first).width, entry.$2);
      final next = find.descendant(
          of: carousel, matching: find.byKey(const ValueKey('carousel-next')));
      await t.tap(next);
      await t.pumpAndSettle();
      final scroll =
          find.descendant(of: carousel, matching: find.byType(Scrollable));
      expect(t.state<ScrollableState>(scroll).position.pixels, greaterThan(0));
      expect(t.takeException(), isNull);
    }
  });
}
