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

  /// Ảnh đại diện (media/{id}); null khi chưa có ảnh.
  final String? avatarMediaId;

  /// Công tắc "Nhận thông báo" lưu trên máy chủ: tắt thì không nhận nhắc lịch,
  /// nhắc tái khám. Dữ liệu cũ chưa có trường này là đang bật.
  final bool notificationsEnabled;

  const UserProfile({
    required this.id,
    this.email = '',
    this.fullName = '',
    this.phone = '',
    this.birthday,
    this.gender = '',
    this.address = '',
    this.health = const HealthInfo(),
    this.avatarMediaId,
    this.notificationsEnabled = true,
  });

  UserProfile withNotifications(bool enabled) => UserProfile(
        id: id,
        email: email,
        fullName: fullName,
        phone: phone,
        birthday: birthday,
        gender: gender,
        address: address,
        health: health,
        avatarMediaId: avatarMediaId,
        notificationsEnabled: enabled,
      );

  UserProfile withAvatar(String? mediaId) => UserProfile(
        id: id,
        email: email,
        fullName: fullName,
        phone: phone,
        birthday: birthday,
        gender: gender,
        address: address,
        health: health,
        avatarMediaId: mediaId,
        notificationsEnabled: notificationsEnabled,
      );

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
        avatarMediaId: _optionalId(json['avatarMediaId']),
        notificationsEnabled: json['notificationsEnabled'] != false,
      );
}

String? _optionalId(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
