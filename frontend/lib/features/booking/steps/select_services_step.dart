import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/dental_service.dart';
import '../booking_controller.dart';

class SelectServicesStep extends StatelessWidget {
  const SelectServicesStep(
      {required this.controller, required this.onDetail, super.key});
  final BookingController controller;
  final ValueChanged<DentalService> onDetail;
  @override
  Widget build(BuildContext context) => Column(children: [
        const Text(
            'Chọn một hoặc nhiều dịch vụ. Combo nằm chung trong danh sách.',
            style: TextStyle(color: Color(0xFF666666))),
        const SizedBox(height: 12),
        if (controller.data.services.isEmpty)
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Chưa có dịch vụ để đặt lịch.')),
        for (final s in controller.data.services)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                  child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => controller.toggleService(s.id),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 12),
                    child: Row(children: [
                      Icon(
                          controller.serviceIds.contains(s.id)
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: controller.serviceIds.contains(s.id)
                              ? const Color(0xFF247BF3)
                              : Colors.grey,
                          size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(s.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${s.isCombo ? 'Combo' : s.category} · ${s.durationMinutes} phút',
                                style:
                                    const TextStyle(color: Color(0xFF666666))),
                            Text(formatVnd(s.price),
                                style: const TextStyle(
                                    color: Color(0xFF247BF3),
                                    fontWeight: FontWeight.w600)),
                          ])),
                      TextButton(
                          onPressed: () => onDetail(s),
                          child: const Text('Chi tiết',
                              style: TextStyle(color: Colors.black))),
                    ])),
              ))),
      ]);
}
