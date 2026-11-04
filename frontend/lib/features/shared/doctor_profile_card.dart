import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/network_image_or_icon.dart';
import '../../data/models/doctor.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/catalog_provider.dart';

/// Thẻ hồ sơ bác sĩ nền pastel, dùng ở Trang chủ (ngang) và Chi tiết bác sĩ
/// (dọc). Thông số chữ và nút lấy theo thẻ "Lịch hẹn" trên Trang chủ.
class DoctorProfileCard extends StatelessWidget {
  const DoctorProfileCard({
    required this.doctor,
    this.vertical = false,
    this.onTap,
    this.showSave = true,
    super.key,
  });

  final Doctor doctor;

  /// true: ảnh ở trên, thông tin xếp dọc bên dưới (trang chi tiết).
  final bool vertical;

  /// Mở chi tiết. null thì ẩn nút "Xem chi tiết" và thẻ không bấm được.
  final VoidCallback? onTap;
  final bool showSave;

  static final _radius = BorderRadius.circular(AppTokens.cardRadius);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          gradient: AppColors.doctorCardGradient,
          borderRadius: _radius,
          border: Border.all(color: Colors.white.withValues(alpha: .7)),
          boxShadow: const [AppTokens.cardShadow]),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: _radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: AppTokens.pageInsets,
            child: vertical ? _vertical() : _horizontal(),
          ),
        ),
      ),
    );
  }

  Widget _horizontal() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 104,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 150),
              child: _photo(iconSize: 64),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: showSave
                      ? SaveDoctorButton(doctor: doctor)
                      : const SizedBox(height: 48),
                ),
                const SizedBox(height: 4),
                ..._info(nameSize: 18, nameLines: 2),
                const Spacer(),
                if (onTap != null) ...[
                  const SizedBox(height: 14),
                  Align(
                      alignment: Alignment.centerRight, child: _detailButton()),
                ],
              ],
            ),
          ),
        ],
      );

  Widget _vertical() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(children: [
            SizedBox(height: 240, child: _photo(iconSize: 96)),
            if (showSave)
              Positioned(
                  top: 10, right: 10, child: SaveDoctorButton(doctor: doctor)),
          ]),
          const SizedBox(height: 16),
          ..._info(nameSize: 22, nameLines: 3),
          if (onTap != null) ...[
            const SizedBox(height: 14),
            Align(alignment: Alignment.centerRight, child: _detailButton()),
          ],
        ],
      );

  // Positioned.fill để ảnh không tham gia đo chiều cao thẻ.
  Widget _photo({required double iconSize}) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(children: [
            Positioned.fill(
              child: NetworkImageOrIcon(
                url: doctor.avatarUrl,
                alignment: Alignment.topCenter,
                icon: Icons.person_rounded,
                iconSize: iconSize,
                color: AppColors.primary.withValues(alpha: .45),
              ),
            ),
          ]),
        ),
      );

  List<Widget> _info({required double nameSize, required int nameLines}) => [
        Text(
          vertical ? doctor.fullName : doctor.fullName.replaceFirst('BS. ', ''),
          style: TextStyle(
            fontSize: nameSize,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          ),
          maxLines: nameLines,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          doctor.specialty,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (doctor.experienceYears > 0 || doctor.hasRating) ...[
          const SizedBox(height: 6),
          Text(
            [
              if (doctor.experienceYears > 0)
                '${doctor.experienceYears} năm kinh nghiệm',
              if (doctor.hasRating) '☆ ${doctor.rating}',
            ].join(' · '),
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ];

  Widget _detailButton() => ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: .6),
          foregroundColor: AppColors.primaryDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          minimumSize: const Size(0, 48),
        ),
        child: const Text(
          'Xem chi tiết',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

/// Nút "Lưu bác sĩ": bác sĩ từ API lưu qua /api/favorites, dữ liệu mock lưu
/// trong PatientDataProvider.
class SaveDoctorButton extends StatelessWidget {
  const SaveDoctorButton({required this.doctor, super.key});
  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final doctorId = doctor.id;
    // Bác sĩ lấy từ máy chủ luôn lưu qua API (như nút lưu cũ ở trang chi tiết).
    final isApi =
        doctor.fromApi || AppConfig.current.dataSource == DataSource.api;
    final catalog = isApi ? context.watch<CatalogProvider>() : null;
    final data = isApi ? null : context.watch<PatientDataProvider>();
    final saved = catalog?.isSaved('doctor', doctorId) ??
        data!.savedDoctorIds.contains(doctorId);
    final pending = catalog?.isPending('doctor', doctorId) ?? false;
    return ElevatedButton.icon(
      onPressed: pending
          ? null
          : () async {
              if (catalog == null) {
                data!.toggleSavedDoctor(doctorId);
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              final error = await catalog.toggleFavorite('doctor', doctorId);
              if (error != null) {
                messenger.showSnackBar(SnackBar(
                    content: Text(saved
                        ? 'Chưa bỏ lưu được: $error'
                        : 'Chưa lưu được: $error')));
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        disabledBackgroundColor: const Color(0xB3FFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        minimumSize: const Size(0, 48),
      ),
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, size: 16),
      label: Text(
        saved ? 'Đã lưu' : 'Lưu bác sĩ',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
