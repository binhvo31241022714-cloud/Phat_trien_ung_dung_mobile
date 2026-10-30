import 'package:flutter/foundation.dart';

enum DataSource { mock, api }

/// Compile-time configuration; never put credentials in dart-define.
class AppConfig {
  final DataSource dataSource;
  final String apiBaseUrl;
  const AppConfig._(this.dataSource, this.apiBaseUrl);

  factory AppConfig.fromValues({
    String source = 'api',
    String baseUrl = '',
    bool isWeb = false,
    TargetPlatform platform = TargetPlatform.linux,
  }) {
    final mode = switch (source.trim().toLowerCase()) {
      'mock' => DataSource.mock,
      'api' => DataSource.api,
      _ => throw ArgumentError('DATA_SOURCE phải là mock hoặc api'),
    };
    final url = baseUrl.trim().isNotEmpty
        ? baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')
        : (!isWeb && platform == TargetPlatform.android
            ? 'http://10.0.2.2:3000'
            : 'http://localhost:3000');
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw ArgumentError(
          'API_BASE_URL phải là URL HTTP(S), không chứa credentials');
    }
    return AppConfig._(mode, url);
  }

  static AppConfig _current = AppConfig.fromValues(
    source: const String.fromEnvironment('DATA_SOURCE', defaultValue: 'api'),
    baseUrl: const String.fromEnvironment('API_BASE_URL',
        defaultValue: String.fromEnvironment('API_URL')),
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  static AppConfig get current => _current;

  /// Test tự chọn nguồn dữ liệu (xem test/flutter_test_config.dart).
  @visibleForTesting
  static set current(AppConfig value) => _current = value;
}
