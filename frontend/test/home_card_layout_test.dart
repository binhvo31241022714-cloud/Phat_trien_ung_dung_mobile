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
              matching: find.byWidgetPredicate((w) =>
                  w is SizedBox &&
                  w.width == (section == 'doctors' ? 120 : 180)));
          final height = t.getSize(cards.first).height;
          for (var i = 0; i < cards.evaluate().length; i++) {
            expect(t.getSize(cards.at(i)).height, height);
          }
        }
      });
    }
  }
}
