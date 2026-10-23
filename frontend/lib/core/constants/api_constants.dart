import '../config/app_config.dart';

class ApiConstants {
  // API_URL remains a compatible alias; API_BASE_URL takes priority.
  static String get baseUrl => AppConfig.current.apiBaseUrl;
  static const users = '/api/users';
  static const health = '/api/health';
  static const timeout = Duration(seconds: 15);
}
