/// Địa chỉ backend.
/// - Web / Windows / iOS simulator: http://localhost:8080
/// - Android emulator: http://10.0.2.2:8080
/// - Máy thật: dùng IP LAN của máy chạy backend, ví dụ http://192.168.1.10:8080
/// Có thể ghi đè khi chạy: flutter run --dart-define=API_URL=http://...
class ApiConstants {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const users = '/api/users';
  static const timeout = Duration(seconds: 15);
}
