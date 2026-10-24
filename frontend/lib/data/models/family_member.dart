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

  const FamilyMember({
    required this.id,
    this.fullName = '',
    this.relationship = '',
    this.birthday,
    this.phone = '',
    this.gender = '',
    this.health = const HealthInfo(),
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: readString(json['id']),
        fullName: readString(json['fullName']),
        relationship: readString(json['relationship']),
        birthday: readDate(json['birthday']),
        phone: readString(json['phone']),
        gender: readGender(json['gender']),
        health: HealthInfo.fromJson(json),
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
