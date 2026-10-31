import '../core/state/session_notifier.dart';

import '../data/api_client.dart';
import '../data/models/family_member.dart';
import '../data/models/health_info.dart';
import '../data/models/user_profile.dart';
import '../core/media/media_cache.dart';
import '../core/media/photo_picker.dart';
import '../data/services/media_service.dart';
import '../data/services/profile_service.dart';

/// Hồ sơ tài khoản và người thân lấy từ backend.
///
/// Tách riêng khỏi PatientDataProvider: đặt lịch và hồ sơ khám vẫn dùng dữ
/// liệu mock cho tới khi các module đó nối API.
class ProfileProvider extends SessionNotifier {
  final ProfileService _service;
  final MediaService _media;

  ProfileProvider({ProfileService? service, MediaService? media})
      : _service = service ?? ProfileService(),
        _media = media ?? MediaService.shared;

  // Tăng mỗi lần đăng xuất, để kết quả API của phiên cũ trả về muộn bị bỏ qua.

  int _profileRequest = 0;
  int _familyRequest = 0;

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
    if (isDisposed) return;
    final session = sessionGeneration;
    final request = ++_profileRequest;
    bool current() => isSessionCurrent(session) && request == _profileRequest;
    _profileLoading = true;
    _profileError = null;
    notifyListeners();
    try {
      final result = await _service.getMe();
      if (!current()) return;
      _profile = result;
    } catch (e) {
      if (!current()) return;
      _profileError = e is ApiException ? e.message : 'Không thể tải hồ sơ.';
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
    if (isDisposed) return 'Phiên đăng nhập đã kết thúc.';
    final session = sessionGeneration;
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
    } catch (e) {
      return isSessionCurrent(session)
          ? (e is ApiException ? e.message : 'Không thể cập nhật hồ sơ.')
          : 'Phiên đăng nhập đã thay đổi.';
    }
    if (!isSessionCurrent(session)) return 'Phiên đăng nhập đã thay đổi.';
    _profile = UserProfile(
      id: current.id,
      email: current.email,
      fullName: fullName.trim(),
      phone: phone.trim(),
      birthday: birthday ?? current.birthday,
      gender: newGender,
      address: current.address,
      health: newHealth,
      avatarMediaId: current.avatarMediaId,
      notificationsEnabled: current.notificationsEnabled,
    );
    notifyListeners();
    return null;
  }

  bool _savingNotifications = false;
  bool get savingNotifications => _savingNotifications;

  /// Bật/tắt nhận thông báo nhắc lịch trên máy chủ. Đổi ngay trên giao diện,
  /// lỗi thì trả lại như cũ. Trả thông báo lỗi hoặc null.
  Future<String?> setNotificationsEnabled(bool enabled) async {
    final current = _profile;
    if (isDisposed || current == null) return 'Chưa tải được hồ sơ.';
    if (_savingNotifications) return null;
    final session = sessionGeneration;
    _savingNotifications = true;
    _profile = current.withNotifications(enabled);
    notifyListeners();
    try {
      await _service.updateNotifications(enabled);
      return null;
    } catch (e) {
      if (!isSessionCurrent(session)) return 'Phiên đăng nhập đã thay đổi.';
      _profile = (_profile ?? current).withNotifications(!enabled);
      return e is ApiException ? e.message : 'Không lưu được cài đặt thông báo.';
    } finally {
      if (isSessionCurrent(session)) {
        _savingNotifications = false;
        notifyListeners();
      }
    }
  }

  /// Thay ảnh đại diện của bản thân; [image] null là gỡ ảnh. Trả lỗi hoặc null.
  Future<String?> changeMyAvatar(PickedImage? image) async {
    final current = _profile;
    if (isDisposed || current == null) return 'Chưa tải được hồ sơ.';
    final session = sessionGeneration;
    try {
      final id = await _media.setMyAvatar(image);
      if (!isSessionCurrent(session)) return 'Phiên đăng nhập đã thay đổi.';
      MediaCache.evict(current.avatarMediaId);
      _profile = (_profile ?? current).withAvatar(id);
      notifyListeners();
      return null;
    } catch (e) {
      return isSessionCurrent(session)
          ? (e is ApiException ? e.message : 'Không thể cập nhật ảnh đại diện.')
          : 'Phiên đăng nhập đã thay đổi.';
    }
  }

  /// Thay ảnh đại diện người thân; [image] null là gỡ ảnh. Trả lỗi hoặc null.
  Future<String?> changeFamilyAvatar(String memberId, PickedImage? image) async {
    if (isDisposed) return 'Phiên đăng nhập đã kết thúc.';
    final session = sessionGeneration;
    try {
      final id = await _media.setFamilyAvatar(memberId, image);
      if (!isSessionCurrent(session)) return 'Phiên đăng nhập đã thay đổi.';
      MediaCache.evict(familyAvatar(memberId));
      _family = List.unmodifiable([
        for (final member in _family)
          member.id == memberId ? member.withAvatar(id) : member,
      ]);
      notifyListeners();
      return null;
    } catch (e) {
      return isSessionCurrent(session)
          ? (e is ApiException ? e.message : 'Không thể cập nhật ảnh đại diện.')
          : 'Phiên đăng nhập đã thay đổi.';
    }
  }

  String? familyAvatar(String memberId) =>
      _family.where((m) => m.id == memberId).firstOrNull?.avatarMediaId;

  Future<void> loadFamily() async {
    if (isDisposed) return;
    final session = sessionGeneration;
    final request = ++_familyRequest;
    bool current() => isSessionCurrent(session) && request == _familyRequest;
    _familyLoading = true;
    _familyError = null;
    notifyListeners();
    try {
      final result = await _service.getFamily();
      if (!current()) return;
      _family = List.unmodifiable(result);
      _familyLoaded = true;
    } catch (e) {
      if (!current()) return;
      _familyError =
          e is ApiException ? e.message : 'Không thể tải người thân.';
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
    if (isDisposed) return 'Phiên đăng nhập đã kết thúc.';
    final session = sessionGeneration;
    try {
      await action();
    } catch (e) {
      return isSessionCurrent(session)
          ? (e is ApiException ? e.message : 'Không thể cập nhật hồ sơ.')
          : 'Phiên đăng nhập đã thay đổi.';
    }
    if (!isSessionCurrent(session)) return 'Phiên đăng nhập đã thay đổi.';
    await loadFamily();
    return null;
  }

  /// Gọi khi đăng xuất để người dùng sau không thấy dữ liệu người trước.
  void clear() {
    invalidateSession();
    MediaCache.clear();
    _savingNotifications = false;
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
