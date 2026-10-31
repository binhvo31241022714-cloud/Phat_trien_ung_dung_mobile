import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

enum ApiErrorKind {
  connection,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  validation,
  server,
  invalidResponse,
  http,
}

class ApiException implements Exception {
  final String message;
  final ApiErrorKind kind;
  final int? statusCode;
  const ApiException(this.message,
      {this.kind = ApiErrorKind.invalidResponse, this.statusCode});
  @override
  String toString() => message;
}

/// Shared transport. Understands Shelf's {success,message,data} envelope and
/// plain JSON. No request/response bodies or credentials are logged.
class ApiClient {
  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;
  // Có thể trả token ngay hoặc trả Future (ví dụ Firebase getIdToken).
  final FutureOr<String?> Function()? tokenProvider;

  ApiClient(
      {http.Client? client,
      String? baseUrl,
      this.timeout = ApiConstants.timeout,
      this.tokenProvider})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        baseUrl =
            (baseUrl ?? ApiConstants.baseUrl).replaceFirst(RegExp(r'/+$'), '');

  Uri _uri(String path) =>
      Uri.parse('$baseUrl/${path.replaceFirst(RegExp(r'^/+'), '')}');
  Future<Map<String, String>> _headers() async {
    final token = await tokenProvider?.call();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> get(String path) =>
      _send(() async => _client.get(_uri(path), headers: await _headers()));
  /// [headers] thêm header riêng cho request, ví dụ Idempotency-Key.
  Future<dynamic> post(String path, Map<String, dynamic> body,
          {Map<String, String>? headers}) =>
      _send(() async => _client.post(_uri(path),
          headers: {...await _headers(), ...?headers},
          body: jsonEncode(body)));
  Future<dynamic> put(String path, Map<String, dynamic> body) =>
      _send(() async => _client.put(_uri(path),
          headers: await _headers(), body: jsonEncode(body)));
  Future<dynamic> patch(String path, Map<String, dynamic> body) =>
      _send(() async => _client.patch(_uri(path),
          headers: await _headers(), body: jsonEncode(body)));
  Future<dynamic> delete(String path) =>
      _send(() async => _client.delete(_uri(path), headers: await _headers()));

  /// Tải dữ liệu nhị phân (ảnh) kèm token. Lỗi vẫn ném [ApiException] như JSON.
  Future<Uint8List> getBytes(String path) async => await _send(
      () async => _client.get(_uri(path), headers: await _headers()),
      raw: true) as Uint8List;

  Future<dynamic> _send(Future<http.Response> Function() request,
      {bool raw = false}) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout);
    } on TimeoutException {
      throw const ApiException('Máy chủ phản hồi quá thời gian chờ.',
          kind: ApiErrorKind.timeout);
    } on Exception {
      throw const ApiException('Không kết nối được tới máy chủ.',
          kind: ApiErrorKind.connection);
    }
    final status = response.statusCode;
    if (raw && status >= 200 && status < 300) return response.bodyBytes;
    dynamic decoded;
    var malformed = false;
    try {
      if (response.bodyBytes.isNotEmpty) {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      }
    } on FormatException {
      malformed = true;
    }
    if (status < 200 || status >= 300) {
      final kind = switch (status) {
        400 || 422 => ApiErrorKind.validation,
        401 => ApiErrorKind.unauthorized,
        403 => ApiErrorKind.forbidden,
        404 => ApiErrorKind.notFound,
        >= 500 => ApiErrorKind.server,
        _ => ApiErrorKind.http,
      };
      // Untrusted server errors can include internal details; keep 5xx generic.
      final message =
          status < 500 && decoded is Map && decoded['message'] is String
              ? decoded['message'] as String
              : 'Yêu cầu thất bại (HTTP $status).';
      throw ApiException(message, kind: kind, statusCode: status);
    }
    if (malformed) {
      throw ApiException('Phản hồi máy chủ không phải JSON hợp lệ.',
          statusCode: status);
    }
    if (decoded is Map && decoded.containsKey('success')) {
      if (decoded['success'] != true || !decoded.containsKey('data')) {
        throw ApiException('Phản hồi máy chủ không đúng hợp đồng dữ liệu.',
            statusCode: status);
      }
      return decoded['data'];
    }
    return decoded;
  }

  // Injected clients are owned by their caller.
  void close() {
    if (_ownsClient) _client.close();
  }
}
