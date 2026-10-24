import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/theme/app_scroll_behavior.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/data/models/article.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/screens/home/home_screen.dart';
import 'package:frontend/data/models/patient_records.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/articles/article_detail_screen.dart';
import 'package:frontend/features/articles/article_list_screen.dart';
import 'package:frontend/features/shared/article_card.dart';
import 'package:frontend/features/me/notifications_screen.dart';
import 'package:frontend/providers/user_provider.dart';

import 'support/fake_profile_backend.dart';

class ContentFixture extends PatientDataProvider {
  ContentFixture(this.items);
  final List<Article> items;
  @override
  List<Article> get articles => items;
}

class MissingNotification extends PatientDataProvider {
  @override
  UnmodifiableListView<PatientNotification> get notifications =>
      UnmodifiableListView([
        PatientNotification(
            id: 'missing', title: '', message: '', createdAt: DateTime(2026)),
      ]);
}

Article article({String? content, String summary = '', String? image}) =>
    Article(
        id: 'content-test',
        title: 'Bài viết kiểm thử',
        summary: summary,
        content: content,
        category: 'Kiểm thử giao diện',
        publishedAt: DateTime(2026),
        readingMinutes: 2,
        imageAsset: image);
Future<void> mount(WidgetTester tester, PatientDataProvider data, Widget page,
    double width) async {
  tester.view.physicalSize = Size(width, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: data),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => FakeProfileBackend().provider()),
      ],
      child: MaterialApp(
          theme: AppTheme.light,
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(body: page))));
  await tester.pumpAndSettle();
}

void main() {
  test(
      'article optional body preserves demo summaries and meaningful missing state',
      () {
    expect(article(summary: 'Mô tả').body, 'Mô tả');
    expect(article(content: '  ', summary: 'Mô tả').body, 'Mô tả');
    expect(article(content: 'Nội dung đầy đủ', summary: 'Mô tả').body,
        'Nội dung đầy đủ');
    expect(article().body, 'Chưa có nội dung bài viết.');
  });
  for (final width in [360.0, 390.0, 430.0]) {
    testWidgets('long article scrolls and bookmark stays unique at $width',
        (tester) async {
      final a = article(
          content:
              List.filled(80, 'Nội dung kiểm thử cuộn văn bản.').join('\n'));
      final data = ContentFixture([a]);
      await mount(tester, data, ArticleDetailScreen(article: a), width);
      expect(find.text(a.body), findsOneWidget);
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels,
          greaterThan(0));
      await tester.scrollUntilVisible(find.text('Lưu để xem sau'), 450,
          scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lưu để xem sau'));
      await tester.pumpAndSettle();
      expect(data.savedArticleIds, {'content-test'});
      expect(data.savedArticles, hasLength(1));
      await tester.tap(find.text('Đã lưu · Bỏ lưu'));
      await tester.pumpAndSettle();
      expect(data.savedArticles, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('new appointment and cancellation immediately update Home',
      (tester) async {
    final data = PatientDataProvider();
    for (final a in data.appointments.toList()) {
      if (a.patientId == data.primaryPatient.id) data.cancelAppointment(a.id);
    }
    await mount(tester, data, const HomeScreen(), 390);
    expect(find.text('Bạn chưa có lịch hẹn nào trong thời gian tới.'),
        findsOneWidget);
    data.addAppointment(Appointment(
        id: 'handover-appointment',
        patientId: data.primaryPatient.id,
        serviceIds: [data.services.first.id],
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
        status: AppointmentStatus.pending));
    await tester.pumpAndSettle();
    expect(find.text('Sắp diễn ra'), findsOneWidget);
    expect(find.text('Bạn chưa có lịch hẹn nào trong thời gian tới.'),
        findsNothing);
    expect(data.cancelAppointment('handover-appointment'), true);
    await tester.pumpAndSettle();
    expect(find.text('Sắp diễn ra'), findsNothing);
    expect(find.text('Bạn chưa có lịch hẹn nào trong thời gian tới.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing description and invalid image asset render fallback',
      (tester) async {
    final a = article(image: 'assets/images/does-not-exist.png');
    final data = ContentFixture([a]);
    await mount(tester, data, ArticleCard(article: a), 360);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mount(tester, data, ArticleDetailScreen(article: a), 360);
    expect(find.text('Chưa có nội dung bài viết.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty article list has a real empty state', (tester) async {
    await mount(tester, ContentFixture([]), const ArticleListScreen(), 390);
    expect(find.text('Chưa có bài viết.'), findsOneWidget);
  });
  testWidgets(
      'missing notification text and repeated category changes preserve data',
      (tester) async {
    final data = MissingNotification();
    await mount(tester, data, const NotificationsScreen(), 360);
    expect(find.text('Thông báo'), findsNWidgets(2));
    expect(find.text('Chưa có nội dung thông báo.'), findsOneWidget);
    for (final label in [
      'Ưu đãi',
      'Lịch hẹn',
      'Tất cả',
      'Hệ thống',
      'Tất cả'
    ]) {
      final filter = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(data.notifications, hasLength(1));
    }
    expect(find.text('Chưa có nội dung thông báo.'), findsOneWidget);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
