class Doctor {
  final String id;
  final String fullName;
  final String specialty;
  final int experienceYears;
  final double rating;
  final int reviewCount;
  final String introduction;
  final String? avatarAsset;

  const Doctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.experienceYears,
    required this.rating,
    required this.reviewCount,
    required this.introduction,
    this.avatarAsset,
  });
}
