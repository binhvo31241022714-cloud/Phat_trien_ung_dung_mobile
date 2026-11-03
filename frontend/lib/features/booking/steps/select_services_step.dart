import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/dental_service.dart';
import '../booking_controller.dart';

class SelectServicesStep extends StatelessWidget {
  const SelectServicesStep({
    required this.controller,
    required this.onDetail,
    super.key,
  });

  final BookingController controller;
  final ValueChanged<DentalService> onDetail;

  @override
  Widget build(BuildContext context) {
    final catalog = controller.catalog;
    final services = controller.restrictToServiceIds
        ? controller.services.where(controller.isSelected).toList()
        : controller.services;
    final canSelect = !controller.submitting && controller.created == null;

    return Column(
      children: [
        const Text(
          'Chọn một hoặc nhiều dịch vụ. Combo nằm chung trong danh sách.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        const SizedBox(height: 12),

        // Đang tải dữ liệu từ API.
        if (catalog != null && !catalog.loaded) ...[
          if (catalog.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Đang tải dịch vụ...'),
                ],
              ),
            )
          else if (catalog.error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 36,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    catalog.error!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: catalog.loading ? null : () => catalog.load(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
        ] else if (services.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chưa có dịch vụ để đặt lịch.'),
          )
        else
          for (final service in services)
            _serviceCard(
              service,
              selected: controller.isSelected(service),
              enabled: canSelect,
            ),
      ],
    );
  }

  Widget _serviceCard(
    DentalService service, {
    required bool selected,
    required bool enabled,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: selected
            ? AppColors.glassPurpleStrong
            : Colors.white.withValues(alpha: 0.92),
        elevation: selected ? 2 : 1.5,
        shadowColor: const Color(0x18000675),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.primary : Colors.white,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? () => controller.toggleCatalogItem(service) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 9,
              horizontal: 11,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () => onDetail(service),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Chi tiết',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${service.isCombo ? 'Combo' : service.category}'
                            ' · ${service.durationMinutes} phút',
                            style: const TextStyle(
                                fontSize: 11.5, color: Color(0xFF666666)),
                          ),
                          const Spacer(),
                          Text(
                            formatVnd(service.price),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
