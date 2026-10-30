import 'package:frontend/core/config/app_config.dart';

/// Ép app dùng dữ liệu giả trong test, giữ nguyên API_BASE_URL đang có.
/// App mặc định DATA_SOURCE=api nên test cần gọi hàm này để không gọi mạng.
void useMockDataSource() {
  AppConfig.current = AppConfig.fromValues(
      source: 'mock', baseUrl: AppConfig.current.apiBaseUrl);
}
