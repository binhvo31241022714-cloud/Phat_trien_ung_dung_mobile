import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:frontend/core/network/api_client.dart';

// Read-only transport smoke against the current Node backend; no legacy users UI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const unavailable = bool.fromEnvironment('EXPECT_BACKEND_UNAVAILABLE');
  testWidgets('Node backend public catalog transport', (tester) async {
    final client = ApiClient();
    try {
      if (unavailable) {
        await expectLater(
            client.get('/api/services'),
            throwsA(isA<ApiException>()
                .having((e) => e.kind, 'kind', ApiErrorKind.connection)));
      } else {
        for (final path in ['/api/services', '/api/doctors', '/api/articles']) {
          expect(await client.get(path), isA<List>());
        }
      }
    } finally {
      client.close();
    }
  });
}
