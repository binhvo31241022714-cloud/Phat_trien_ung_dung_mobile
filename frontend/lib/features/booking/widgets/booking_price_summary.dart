import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../booking_controller.dart';

class BookingPriceSummary extends StatelessWidget {
  const BookingPriceSummary(
      {required this.controller, required this.onNext, super.key});
  final BookingController controller;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${controller.serviceIds.length} dịch vụ đã chọn',
              style: const TextStyle(color: Color(0xFF666666))),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(formatVnd(controller.total),
                    style: const TextStyle(
                        color: Color(0xFF247BF3),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (controller.step > 0)
                        TextButton(
                            onPressed:
                                controller.submitting ? null : controller.back,
                            child: const Text('Quay lại')),
                      FilledButton(
                          onPressed:
                              controller.canContinue && !controller.submitting
                                  ? onNext
                                  : null,
                          style: FilledButton.styleFrom(
                              backgroundColor: Colors.black,
                              minimumSize: const Size(0, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14)),
                          child: controller.submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(controller.step == 3
                                  ? 'Xác nhận đặt lịch →'
                                  : 'Tiếp theo →')),
                    ]),
              ]),
        ]),
      ));
}
