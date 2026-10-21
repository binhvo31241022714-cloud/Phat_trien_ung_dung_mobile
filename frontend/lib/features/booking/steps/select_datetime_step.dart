import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../booking_controller.dart';

class SelectDatetimeStep extends StatelessWidget {
  const SelectDatetimeStep({required this.controller, super.key});
  final BookingController controller;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedButton(
                onPressed: () async {
                  final now = controller.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final date = await showDatePicker(
                      context: context,
                      initialDate: controller.date != null &&
                              !controller.date!.isBefore(today)
                          ? controller.date!
                          : today,
                      firstDate: today,
                      lastDate:
                          DateTime(today.year + 2, today.month, today.day));
                  if (date != null) controller.chooseDate(date);
                },
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(controller.date == null
                          ? 'Chọn ngày khám'
                          : '${formatVietnameseDate(controller.date!).substring(0, 6)}${(controller.date!.year % 100).toString().padLeft(2, '0')}')),
                  const Icon(Icons.expand_more)
                ])),
            const Divider(height: 32),
            const Text('Khung giờ 30 phút',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            LayoutBuilder(
                builder: (context, constraints) =>
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final slot in BookingController.slots)
                        SizedBox(
                            width: (constraints.maxWidth - 24) / 4,
                            child: OutlinedButton(
                                onPressed: controller.validSlot(slot)
                                    ? () => controller.chooseTime(slot)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 32),
                                    padding: EdgeInsets.zero,
                                    backgroundColor: controller.time == slot
                                        ? Colors.black
                                        : Colors.transparent,
                                    foregroundColor: controller.time == slot
                                        ? Colors.white
                                        : Colors.black,
                                    side: const BorderSide(
                                        color: Color(0xFFD1D1D1))),
                                child: Text(slot))),
                    ])),
            const SizedBox(height: 12),
            const Text(
                'Giờ trống đang mô phỏng, chưa được xác nhận bởi phòng khám.',
                style: TextStyle(color: Color(0xFF666666))),
          ])));
}
