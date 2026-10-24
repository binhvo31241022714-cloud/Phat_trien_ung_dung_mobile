import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/models/family_member.dart';
import '../data/models/health_info.dart';
import '../data/models/user_profile.dart';
import '../data/services/profile_service.dart';

/// Hồ sơ tài khoản và người thân lấy từ backend.
///
/// Tách riêng khỏi PatientDataProvider: đặt lịch và hồ sơ khám vẫn dùng dữ
/// liệu mock cho tới khi các module đó nối API.
class ProfileProvider extends ChangeNotifier {
  final ProfileService _service;

  ProfileProvider({ProfileService? service})
      : _service = service ?? ProfileService();

  // Tăng mỗi lần đăng xuất, để kết quả API của phiên cũ trả về muộn bị bỏ qua.
  int _session = 0;

  UserProfile? _profile;
  bool _profileLoading = false;
  String? _profileError;
  UserProfile? get profile => _profile;
  bool get profileLoading => _profileLoading;
  String? get profileError => _profileError;

  List<FamilyMember> _family = const [];
  bool _familyLoading = false;
  bool _familyLoaded = false;
  String? _familyError;
  List<FamilyMember> get family => _family;
  bool get familyLoading => _familyLoading;
  bool get familyLoaded => _familyLoaded;
  String? get familyError => _familyError;

  /// Tên hiển thị: họ tên từ API; đang tải thì "..."; chưa có thì dùng
  /// [fallback] (thường là email đăng nhập).
  String displayName(String fallback) {
    final name = _profile?.fullName ?? '';
    if (name.isNotEmpty) return name;
    if (_profile == null && _profileLoading) return '...';
    final email = _profile?.email ?? '';
    if (email.isNotEmpty) return email;
    return fallback.isNotEmpty ? fallback : 'bạn';
  }

  /// Tải hồ sơ nếu chưa có (gọi khi vào trang chính).
  Future<void> ensureLoaded() async {
    if (_profile == null && !_profileLoading) await loadProfile();
  }

  Future<void> loadProfile() async {
    final session = _session;
    _profileLoading = true;
    _profileError = null;
    notifyListeners();
    try {
      final result = await _service.getMe();
      if (session != _session) return;
      _profile = result;
    } on ApiException catch (e) {
      if (session != _session) return;
      _profileError = e.message;
    }
    _profileLoading = false;
    notifyListeners();
  }

  /// Trả về null nếu thành công, ngược lại trả về thông báo lỗi.
  Future<String?> saveProfile({
    required String fullName,
    required String phone,
    DateTime? birthday,
    String? gender,
    HealthInfo? health,
  }) async {
    final current = _profile;
    if (current == null) return 'Chưa tải được hồ sơ.';
    final newGender = gender ?? current.gender;
    // Đổi sang giới tính khác Nữ thì "đang mang thai" tự về false.
    final newHealth = (health ?? current.health).forGender(newGender);
    try {
      await _service.updateMe(
          fullName: fullName.trim(),
          phone: phone.trim(),
          birthday: birthday,
          gender: newGender,
          health: newHealth);
    } on ApiException catch (e) {
      return e.message;
    }
    _profile = UserProfile(
      id: current.id,
      email: current.email,
      fullName: fullName.trim(),
      phone: phone.trim(),
      birthday: birthday ?? current.birthday,
      gender: newGender,
      address: current.address,
      health: newHealth,
    );
    notifyListeners();
    return null;
  }

  Future<void> loadFamily() async {
    final session = _session;
    _familyLoading = true;
    _familyError = null;
    notifyListeners();
    try {
      final result = await _service.getFamily();
      if (session != _session) return;
      _family = List.unmodifiable(result);
      _familyLoaded = true;
    } on ApiException catch (e) {
      if (session != _session) return;
      _familyError = e.message;
    }
    _familyLoading = false;
    notifyListeners();
  }

  // Thêm, sửa, xóa xong thì tải lại danh sách để luôn khớp với máy chủ.
  Future<String?> addFamily(FamilyMember member) =>
      _mutate(() => _service.addFamily(member));
  Future<String?> updateFamily(FamilyMember member) =>
      _mutate(() => _service.updateFamily(member));
  Future<String?> deleteFamily(String id) =>
      _mutate(() => _service.deleteFamily(id));

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      return e.message;
    }
    await loadFamily();
    return null;
  }

  /// Gọi khi đăng xuất để người dùng sau không thấy dữ liệu người trước.
  void clear() {
    _session++;
    _profile = null;
    _profileLoading = false;
    _profileError = null;
    _family = const [];
    _familyLoading = false;
    _familyLoaded = false;
    _familyError = null;
    notifyListeners();
  }
}
