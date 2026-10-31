import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';

/// Scope a fixture to the mode whose contract it describes. Never change the
/// runner default or skip a test. tearDown restores the caller's configuration.
void useDataSourceForTest(DataSource source) {
  final previous = AppConfig.current;
  AppConfig.current =
      AppConfig.fromValues(source: source.name, baseUrl: previous.apiBaseUrl);
  addTearDown(() => AppConfig.current = previous);
}
