import 'package:flutter/foundation.dart';

import 'dart:async';

import '../data/api_client.dart';
import '../data/models/user_model.dart';
import '../data/mock_data.dart';
import '../data/services/auth_service.dart';
import '../data/services/settings_store.dart';
import '../data/services/user_service.dart';

/// Quản lý state danh sách user cho UI.
class UserProvider extends ChangeNotifier {
  final UserService _service;
  final AuthService _auth;
  final SettingsStore _settings;

  /// App truyền [SharedPrefsSettingsStore] để lưu tùy chọn xuống máy;
  /// mặc định (dùng trong test) chỉ lưu trong bộ nhớ.
  UserProvider(
      {UserService? service, AuthService? auth, SettingsStore? settings})
      : _service = service ?? UserService(),
        _auth = auth ?? FirebaseAuthService(),
        _settings = settings ?? MemorySettingsStore();

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
  // ===== Tùy chọn lưu trên máy =====
  static const _keyNotifications = 'settings.receiveNotifications';
  static const _keyLanguage = 'settings.languageCode';

  /// Ngôn ngữ app hỗ trợ. Hiện chỉ có tiếng Việt.
  static const supportedLanguages = {'vi': 'Tiếng Việt'};

  bool _receiveNotifications = true;
  String _languageCode = 'vi';
  bool get receiveNotifications => _receiveNotifications;
  String get languageCode => _languageCode;
  String get languageName => supportedLanguages[_languageCode]!;

  /// Đọc tùy chọn đã lưu (gọi khi khởi động app).
  Future<void> loadSettings() async {
    _receiveNotifications = await _settings.getBool(_keyNotifications) ?? true;
    final language = await _settings.getString(_keyLanguage);
    // Mã ngôn ngữ lạ (ví dụ từ bản cũ) thì quay về tiếng Việt.
    _languageCode = supportedLanguages.containsKey(language) ? language! : 'vi';
    notifyListeners();
  }

  void setReceiveNotifications(bool value) {
    _receiveNotifications = value;
    notifyListeners();
    unawaited(_settings.setBool(_keyNotifications, value));
  }

  void setLanguage(String code) {
    if (!supportedLanguages.containsKey(code)) return;
    _languageCode = code;
    notifyListeners();
    unawaited(_settings.setString(_keyLanguage, code));
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

  // ===== Đăng nhập thật bằng Firebase =====
  // Các hàm trả về null nếu thành công, ngược lại trả về thông báo lỗi.

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signIn(email, password);
    } on AuthException catch (e) {
      return e.message;
    }
    signInDemo(email);
    return null;
  }

  Future<String?> register(
      String fullName, String email, String password) async {
    try {
      await _auth.register(fullName, email, password);
    } on AuthException catch (e) {
      return e.message;
    }
    signInDemo(email);
    return null;
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordReset(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<String?> changePassword(
      String currentPassword, String newPassword) async {
    try {
      await _auth.changePassword(currentPassword, newPassword);
      return null;
    } on AuthException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    signOutDemo();
  }

  /// Gọi /api/users/sync. Trả về null nếu thành công, ngược lại trả về
  /// cảnh báo. Lỗi sync không chặn đăng nhập vì lần đăng nhập sau sẽ sync lại.
  Future<String?> syncProfile({String? fullName}) async {
    try {
      await _auth.syncProfile(fullName: fullName);
      return null;
    } on ApiException catch (e) {
      return 'Đã đăng nhập nhưng chưa đồng bộ được hồ sơ: ${e.message}';
    }
  }

  /// Gọi khi mở app: nếu Firebase còn nhớ phiên thì đánh dấu đã đăng nhập
  /// và sync lại ở nền (không bắt người dùng chờ mạng).
  Future<void> restoreSession() async {
    final email = await _auth.restoreEmail();
    if (email == null) return;
    signInDemo(email);
    unawaited(syncProfile().then((warning) {
      if (warning != null) debugPrint(warning);
    }));
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
