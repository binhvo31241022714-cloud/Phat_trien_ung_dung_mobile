import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Wrapper quanh package http. Backend trả về { success, message, data },
/// hàm nào cũng trả về phần `data` hoặc ném ApiException.
class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static const _headers = {'Content-Type': 'application/json'};

  Uri _uri(String path) => Uri.parse('${ApiConstants.baseUrl}$path');

  Future<dynamic> get(String path) =>
      _send(() => _client.get(_uri(path), headers: _headers));

  Future<dynamic> post(String path, Map<String, dynamic> body) => _send(() =>
      _client.post(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> put(String path, Map<String, dynamic> body) => _send(() =>
      _client.put(_uri(path), headers: _headers, body: jsonEncode(body)));

  Future<dynamic> delete(String path) =>
      _send(() => _client.delete(_uri(path), headers: _headers));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(ApiConstants.timeout);
    } catch (_) {
      throw const ApiException('Không kết nối được tới máy chủ');
    }

    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is Map<String, dynamic> && json['success'] == true) {
      return json['data'];
    }
    final message = json is Map<String, dynamic> ? json['message'] : null;
    throw ApiException(message?.toString() ?? 'Lỗi ${response.statusCode}');
  }
}
