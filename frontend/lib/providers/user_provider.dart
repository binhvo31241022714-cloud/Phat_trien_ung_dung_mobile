import 'package:flutter/foundation.dart';

import '../data/models/user_model.dart';
import '../data/services/user_service.dart';

/// Quản lý state danh sách user cho UI.
class UserProvider extends ChangeNotifier {
  final UserService _service;

  UserProvider({UserService? service}) : _service = service ?? UserService();

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _users = await _service.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Trả về null nếu thành công, ngược lại trả về thông báo lỗi.
  Future<String?> saveUser({int? id, required String name, required String email}) async {
    try {
      if (id == null) {
        _users = [..._users, await _service.create(name, email)];
      } else {
        final updated = await _service.update(id, name, email);
        _users = [for (final u in _users) u.id == id ? updated : u];
      }
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteUser(int id) async {
    try {
      await _service.delete(id);
      _users = _users.where((u) => u.id != id).toList();
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
