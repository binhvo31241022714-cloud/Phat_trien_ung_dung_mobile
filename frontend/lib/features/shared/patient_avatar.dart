import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/patient.dart';

class PatientAvatar extends StatelessWidget {
  final Patient patient;
  final double radius;

  const PatientAvatar({
    required this.patient,
    this.radius = 24,
    super.key,
  });

  String get _initials {
    final parts = patient.fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final image = patient.avatarAsset;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent,
      foregroundColor: AppColors.primaryDark,
      child: image == null
          ? Text(_initials)
          : ClipOval(
              child: SizedBox.square(
                dimension: radius * 2,
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(_initials),
                  ),
                ),
              ),
            ),
    );
  }
}
