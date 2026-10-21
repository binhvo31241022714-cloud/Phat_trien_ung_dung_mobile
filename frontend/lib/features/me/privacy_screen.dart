import 'package:flutter/material.dart';
import 'me_widgets.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const MePage(title: 'Quyền riêng tư', children: [
        MeCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Dữ liệu trong bản demo',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text(
              'Thông tin cá nhân, người thân, lịch hẹn, hồ sơ nha khoa, thông báo và bookmark chỉ dùng để minh họa. Thay đổi được giữ trong bộ nhớ và có thể mất khi khởi động lại ứng dụng.'),
          SizedBox(height: 16),
          Text('Ai có thể xem hồ sơ?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text(
              'Người đang sử dụng phiên demo trên thiết bị có thể xem hồ sơ bản thân và người thân được thêm. Bản demo chưa có cơ chế phân quyền và bảo vệ hồ sơ trên máy chủ.'),
          SizedBox(height: 16),
          Text('Giới hạn kết nối',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text(
              'Chưa kết nối backend thật cho tài khoản, bệnh án, push notification, sinh trắc học hoặc tải ảnh. Không có chức năng thanh toán trực tuyến.'),
          SizedBox(height: 16),
          Text(
              'Không nhập dữ liệu y tế thật hoặc thông tin nhạy cảm vào bản demo khi chưa có cơ chế bảo vệ phù hợp.'),
        ]))
      ]);
}
