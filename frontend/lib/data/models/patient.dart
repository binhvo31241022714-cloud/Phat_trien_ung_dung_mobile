class Patient {
  final String id;
  final String fullName;
  final String phone;
  final DateTime dateOfBirth;
  final String relationship;
  final bool isPrimary;
  final String? avatarAsset;

  const Patient({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.dateOfBirth,
    required this.relationship,
    this.isPrimary = false,
    this.avatarAsset,
  });
}
