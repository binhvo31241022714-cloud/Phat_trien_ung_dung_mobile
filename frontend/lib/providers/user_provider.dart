import 'package:flutter/foundation.dart';

import '../data/models/user_model.dart';
import '../data/mock_data.dart';
import '../data/services/user_service.dart';

/// Quản lý state danh sách user cho UI.
class UserProvider extends ChangeNotifier {
  final UserService _service;

  UserProvider({UserService? service}) : _service = service ?? UserService();

  // The existing demo login uses one patient account. No password is retained.
  UserModel _account = UserModel(
    id: 1,
    name: MockData.patients.firstWhere((p) => p.isPrimary).fullName,
    email: '',
    phone: MockData.patients.firstWhere((p) => p.isPrimary).phone,
    dateOfBirth: MockData.patients.firstWhere((p) => p.isPrimary).dateOfBirth,
    createdAt: DateTime.now(),
  );
  bool _authenticated = false;
  UserModel get account => _account;
  UserModel? get currentUser => _authenticated ? _account : null;
  bool get isAuthenticated => _authenticated;
  bool _receiveNotifications = true;
  bool _biometricDemo = false;
  bool get receiveNotifications => _receiveNotifications;
  bool get biometricDemo => _biometricDemo;
  void setReceiveNotifications(bool value) {
    _receiveNotifications = value;
    notifyListeners();
  }

  void setBiometricDemo(bool value) {
    _biometricDemo = value;
    notifyListeners();
  }

  void signInDemo(String email) {
    _account = UserModel(
        id: _account.id,
        name: _account.name,
        email: email.trim(),
        phone: _account.phone,
        dateOfBirth: _account.dateOfBirth,
        createdAt: _account.createdAt);
    _authenticated = true;
    notifyListeners();
  }

  void signOutDemo() {
    _authenticated = false;
    notifyListeners();
  }

  void updateDemoAccount(
      {required String name,
      required String email,
      required String phone,
      required DateTime dateOfBirth}) {
    _account = UserModel(
        id: _account.id,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        dateOfBirth: dateOfBirth,
        createdAt: _account.createdAt);
    notifyListeners();
  }

  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    _service.close();
    super.dispose();
  }

  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUsers() async {
    if (_disposed || _isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.getAll();
      if (!_disposed) _users = result;
    } catch (e) {
      if (!_disposed) {
        _users = [];
        _error = e.toString();
      }
    } finally {
      _isLoading = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Trả về null nếu thành công, ngược lại trả về thông báo lỗi.
  Future<String?> saveUser(
      {int? id, required String name, required String email}) async {
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
