import 'health_info.dart';
import 'json_read.dart';

/// Người thân từ /api/family-members.
class FamilyMember {
  final String id;
  final String fullName;
  final String relationship;
  final DateTime? birthday;
  final String phone;
  final String gender;
  final HealthInfo health;

  /// Ảnh đại diện (media/{id}); null khi chưa có ảnh. Không gửi trong toJson.
  final String? avatarMediaId;

  const FamilyMember({
    required this.id,
    this.fullName = '',
    this.relationship = '',
    this.birthday,
    this.phone = '',
    this.gender = '',
    this.health = const HealthInfo(),
    this.avatarMediaId,
  });

  FamilyMember withAvatar(String? mediaId) => FamilyMember(
        id: id,
        fullName: fullName,
        relationship: relationship,
        birthday: birthday,
        phone: phone,
        gender: gender,
        health: health,
        avatarMediaId: mediaId,
      );

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: readString(json['id']),
        fullName: readString(json['fullName']),
        relationship: readString(json['relationship']),
        birthday: readDate(json['birthday']),
        phone: readString(json['phone']),
        gender: readGender(json['gender']),
        health: HealthInfo.fromJson(json),
        avatarMediaId: json['avatarMediaId'] is String &&
                (json['avatarMediaId'] as String).trim().isNotEmpty
            ? (json['avatarMediaId'] as String).trim()
            : null,
      );

  /// Body gửi cho POST và PATCH.
  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'relationship': relationship,
        'birthday': birthday == null ? '' : writeDate(birthday!),
        'phone': phone,
        'gender': gender,
        ...health.forGender(gender).toJson(),
      };
}
