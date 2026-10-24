import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/network_image_or_icon.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/dental_service.dart';

class ServiceCard extends StatelessWidget {
  final DentalService service;
  final VoidCallback? onTap;

  const ServiceCard({
    required this.service,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: NetworkImageOrIcon(
              url: service.imageUrl,
              icon: service.icon,
              color: AppColors.primary,
              width: 48,
              height: 48,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      service.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (service.isCombo)
                      const StatusChip(label: 'Combo', tone: StatusTone.info),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  service.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      formatVnd(service.price),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${service.durationMinutes} phút',
                      style: Theme.of(context).textTheme.bodySmall,
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
