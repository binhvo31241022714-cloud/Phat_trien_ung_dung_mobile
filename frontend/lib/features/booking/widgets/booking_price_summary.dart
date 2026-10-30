import 'package:flutter/material.dart';
import '../../../core/utils/formatters.dart';
import '../booking_controller.dart';

class BookingPriceSummary extends StatelessWidget {
  const BookingPriceSummary(
      {required this.controller,
      required this.onNext,
      this.onReselect,
      super.key});
  final BookingController controller;
  final VoidCallback onNext;

  /// Nút "Chọn lại" khi đang khóa sau lỗi mạng.
  final VoidCallback? onReselect;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (controller.step != 3 && controller.quoteError != null) ...[
            Text(controller.quoteError!),
            TextButton(
                onPressed:
                    controller.quoteLoading ? null : controller.refreshQuote,
                child: const Text('Thử lại báo giá')),
          ],
          Text('${controller.serviceIds.length} dịch vụ đã chọn',
              style: const TextStyle(color: Color(0xFF666666))),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                    controller.quoteReady
                        ? formatVnd(controller.total)
                        : controller.quoteLoading
                            ? 'Đang tải giá…'
                            : 'Chưa có giá',
                    style: const TextStyle(
                        color: Color(0xFF247BF3),
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (controller.awaitingRetry)
                        TextButton(
                            onPressed:
                                controller.submitting ? null : onReselect,
                            child: const Text('Chọn lại'))
                      else if (controller.step > 0)
                        TextButton(
                            onPressed:
                                controller.locked ? null : controller.back,
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
                              : Text(controller.awaitingRetry
                                  ? 'Thử lại'
                                  : controller.step == 3
                                      ? 'Xác nhận đặt lịch →'
                                      : 'Tiếp theo →')),
                    ]),
              ]),
        ]),
      ));
}
