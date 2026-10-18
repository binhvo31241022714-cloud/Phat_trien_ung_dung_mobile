import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/api_response.dart';
import '../core/app_exception.dart';
import '../services/user_service.dart';

/// Nhận request HTTP, gọi service và trả response.
class UserController {
  final UserService _service;

  UserController(this._service);

  Router get router {
    final router = Router();
    router.get('/', _getAll);
    router.get('/<id>', _getById);
    router.post('/', _create);
    router.put('/<id>', _update);
    router.delete('/<id>', _delete);
    return router;
  }

  Response _getAll(Request request) {
    final users = _service.getAll().map((u) => u.toJson()).toList();
    return ApiResponse.ok(users);
  }

  Response _getById(Request request, String id) {
    return ApiResponse.ok(_service.getById(_parseId(id)).toJson());
  }

  Future<Response> _create(Request request) async {
    final user = _service.create(await _readJson(request));
    return ApiResponse.created(user.toJson());
  }

  Future<Response> _update(Request request, String id) async {
    final user = _service.update(_parseId(id), await _readJson(request));
    return ApiResponse.ok(user.toJson(), message: 'Cập nhật thành công');
  }

  Response _delete(Request request, String id) {
    _service.delete(_parseId(id));
    return ApiResponse.ok(null, message: 'Xoá thành công');
  }

  int _parseId(String id) {
    final value = int.tryParse(id);
    if (value == null) throw const AppException.badRequest('ID không hợp lệ');
    return value;
  }

  Future<Map<String, dynamic>> _readJson(Request request) async {
    final decoded = jsonDecode(await request.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const AppException.badRequest('Body phải là JSON object');
    }
    return decoded;
  }
}
