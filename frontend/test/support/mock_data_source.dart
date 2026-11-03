import 'package:frontend/core/config/app_config.dart';

void useMockDataSource() {
  AppConfig.current = AppConfig.fromValues(
    source: 'mock',
    baseUrl: 'http://fake.invalid:3000',
  );
}
