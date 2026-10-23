import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'content_handover_test.dart' as content;
import 'final_flow_test.dart' as demo;

/// Block app-isolate HTTP without touching the backend or changing production
/// code. HttpClient construction is allowed; any attempted request fails.
class _OfflineGuard extends HttpOverrides {
  int requests = 0;
  @override
  HttpClient createHttpClient(SecurityContext? context) => _BlockedClient(this);
}

class _BlockedClient implements HttpClient {
  _BlockedClient(this.guard);
  final _OfflineGuard guard;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    guard.requests++;
    throw StateError('Mock baseline attempted an HTTP request');
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final guard = _OfflineGuard();
  HttpOverrides? previous;
  setUpAll(() {
    expect(AppConfig.current.dataSource, DataSource.mock);
    previous = HttpOverrides.current;
    HttpOverrides.global = guard;
  });
  tearDownAll(() {
    HttpOverrides.global = previous;
    expect(guard.requests, 0,
        reason: 'Mock demo must work without any HTTP requests');
    // Counts only; never log URLs, request bodies, tokens or account data.
    // ignore: avoid_print
    print('MOCK_HTTP_ATTEMPTS=${guard.requests}');
  });
  if (const bool.fromEnvironment('CONTENT_SCENARIO')) {
    content.main();
  } else {
    demo.main();
  }
}
