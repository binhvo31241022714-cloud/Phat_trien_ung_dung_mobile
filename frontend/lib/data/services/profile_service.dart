import '../api_client.dart';
import '../models/family_member.dart';
import '../models/user_profile.dart';

/// Gọi /api/users/me và /api/family-members. Lỗi ném ra [ApiException].
class ProfileService {
  final ApiClient _api;

  /// Test truyền ApiClient giả; app dùng biến [api] dùng chung.
  ProfileService({ApiClient? client}) : _api = client ?? api;

  static const _me = '/api/users/me';
  static const _family = '/api/family-members';

  Future<UserProfile> getMe() async {
    final data = await _api.get(_me);
    if (data is! Map<String, dynamic>) throw _invalid;
    return UserProfile.fromJson(data);
  }

  Future<void> updateMe({
    required String fullName,
    required String phone,
    DateTime? birthday,
  }) =>
      _api.patch(_me, {
        'fullName': fullName,
        'phone': phone,
        if (birthday != null) 'birthday': writeDate(birthday),
      });

  Future<List<FamilyMember>> getFamily() async {
    final data = await _api.get(_family);
    if (data is! List) throw _invalid;
    return [
      for (final row in data)
        if (row is Map<String, dynamic>) FamilyMember.fromJson(row),
    ];
  }

  Future<void> addFamily(FamilyMember member) =>
      _api.post(_family, member.toJson());

  Future<void> updateFamily(FamilyMember member) =>
      _api.patch('$_family/${member.id}', member.toJson());

  Future<void> deleteFamily(String id) => _api.delete('$_family/$id');

  static const _invalid =
      ApiException('Dữ liệu máy chủ trả về không đúng định dạng.');
}
