import 'dart:convert';

import 'package:shelf/shelf.dart';

/// Chuẩn hoá format JSON trả về: { success, message, data }.
class ApiResponse {
  static const _headers = {'content-type': 'application/json; charset=utf-8'};

  static Response ok(Object? data, {String message = 'OK'}) =>
      _build(200, true, message, data);

  static Response created(Object? data, {String message = 'Tạo thành công'}) =>
      _build(201, true, message, data);

  static Response error(int statusCode, String message) =>
      _build(statusCode, false, message, null);

  static Response _build(
    int statusCode,
    bool success,
    String message,
    Object? data,
  ) {
    return Response(
      statusCode,
      body: jsonEncode({'success': success, 'message': message, 'data': data}),
      headers: _headers,
    );
  }
}
