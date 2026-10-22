import '../core/app_exception.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';

/// Xử lý nghiệp vụ và kiểm tra dữ liệu cho User.
class UserService {
  final UserRepository _repository;

  UserService(this._repository);

  List<User> getAll() => _repository.findAll();

  User getById(int id) {
    final user = _repository.findById(id);
    if (user == null) throw AppException.notFound('Không tìm thấy user $id');
    return user;
  }

  User create(Map<String, dynamic> body) {
    final name = _string(body, 'name')?.trim() ?? '';
    final email = _string(body, 'email')?.trim() ?? '';
    _validate(name, email);

    if (_repository.findByEmail(email) != null) {
      throw const AppException.badRequest('Email đã tồn tại');
    }
    return _repository.create(name: name, email: email);
  }

  User update(int id, Map<String, dynamic> body) {
    final current = getById(id);
    final name = _string(body, 'name')?.trim() ?? current.name;
    final email = _string(body, 'email')?.trim() ?? current.email;
    _validate(name, email);

    final existing = _repository.findByEmail(email);
    if (existing != null && existing.id != id) {
      throw const AppException.badRequest('Email đã tồn tại');
    }
    return _repository.update(current.copyWith(name: name, email: email));
  }

  void delete(int id) {
    if (!_repository.delete(id)) {
      throw AppException.notFound('Không tìm thấy user $id');
    }
  }

  String? _string(Map<String, dynamic> body, String key) {
    final value = body[key];
    if (value != null && value is! String) {
      throw AppException.badRequest('$key phải là chuỗi');
    }
    return value as String?;
  }

  void _validate(String name, String email) {
    if (name.isEmpty) {
      throw const AppException.badRequest('Tên không được để trống');
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      throw const AppException.badRequest('Email không hợp lệ');
    }
  }
}
