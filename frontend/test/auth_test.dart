import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/services/auth_service.dart';
import 'package:frontend/providers/user_provider.dart';

import 'support/fake_auth_service.dart';

void main() {
  test('Firebase error codes map to Vietnamese messages', () {
    expect(FirebaseAuthService.messageFor('invalid-credential'),
        'Email hoặc mật khẩu không đúng.');
    expect(FirebaseAuthService.messageFor('email-already-in-use'),
        'Email này đã được đăng ký.');
    expect(FirebaseAuthService.messageFor('weak-password'),
        contains('Mật khẩu quá yếu'));
    expect(FirebaseAuthService.messageFor('something-new'),
        'Có lỗi xảy ra, vui lòng thử lại.');
  });

  test('login returns the error message and stays signed out on failure',
      () async {
    final auth = FakeAuthService()
      ..failWith = 'Email hoặc mật khẩu không đúng.';
    final users = UserProvider(auth: auth);
    expect(await users.login('a@example.com', 'sai'),
        'Email hoặc mật khẩu không đúng.');
    expect(users.isAuthenticated, isFalse);

    auth.failWith = null;
    expect(await users.login('a@example.com', 'dung123'), isNull);
    expect(users.isAuthenticated, isTrue);
    expect(users.account.email, 'a@example.com');

    await users.logout();
    expect(users.isAuthenticated, isFalse);
    expect(auth.email, isNull);
  });

  test('restoreSession signs in and syncs when Firebase remembers a user',
      () async {
    final auth = FakeAuthService(email: 'saved@example.com');
    final users = UserProvider(auth: auth);
    await users.restoreSession();
    await Future<void>.delayed(Duration.zero);
    expect(users.isAuthenticated, isTrue);
    expect(users.account.email, 'saved@example.com');
    expect(auth.syncCalls, 1);

    final empty = UserProvider(auth: FakeAuthService());
    await empty.restoreSession();
    expect(empty.isAuthenticated, isFalse);
  });

  test('ApiClient awaits an async token provider', () async {
    String? header;
    final api = ApiClient(
      baseUrl: 'http://example.invalid:3000',
      client: MockClient((request) async {
        header = request.headers['Authorization'];
        return http.Response('{}', 200);
      }),
      tokenProvider: () async => 'firebase-token',
    );
    await api.post('/api/users/sync', {});
    expect(header, 'Bearer firebase-token');
  });
}
