import 'package:flutter/material.dart';

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
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? () => controller.toggleCatalogItem(service) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 14,
              horizontal: 12,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? const Color(0xFF247BF3) : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${service.isCombo ? 'Combo' : service.category}'
                        ' · ${service.durationMinutes} phút',
                        style: const TextStyle(
                          color: Color(0xFF666666),
                        ),
                      ),
                      Text(
                        formatVnd(service.price),
                        style: const TextStyle(
                          color: Color(0xFF247BF3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => onDetail(service),
                  child: const Text(
                    'Chi tiết',
                    style: TextStyle(color: Colors.black),
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
