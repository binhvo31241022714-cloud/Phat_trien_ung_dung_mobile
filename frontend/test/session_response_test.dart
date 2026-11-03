import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/services/content_service.dart';
import 'package:frontend/providers/content_provider.dart';
import 'support/data_source_scope.dart';

class DeferredHome extends ContentService {
  final pending = <Completer<ContentHome>>[];
  @override
  Future<ContentHome> home() {
    final c = Completer<ContentHome>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  setUp(() => useDataSourceForTest(DataSource.api));
  test('late A Home cannot overwrite B or remove B in-flight loading',
      () async {
    final service = DeferredHome();
    final p = ContentProvider(service: service);
    p.setAccount('A');
    final a = p.loadHome();
    p.setAccount('B');
    final b = p.loadHome();
    expect(service.pending.length, 2);
    service.pending[0].complete(ContentHome.fromParts());
    await a;
    expect(p.home, isNull);
    expect(p.loading('home'), isTrue);
    service.pending[1].complete(ContentHome.fromParts());
    await b;
    expect(p.home, isNotNull);
    expect(p.loading('home'), isFalse);
    p.dispose();
  });

  test('late A 401 cannot refresh, retry or sign out B', () async {
    var generation = 1;
    var refreshes = 0;
    var logouts = 0;
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final client = ApiClient(
      baseUrl: 'http://fixture.invalid',
      sessionVersionProvider: () => generation,
      tokenProvider: () => 'test-token',
      refreshTokenProvider: () async {
        refreshes++;
        return 'new-token';
      },
      onUnauthorized: () {
        logouts++;
      },
      client: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    final request = client.get('/api/users/me');
    final result = expectLater(request, throwsA(isA<ApiException>()));
    await started.future;
    generation++;
    response.complete(http.Response('{}', 401));
    await result;
    expect(refreshes, 0);
    expect(logouts, 0);
  });

  test('expired token refresh fails and expires the current session', () async {
    var logouts = 0;
    final client = ApiClient(
      baseUrl: 'http://fixture.invalid',
      refreshTokenProvider: () async => throw Exception('expired refresh'),
      onUnauthorized: () {
        logouts++;
      },
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(
        client.get('/api/users/me'), throwsA(isA<ApiException>()));
    expect(logouts, 1);
  });
}
