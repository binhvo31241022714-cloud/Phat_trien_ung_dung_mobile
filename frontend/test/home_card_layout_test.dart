import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'support/api_app_fixture.dart';
import 'support/data_source_scope.dart';

void main() {
  setUp(() => useDataSourceForTest(DataSource.api));
  for (final width in [320.0, 1080 / (420 / 160)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('Home cards fit at width $width and scale $scale', (t) async {
        final f = ApiAppFixture();
        f.appointmentRows.clear();
        f.articles.first['title'] =
            'Chăm sóc răng miệng đúng cách để bảo vệ sức khỏe mỗi ngày';
        f.articles
            .add({...f.articles.first, 'id': 'short', 'title': 'Răng khỏe'});
        f.content.setAccount(ApiAppFixture.owner);
        await f.content.loadHome();
        await f.mount(t,
            width: width, height: 800, scale: scale, home: const HomeScreen());
        for (final section in ['doctors', 'articles']) {
          final carousel = find.byKey(ValueKey('home-$section-carousel'));
          await t.ensureVisible(carousel);
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          final cards = find.descendant(
              of: carousel,
              matching: section == 'doctors'
                  ? find.byWidgetPredicate((w) =>
                      w.key is ValueKey<String> &&
                      (w.key as ValueKey<String>)
                          .value
                          .startsWith('home-doctor-card-'))
                  : find.byWidgetPredicate(
                      (w) => w is SizedBox && w.width == 180));
          final height = t.getSize(cards.first).height;
          if (section == 'doctors') {
            // Thẻ bác sĩ rộng bằng khung carousel (trừ padding 4 mỗi bên).
            expect(t.getSize(cards.first).width,
                closeTo(t.getSize(carousel).width - 8, 0.1));
          }
          for (var i = 0; i < cards.evaluate().length; i++) {
            expect(t.getSize(cards.at(i)).height, height);
          }
        }
      });
    }
  }

  testWidgets('Home doctors swipe moves exactly one doctor per gesture',
      (t) async {
    final f = ApiAppFixture();
    final sample = Map<String, dynamic>.from(f.doctors.first);
    f.doctors.addAll([
      for (var i = 1; i < 4; i++)
        {...sample, 'id': '${sample['id']}-$i', 'name': '${sample['name']} $i'}
    ]);
    f.content.setAccount(ApiAppFixture.owner);
    await f.content.loadHome();
    await f.mount(t, width: 360, height: 800, home: const HomeScreen());
    final carousel = find.byKey(const ValueKey('home-doctors-carousel'));
    await t.ensureVisible(carousel);
    await t.pumpAndSettle();
    final scroll =
        find.descendant(of: carousel, matching: find.byType(Scrollable));
    final position = t.state<ScrollableState>(scroll).position;
    final page = t.getSize(carousel).width - 8 + 12;
    // Vuốt ngắn vẫn sang đúng 1 thẻ; vuốt mạnh cũng không nhảy quá 1 thẻ.
    await t.fling(carousel, const Offset(-60, 0), 400);
    await t.pumpAndSettle();
    expect(position.pixels, closeTo(page, 0.5));
    await t.fling(carousel, const Offset(-300, 0), 3000);
    await t.pumpAndSettle();
    expect(position.pixels, closeTo(page * 2, 0.5));
    await t.fling(carousel, const Offset(60, 0), 400);
    await t.pumpAndSettle();
    expect(position.pixels, closeTo(page, 0.5));
    expect(t.takeException(), isNull);
  });
}
