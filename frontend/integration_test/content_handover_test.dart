import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart' as app;
import 'package:frontend/app/main_shell.dart';
import 'package:frontend/data/providers/patient_data_provider.dart';
import 'package:frontend/features/me/notifications_screen.dart';
import 'package:frontend/providers/user_provider.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Mock Android content, bookmarks, notification filters/read/link and logout',
      (tester) async {
    app.main();
    await tester.pumpAndSettle();
    Future<void> tap(String text) async {
      final finder = find.text(text).last;
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(finder, 250,
            scrollable: find.byType(Scrollable).first);
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tap('Đăng nhập');
    await tester.enterText(
        find.byType(TextFormField).first, 'handover.qa@example.invalid');
    await tester.enterText(find.byType(TextFormField).last, 'demo123456');
    await tap('Đăng nhập');
    final data =
        tester.element(find.byType(MainShell)).read<PatientDataProvider>();
    final user = tester.element(find.byType(MainShell)).read<UserProvider>();
    final accountId = user.account.id;
    await tap(data.articles.first.title);
    expect(find.text('Chi tiết bài viết'), findsOneWidget);
    await tap('Lưu để xem sau');
    expect(data.savedArticles.single.id, data.articles.first.id);
    await tap('Tôi');
    await tap('Đã lưu');
    await tap(data.articles.first.title);
    await tap('Đã lưu · Bỏ lưu');
    expect(data.savedArticles, isEmpty);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Chưa có nội dung đã lưu.'), findsOneWidget);
    await tap('Trang chủ');
    expect(find.text('Lưu để xem sau'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    final count = data.notifications.length;
    for (final label in ['Ưu đãi', 'Hệ thống', 'Lịch hẹn', 'Tất cả']) {
      final chip = find.widgetWithText(ChoiceChip, label);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(data.notifications.length, count);
    }
    final system =
        data.notifications.firstWhere((n) => n.appointmentId == null);
    await tap(system.title);
    expect(
        data.notifications.firstWhere((n) => n.id == system.id).isRead, true);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('content_notifications');
    final linked =
        data.notifications.firstWhere((n) => n.appointmentId != null);
    await tap(linked.title);
    expect(find.text('Chi tiết lịch hẹn'), findsOneWidget);
    expect(
        data.notifications.firstWhere((n) => n.id == linked.id).isRead, true);
    expect(user.account.id, accountId);
    await tap('Đặt lịch');
    expect(find.text('Chọn dịch vụ nha khoa'), findsOneWidget);
    await tap('Tôi');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tap('Đăng xuất');
    await tap('Đăng xuất');
    expect(user.isAuthenticated, false);
    expect(find.byType(MainShell), findsNothing);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
