import 'package:flutter/material.dart';

import 'json_read.dart';

class DentalService {
  final String id;
  final String name;
  final String description;
  final int price;
  final int durationMinutes;
  final IconData icon;
  final String category;
  final bool isCombo;
  final bool isPopular;

  /// Ảnh từ API; rỗng thì giao diện hiện [icon].
  final String imageUrl;

  /// Combo: id các dịch vụ bên trong.
  final List<String> serviceIds;

  /// true khi lấy từ backend; false với dữ liệu mock (đặt lịch vẫn dùng mock).
  final bool fromApi;

  const DentalService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.icon,
    required this.category,
    this.isCombo = false,
    this.isPopular = false,
    this.imageUrl = '',
    this.serviceIds = const [],
    this.fromApi = false,
  });

  /// Đọc từ /api/services hoặc /api/combos (đặt [isCombo] = true cho combo).
  /// Chịu được trường thiếu hoặc null.
  factory DentalService.fromJson(Map<String, dynamic> json,
          {bool isCombo = false}) =>
      DentalService(
        id: readString(json['id']),
        name: readString(json['name']),
        description: readString(json['description']),
        price: readInt(json['price']),
        durationMinutes: readInt(json['durationMinutes']),
        icon: isCombo
            ? Icons.auto_awesome_outlined
            : Icons.medical_services_outlined,
        category: isCombo ? 'Combo' : 'Dịch vụ nha khoa',
        isCombo: isCombo,
        imageUrl: readString(json['imageUrl']),
        serviceIds: readStringList(json['serviceIds']),
        fromApi: true,
      );

  /// Loại dùng cho /api/favorites.
  String get favoriteType => isCombo ? 'combo' : 'service';
}
