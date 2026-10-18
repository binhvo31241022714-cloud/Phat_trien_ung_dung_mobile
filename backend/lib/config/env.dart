import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Đọc cấu hình từ file .env (nếu có) và biến môi trường hệ thống.
class Env {
  final String host;
  final int port;

  const Env({required this.host, required this.port});

  factory Env.load() {
    final dotenv = DotEnv(includePlatformEnvironment: true);
    if (File('.env').existsSync()) dotenv.load();

    return Env(
      host: dotenv['HOST'] ?? '0.0.0.0',
      port: int.tryParse(dotenv['PORT'] ?? '') ?? 8080,
    );
  }
}
