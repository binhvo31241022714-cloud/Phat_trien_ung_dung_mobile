import 'dart:convert';
import 'dart:io';

import 'package:backend/middlewares/cors_middleware.dart';
import 'package:backend/middlewares/error_middleware.dart';
import 'package:backend/routes/app_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late HttpClient client;
  setUp(() async {
    server = await shelf_io.serve(
        const Pipeline()
            .addMiddleware(corsMiddleware())
            .addMiddleware(errorMiddleware())
            .addHandler(AppRouter().handler),
        InternetAddress.loopbackIPv4,
        0);
    client = HttpClient();
  });
  tearDown(() async {
    client.close(force: true);
    await server.close(force: true);
  });

  Future<(int, Map<String, dynamic>)> call(String method, String path,
      [Object? body]) async {
    final request = await client.openUrl(
        method, Uri.parse('http://127.0.0.1:${server.port}$path'));
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(body is String ? body : jsonEncode(body));
    }
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (response.statusCode, jsonDecode(text) as Map<String, dynamic>);
  }

  test('real HTTP health and isolated user CRUD contract', () async {
    final health = await call('GET', '/api/health');
    expect(health.$1, 200);
    expect(health.$2, {
      'success': true,
      'message': 'OK',
      'data': {'status': 'up'}
    });
    expect((await call('GET', '/api/users')).$2['data'], isEmpty);
    final created = await call('POST', '/api/users',
        {'name': 'HTTP test', 'email': 'http-test@example.invalid'});
    expect(created.$1, 201);
    final row = created.$2['data'] as Map;
    final id = row['id'];
    expect(id, isA<int>());
    expect(DateTime.tryParse(row['createdAt'] as String), isNotNull);
    expect((await call('GET', '/api/users/$id')).$2['data'], row);
    final updated = await call('PUT', '/api/users/$id', {'name': 'Updated'});
    expect(updated.$1, 200);
    expect(updated.$2['data']['name'], 'Updated');
    expect((await call('DELETE', '/api/users/$id')).$1, 200);
    expect((await call('GET', '/api/users/$id')).$1, 404);
  });

  test('validation, malformed JSON and unknown endpoints', () async {
    for (final body in [
      '{',
      '[]',
      {'name': 9, 'email': 'a@example.invalid'},
      {'name': 'A', 'email': false},
      {'name': '', 'email': 'bad'},
    ]) {
      expect((await call('POST', '/api/users', body)).$1, 400);
    }
    expect((await call('GET', '/api/users/not-an-id')).$1, 400);
    expect((await call('GET', '/api/missing')).$1, 404);
  });
}
