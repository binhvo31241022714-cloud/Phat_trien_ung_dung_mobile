import 'package:frontend/core/config/app_config.dart';

/// Selects the data source for a test and restores the normal test-safe
/// configuration between cases.
void useDataSourceForTest(DataSource source) {
  AppConfig.current = AppConfig.fromValues(
    source: source == DataSource.mock ? 'mock' : 'api',
    baseUrl: 'http://fake.invalid:3000',
  );
}
