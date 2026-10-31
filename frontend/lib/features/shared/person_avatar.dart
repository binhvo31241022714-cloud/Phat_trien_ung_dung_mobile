import 'package:flutter/material.dart';

import 'media_image.dart';

/// Ảnh đại diện tròn của người khám: có [mediaId] thì hiện ảnh trên backend,
/// không có (hoặc tải lỗi) thì hiện biểu tượng [icon].
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.mediaId,
    this.radius = 20,
    this.icon = Icons.person_outline,
    this.iconColor = const Color(0xFF247BF3),
    this.background = const Color(0xFFDFE8F6),
    super.key,
  });

  final String? mediaId;
  final double radius;
  final IconData icon;
  final Color iconColor;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(icon, color: iconColor, size: radius);
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: mediaId == null
          ? fallback
          : ClipOval(
              child: SizedBox.square(
                dimension: radius * 2,
                child: MediaImage(mediaId!,
                    key: ValueKey('person-avatar-$mediaId'),
                    error: Center(child: fallback)),
              ),
            ),
    );
  }
}

/// Một dòng trong ô chọn người khám (Hồ sơ, Đặt lịch): ảnh đại diện và tên.
class PatientOptionLabel extends StatelessWidget {
  const PatientOptionLabel(this.label, {required this.avatarMediaId, super.key});
  final String label;
  final String? avatarMediaId;

  @override
  Widget build(BuildContext context) => Row(children: [
        PersonAvatar(mediaId: avatarMediaId, radius: 12),
        const SizedBox(width: 8),
        Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      ]);
}
