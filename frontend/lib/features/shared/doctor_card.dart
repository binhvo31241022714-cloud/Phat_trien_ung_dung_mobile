import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/doctor.dart';

class DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback? onTap;

  const DoctorCard({
    required this.doctor,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.primaryDark,
            child: doctor.avatarAsset == null
                ? const Icon(Icons.person_outline_rounded, size: 30)
                : ClipOval(
                    child: Image.asset(
                      doctor.avatarAsset!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person_outline_rounded, size: 30),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.fullName,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  doctor.specialty,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _DoctorFact(
                      icon: Icons.star_rounded,
                      text: doctor.rating.toStringAsFixed(1),
                      color: AppColors.warning,
                    ),
                    _DoctorFact(
                      icon: Icons.work_outline_rounded,
                      text: '${doctor.experienceYears} năm kinh nghiệm',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorFact extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DoctorFact({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
