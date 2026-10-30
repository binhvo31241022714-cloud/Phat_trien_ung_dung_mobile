import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/models/user_model.dart';
import 'package:frontend/data/repositories/user_read_repository.dart';
import 'package:frontend/data/services/user_service.dart';
import 'package:frontend/providers/user_provider.dart';
import 'package:frontend/screens/user/user_list_screen.dart';

final row = {
  'id': 37,
  'name': 'API User',
  'email': 'test@example.invalid',
  'createdAt': '2026-10-21T09:00:00+07:00'
};
String envelope(Object? data) =>
    jsonEncode({'success': true, 'message': 'OK', 'data': data});
Matcher apiError(ApiErrorKind kind, [int? status]) => isA<ApiException>()
    .having((e) => e.kind, 'kind', kind)
    .having((e) => e.statusCode, 'status', status);
AppConfig config(String source) =>
    AppConfig.fromValues(source: source, baseUrl: 'http://localhost:8080');

void main() {
  test('API default, explicit mock and configured URL', () {
    expect(AppConfig.fromValues().dataSource, DataSource.api);
    expect(config('mock').dataSource, DataSource.mock);
    expect(
        AppConfig.fromValues(baseUrl: 'https://example.invalid:9000/')
            .apiBaseUrl,
        'https://example.invalid:9000');
    expect(AppConfig.fromValues(platform: TargetPlatform.android).apiBaseUrl,
        'http://10.0.2.2:3000');
    expect(
        AppConfig.fromValues(platform: TargetPlatform.android, isWeb: true)
            .apiBaseUrl,
        'http://localhost:3000');
    expect(() => config('typo'), throwsArgumentError);
    expect(() => AppConfig.fromValues(baseUrl: 'http://user:secret@host'),
        throwsArgumentError);
  });

  test('valid Shelf envelope, UTF-8 and empty response', () async {
    final client = ApiClient(
        client: MockClient((request) async {
          expect(
              request.url.toString(), 'http://example.invalid:8080/api/users');
          expect(request.headers['Authorization'], isNull);
          return http.Response.bytes(
              utf8.encode(envelope({'name': 'Nguyễn Mai'})), 200);
        }),
        baseUrl: 'http://example.invalid:8080/');
    expect(await client.get('/api/users'), {'name': 'Nguyễn Mai'});
    final empty =
        ApiClient(client: MockClient((_) async => http.Response('', 204)));
    expect(await empty.delete('/api/users/1'), isNull);
  });

  test('plain JSON is not forced into an envelope', () async {
    final client =
        ApiClient(client: MockClient((_) async => http.Response('[1,2]', 200)));
    expect(await client.get('/plain'), [1, 2]);
  });

  for (final body in [
    '<html>oops',
    '{',
    '{"success":true}',
    '{"success":false,"data":null}'
  ]) {
    test('invalid response: $body', () async {
      final client =
          ApiClient(client: MockClient((_) async => http.Response(body, 200)));
      await expectLater(client.get('/api/users'),
          throwsA(apiError(ApiErrorKind.invalidResponse, 200)));
    });
  }
  for (final entry in {
    400: ApiErrorKind.validation,
    401: ApiErrorKind.unauthorized,
    403: ApiErrorKind.forbidden,
    404: ApiErrorKind.notFound,
    422: ApiErrorKind.validation,
    500: ApiErrorKind.server,
  }.entries) {
    test('HTTP ${entry.key} even with malformed body', () async {
      final client = ApiClient(
          client:
              MockClient((_) async => http.Response('not JSON', entry.key)));
      await expectLater(
          client.get('/api/users'), throwsA(apiError(entry.value, entry.key)));
    });
  }

  test('timeout distinct from connection', () async {
    final slow = ApiClient(
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) => Completer<http.Response>().future));
    await expectLater(
        slow.get('/api/users'), throwsA(apiError(ApiErrorKind.timeout)));
    final offline = ApiClient(
        client: MockClient((_) async => throw http.ClientException('offline')));
    await expectLater(
        offline.get('/api/users'), throwsA(apiError(ApiErrorKind.connection)));
  });

  test('POST PUT DELETE methods and optional token, never supplied by default',
      () async {
    final seen = <String>[];
    final client = ApiClient(
        tokenProvider: () => 'test-only-token',
        client: MockClient((r) async {
          seen.add(r.method);
          expect(r.headers['Authorization'], 'Bearer test-only-token');
          if (r.method != 'DELETE') expect(jsonDecode(r.body), {'name': 'Mai'});
          return http.Response(envelope(null), 200);
        }));
    await client.post('/api/users', {'name': 'Mai'});
    await client.put('/api/users/1', {'name': 'Mai'});
    await client.delete('/api/users/1');
    expect(seen, ['POST', 'PUT', 'DELETE']);
  });

  test('API repository preserves int ID and timestamp instant', () async {
    final repo = ApiUserReadRepository(ApiClient(
        client: MockClient((_) async => http.Response(envelope([row]), 200))));
    final user = (await repo.getAll()).single;
    expect(user.id, 37);
    expect(user.createdAt.toUtc(), DateTime.utc(2026, 10, 21, 2));
    expect(user.phone, '');
    expect(user.dateOfBirth, isNull);
    expect(
        UserModel.fromJson({...row, 'createdAt': '2026-10-21T09:00:00'})
            .createdAt
            .isUtc,
        false);
  });

  test('API repository rejects incompatible types without mock fallback',
      () async {
    for (final data in [
      null,
      {},
      [null],
      [
        {...row, 'id': '37'}
      ],
      [
        {...row, 'createdAt': 'bad'}
      ]
    ]) {
      final repo = ApiUserReadRepository(ApiClient(
          client: MockClient((_) async => http.Response(envelope(data), 200))));
      await expectLater(repo.getAll(), throwsA(isA<ApiException>()));
    }
    final repo = ApiUserReadRepository(ApiClient(
        client: MockClient((_) async => http.Response('failure', 500))));
    await expectLater(
        repo.getAll(), throwsA(apiError(ApiErrorKind.server, 500)));
  });

  test('mock mode uses repository and never contacts a stopped backend',
      () async {
    var requests = 0;
    final api = ApiClient(client: MockClient((_) async {
      requests++;
      throw http.ClientException('backend stopped');
    }));
    final mock = createUserReadRepository(config('mock'), api);
    expect(mock, isA<MockUserReadRepository>());
    expect(await mock.getAll(), isEmpty);
    expect(createUserReadRepository(config('api'), api),
        isA<ApiUserReadRepository>());
    final service = UserService(api: api, config: config('mock'));
    expect(await service.getAll(), isEmpty);
    await expectLater(
        service.create('A', 'a@example.invalid'), throwsA(isA<ApiException>()));
    expect(requests, 0);
  });

  testWidgets('existing list displays loading, API empty, error and retry',
      (tester) async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final api = ApiClient(client: MockClient((_) async {
      requests++;
      if (requests == 1) return pending.future;
      if (requests == 2) return http.Response('unavailable', 500);
      return http.Response(envelope([row]), 200);
    }));
    final provider =
        UserProvider(service: UserService(api: api, config: config('api')));
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider, child: const MaterialApp(home: UserListScreen())));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(http.Response(envelope([]), 200));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có người dùng nào'), findsOneWidget);
    await provider.fetchUsers();
    await tester.pumpAndSettle();
    expect(provider.users, isEmpty);
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    // Retry UI uses existing AppErrorView callback.
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('API User'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
