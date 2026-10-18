import 'dart:io';

import 'package:shelf/shelf.dart';

import '../core/api_response.dart';
import '../core/app_exception.dart';

/// Bắt mọi exception và trả về JSON thống nhất.
Middleware errorMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } on AppException catch (e) {
        return ApiResponse.error(e.statusCode, e.message);
      } on FormatException {
        return ApiResponse.error(400, 'Dữ liệu JSON không hợp lệ');
      } catch (e, st) {
        stderr.writeln('Lỗi không xác định: $e\n$st');
        return ApiResponse.error(500, 'Lỗi máy chủ');
      }
    };
  };
}
