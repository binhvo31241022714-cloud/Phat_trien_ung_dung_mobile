import 'json_read.dart';

class Doctor {
  final String id;
  final String fullName;
  final String specialty;
  final int experienceYears;
  final double rating;
  final int reviewCount;
  final String introduction;
  final String? avatarAsset;

  /// Ảnh từ API; rỗng thì giao diện hiện icon mặc định.
  final String avatarUrl;
  final List<String> serviceIds;

  /// true khi lấy từ backend; false với dữ liệu mock (đặt lịch vẫn dùng mock).
  final bool fromApi;

  const Doctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.experienceYears,
    required this.rating,
    required this.reviewCount,
    required this.introduction,
    this.avatarAsset,
    this.avatarUrl = '',
    this.serviceIds = const [],
    this.fromApi = false,
  });

  /// Đọc từ /api/doctors. Backend chưa có đánh giá và giới thiệu nên để
  /// 0 và rỗng; giao diện sẽ ẩn các phần đó.
  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: readString(json['id']),
        fullName: readString(json['name']),
        specialty: readString(json['specialty']),
        experienceYears: readInt(json['experienceYears']),
        rating: 0,
        reviewCount: 0,
        introduction: readString(json['introduction']),
        avatarUrl: readString(json['avatarUrl']),
        serviceIds: readStringList(json['serviceIds']),
        fromApi: true,
      );

  bool get hasRating => rating > 0;
}
