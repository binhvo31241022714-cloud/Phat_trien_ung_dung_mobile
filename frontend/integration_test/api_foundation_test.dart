import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:frontend/main.dart' as app;
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/routes/app_routes.dart';
import 'package:frontend/screens/user/user_list_screen.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const unavailable = bool.fromEnvironment('EXPECT_BACKEND_UNAVAILABLE');
  testWidgets('Android real API transport and existing list state',
      (tester) async {
    expect(AppConfig.current.dataSource, DataSource.api);
    final api = ApiClient();
    try {
      if (unavailable) {
        await expectLater(
            api.get('/api/health'),
            throwsA(isA<ApiException>()
                .having((e) => e.kind, 'kind', ApiErrorKind.connection)));
      } else {
        expect(await api.get('/api/health'), {'status': 'up'});
      }
    } finally {
      api.close();
    }
    app.main();
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.users);
    await tester.pumpAndSettle();
    final provider =
        tester.element(find.byType(UserListScreen)).read<UserProvider>();
    // Integration bindings use the real HTTP stack, not MockClient.
    for (var i = 0; provider.isLoading && i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(provider.isLoading, false);
    if (unavailable) {
      expect(find.text('Không kết nối được tới máy chủ.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(provider.users, isEmpty);
      expect(find.text('Chưa có người dùng nào'), findsNothing);
    } else {
      expect(provider.error, isNull);
      // Do not assume or modify another developer's in-memory users.
      if (provider.users.isEmpty) {
        expect(find.text('Chưa có người dùng nào'), findsOneWidget);
      } else {
        expect(find.text(provider.users.first.name), findsWidgets);
      }
    }
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding
        .takeScreenshot(unavailable ? 'api_unavailable' : 'api_users_live');
  });
}
