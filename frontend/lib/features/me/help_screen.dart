import 'package:flutter/material.dart';
import 'me_widgets.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => MePage(title: 'Trợ giúp', children: [
        for (final entry in const {
          'Làm thế nào để đặt lịch?':
              'Vào tab Đặt lịch, chọn người khám, dịch vụ, bác sĩ, ngày giờ và xác nhận.',
          'Có thể đặt nhiều dịch vụ không?':
              'Có. Bạn có thể tích nhiều dịch vụ trong cùng một yêu cầu đặt lịch.',
          'Có thể đặt cho người thân không?':
              'Có. Thêm người thân tại trang Tôi, sau đó chọn người khám phía trên các bước đặt lịch.',
          'Xem kết quả điều trị ở đâu?':
              'Vào Hồ sơ → Lịch sử khám hoặc Liệu trình điều trị.',
        }.entries)
          MeCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(entry.key,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 10),
                Text(entry.value,
                    style: const TextStyle(color: Color(0xFF666666)))
              ])),
      ]);
}
