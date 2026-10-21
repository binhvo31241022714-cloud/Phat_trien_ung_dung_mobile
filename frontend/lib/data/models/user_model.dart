class UserModel {
  final int id;
  final String name;
  final String email;
  final DateTime createdAt;
  final String phone;
  final DateTime? dateOfBirth;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.createdAt,
    this.phone = '',
    this.dateOfBirth,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final email = json['email'];
    final rawDate = json['createdAt'];
    final createdAt = rawDate is String ? DateTime.tryParse(rawDate) : null;
    if (id is! int ||
        name is! String ||
        name.trim().isEmpty ||
        email is! String ||
        createdAt == null) {
      throw const FormatException('Invalid user contract');
    }
    // Backend currently emits local ISO without offset. Preserve its semantics;
    // do not silently label that timestamp as UTC.
    return UserModel(id: id, name: name, email: email, createdAt: createdAt);
  }
}
