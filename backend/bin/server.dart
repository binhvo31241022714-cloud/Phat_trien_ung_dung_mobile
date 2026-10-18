import 'dart:io';

import 'package:backend/config/env.dart';
import 'package:backend/middlewares/cors_middleware.dart';
import 'package:backend/middlewares/error_middleware.dart';
import 'package:backend/routes/app_router.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final env = Env.load();

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(errorMiddleware())
      .addHandler(AppRouter().handler);

  final server = await io.serve(handler, env.host, env.port);
  stdout.writeln('Server chạy tại http://${server.address.host}:${server.port}');
}
