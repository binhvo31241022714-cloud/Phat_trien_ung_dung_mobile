import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/widgets/horizontal_card_carousel.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'support/api_app_fixture.dart';
import 'support/data_source_scope.dart';

/// Thêm 3 bản sao cho mỗi danh mục để carousel có thể cuộn.
void _addRows(ApiAppFixture f) {
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
}

const _keys = {
  'services': 'featuredServices',
  'doctors': 'doctors',
  'articles': 'articles',
};

/// Thẻ bác sĩ rộng bằng khung carousel; dịch vụ và bài viết có độ rộng cố định.
Finder _tiles(Finder carousel, String section) => find.descendant(
    of: carousel,
    matching: section == 'doctors'
        ? find.byWidgetPredicate((w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('home-doctor-card-'))
        : find.byWidgetPredicate((w) =>
            w is SizedBox &&
            w.width == (section == 'services' ? 176.0 : 180.0)));

void main() {
  setUp(() => useDataSourceForTest(DataSource.api));
  for (final section in ['services', 'doctors', 'articles']) {
    testWidgets('Home $section scroll, card and View all retain API navigation',
        (t) async {
      final f = ApiAppFixture();
      _addRows(f);
      await f.mount(t, width: 360, height: 700);
      final carousel = find.byKey(ValueKey('home-${_keys[section]}-carousel'));
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
      final position = t.state<ScrollableState>(scroll).position;
      final bounds = t.getRect(carousel);
      expect(t.getRect(scroll).left, closeTo(bounds.left, 0.1));
      expect(t.getRect(scroll).right, closeTo(bounds.right, 0.1));

      if (section == 'services') {
        // Chỉ mục Dịch vụ có mũi tên, nằm sát hai mép carousel.
        expect(t.getRect(previous).left, closeTo(bounds.left, 0.1));
        expect(t.getRect(next).right, closeTo(bounds.right, 0.1));
        expect(t.getRect(previous).center.dy,
            closeTo(t.getRect(next).center.dy, 0.1));
        expect(t.getRect(previous).center.dy, closeTo(bounds.top + 52, 0.1));
        // Ở đầu danh sách: không lùi được.
        expect(t.widget<IconButton>(previous).onPressed, isNull);
        await t.tap(next);
        await t.pumpAndSettle();
        expect(position.pixels, closeTo(176, 0.5));
        await t.tap(previous);
        await t.pumpAndSettle();
        expect(position.pixels, 0);
      } else {
        expect(next, findsNothing);
        expect(previous, findsNothing);
        // Bác sĩ cần quẹt (có vận tốc); kéo chậm dưới nửa thẻ sẽ bật về.
        if (section == 'doctors') {
          await t.fling(scroll, const Offset(-120, 0), 800);
        } else {
          await t.drag(scroll, const Offset(-120, 0));
        }
        await t.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        if (section == 'doctors') {
          // Bác sĩ dừng đúng mép thẻ kế tiếp.
          expect(position.pixels, closeTo(bounds.width - 8 + 12, 0.5));
        }
        position.jumpTo(0);
        await t.pump();
      }
      expect(f.requests.length, calls,
          reason: 'scrolling must not fetch the API');

      final cardText = {
        'services': 'Dịch vụ API',
        'doctors': 'Bác sĩ API',
        'articles': 'Bài viết API'
      }[section]!;
      final card = find.descendant(of: carousel, matching: find.text(cardText));
      await t.ensureVisible(card);
      await t.pumpAndSettle();
      if (section == 'services') {
        final title = t.getRect(card);
        for (final arrow in [t.getRect(previous), t.getRect(next)]) {
          expect(arrow.overlaps(title), isFalse,
              reason: 'floating controls must not cover the title');
        }
      }
      final tile = _tiles(carousel, section);
      expect(
          t.getSize(tile.first).width,
          {
            'services': 176.0,
            'doctors': bounds.width - 8,
            'articles': 180.0
          }[section]!);
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
      // Trang chủ giữ nguyên 3 nút "Xem tất cả".
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

  testWidgets('Home geometry at emulator logical size 1080x2400 density420',
      (t) async {
    final f = ApiAppFixture();
    _addRows(f);
    // adb wm: 1080x2400 pixels at 420 dpi => density ratio 420/160.
    const width = 1080 / (420 / 160);
    await f.mount(t, width: width, height: 2400 / (420 / 160));
    for (final section in ['services', 'doctors', 'articles']) {
      final carousel = find.byKey(ValueKey('home-${_keys[section]}-carousel'));
      await t.ensureVisible(carousel);
      await t.pumpAndSettle();
      final scroll =
          find.descendant(of: carousel, matching: find.byType(Scrollable));
      expect(t.getSize(scroll).width, closeTo(width - 32, 0.1));
      final tiles = _tiles(carousel, section);
      expect(tiles, findsWidgets);
      expect(
          t.getSize(tiles.first).width,
          closeTo(
              {
                'services': 176.0,
                'doctors': width - 32 - 8,
                'articles': 180.0
              }[section]!,
              0.1));
      // Các thẻ trong cùng carousel cao bằng nhau.
      final height = t.getSize(tiles.first).height;
      for (var i = 0; i < tiles.evaluate().length; i++) {
        expect(t.getSize(tiles.at(i)).height, height);
      }
      expect(t.takeException(), isNull);
    }
  });
}
