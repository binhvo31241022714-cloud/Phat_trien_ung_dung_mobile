import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/widgets/horizontal_card_carousel.dart';

void main() {
  Future<void> mount(WidgetTester t,
      {int count = 4, double width = 320}) async {
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
      child: SizedBox(
          width: width,
          child: HorizontalCardCarousel(
            label: 'Test',
            itemCount: count,
            itemWidth: 180,
            itemHeight: 100,
            itemBuilder: (_, index) => Text('Card $index'),
          )),
    ))));
    await t.pumpAndSettle();
  }

  Finder arrow(String direction) => find.byKey(ValueKey('carousel-$direction'));
  double offset(WidgetTester t) => t
      .state<ScrollableState>(find.descendant(
          of: find.byType(HorizontalCardCarousel),
          matching: find.byType(Scrollable)))
      .position
      .pixels;

  testWidgets('arrows animate forward/back and disable exactly at boundaries',
      (t) async {
    await mount(t);
    expect(t.widget<IconButton>(arrow('previous')).onPressed, isNull);
    expect(t.widget<IconButton>(arrow('next')).onPressed, isNotNull);
    await t.tap(arrow('next'));
    await t.pumpAndSettle();
    expect(offset(t), greaterThan(0));
    await t.tap(arrow('previous'));
    await t.pumpAndSettle();
    expect(offset(t), 0);
    for (var i = 0; i < 4; i++) {
      await t.tap(arrow('next'));
      await t.pumpAndSettle();
    }
    expect(t.widget<IconButton>(arrow('next')).onPressed, isNull);
    expect(t.widget<IconButton>(arrow('previous')).onPressed, isNotNull);
  });

  testWidgets('manual swipe still scrolls and updates arrows', (t) async {
    await mount(t);
    await t.drag(find.byType(ListView), const Offset(-350, 0));
    await t.pumpAndSettle();
    expect(offset(t), greaterThan(0));
    expect(t.widget<IconButton>(arrow('previous')).onPressed, isNotNull);
    await t.drag(find.byType(ListView), const Offset(1000, 0));
    await t.pumpAndSettle();
    expect(offset(t), closeTo(0, 0.1));
    expect(t.widget<IconButton>(arrow('previous')).onPressed, isNull);
  });

  testWidgets('empty, one-card and fitting lists have no redundant controls',
      (t) async {
    for (final count in [0, 1, 2]) {
      await mount(t, count: count, width: 500);
      expect(find.byType(IconButton), findsNothing);
      expect(t.takeException(), isNull);
    }
  });

  testWidgets('controls respond to resizing and a shorter refreshed list',
      (t) async {
    await mount(t, width: 250);
    await t.tap(arrow('next'));
    await t.pumpAndSettle();
    await mount(t, count: 1, width: 500);
    expect(find.byType(IconButton), findsNothing);
    expect(offset(t), closeTo(0, 0.1));
    await mount(t, width: 250);
    expect(t.widget<IconButton>(arrow('previous')).onPressed, isNull);
    expect(t.widget<IconButton>(arrow('next')).onPressed, isNotNull);
    expect(t.takeException(), isNull);
  });
  for (final width in [250.0, 320.0, 430.0]) {
    testWidgets(
        'small arrows float over a full-width viewport without resizing cards at $width',
        (t) async {
      await mount(t, width: width);
      final carousel = t.getRect(find.byType(HorizontalCardCarousel));
      final viewport = t.getRect(find.byType(ListView));
      final left = t.getRect(arrow('previous'));
      final right = t.getRect(arrow('next'));
      expect(carousel.height, 100, reason: 'no controls above or below cards');
      expect(left.left, closeTo(carousel.left, 0.1));
      expect(right.right, closeTo(carousel.right, 0.1));
      expect(left.center.dy, closeTo(viewport.center.dy, 0.1));
      expect(right.center.dy, closeTo(viewport.center.dy, 0.1));
      expect(viewport.left, closeTo(carousel.left, 0.1));
      expect(viewport.right, closeTo(carousel.right, 0.1));
      expect(left.size, const Size(32, 32));
      expect(right.size, const Size(32, 32));
      expect(
          t
              .widget<Icon>(find.descendant(
                  of: arrow('next'), matching: find.byType(Icon)))
              .size,
          20);
      final firstCard = find
          .ancestor(of: find.text('Card 0'), matching: find.byType(SizedBox))
          .first;
      expect(t.getSize(firstCard).width, 180);
      expect(find.byType(IconButton), findsNWidgets(2));
      await t.tap(arrow('next'));
      await t.pumpAndSettle();
      expect(offset(t), greaterThan(0));
      expect(t.takeException(), isNull);
    });
  }
}
