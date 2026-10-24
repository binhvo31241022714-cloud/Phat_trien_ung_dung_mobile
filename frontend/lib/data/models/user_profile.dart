import 'health_info.dart';
import 'json_read.dart';

export 'json_read.dart' show writeDate;

/// Hồ sơ tài khoản từ GET /api/users/me.
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final DateTime? birthday;
  final String gender;
  final String address;
  final HealthInfo health;

  const UserProfile({
    required this.id,
    this.email = '',
    this.fullName = '',
    this.phone = '',
    this.birthday,
    this.gender = '',
    this.address = '',
    this.health = const HealthInfo(),
  });

  /// Chịu được trường thiếu hoặc null: chuỗi thiếu thành '', ngày sai thành null.
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: readString(json['id']),
        email: readString(json['email']),
        fullName: readString(json['fullName']),
        phone: readString(json['phone']),
        birthday: readDate(json['birthday']),
        gender: readGender(json['gender']),
        address: readString(json['address']),
        health: HealthInfo.fromJson(json),
      );
}
