/// Hồ sơ tài khoản từ GET /api/users/me.
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final DateTime? birthday;
  final String gender;
  final String address;

  const UserProfile({
    required this.id,
    this.email = '',
    this.fullName = '',
    this.phone = '',
    this.birthday,
    this.gender = '',
    this.address = '',
  });

  /// Chịu được trường thiếu hoặc null: chuỗi thiếu thành '', ngày sai thành null.
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: readString(json['id']),
        email: readString(json['email']),
        fullName: readString(json['fullName']),
        phone: readString(json['phone']),
        birthday: readDate(json['birthday']),
        gender: readString(json['gender']),
        address: readString(json['address']),
      );
}

String readString(Object? value) => value is String ? value.trim() : '';

/// Đọc ngày dạng "2000-05-31" (hoặc ISO đầy đủ). Rỗng hoặc sai thì trả null.
DateTime? readDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final date = DateTime.tryParse(value.trim());
  return date == null ? null : DateTime(date.year, date.month, date.day);
}

/// Ghi ngày gửi lên backend dạng "2000-05-31".
String writeDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
