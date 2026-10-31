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
          Text('Tài khoản của bạn',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text(
              'Đăng nhập được quản lý bằng Firebase Authentication của Google. Ứng dụng không lưu mật khẩu của bạn.'),
          SizedBox(height: 16),
          Text('Ai có thể xem hồ sơ?',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text(
              'Thông tin cá nhân, người thân và nội dung đã lưu được lưu trên máy chủ. Dữ liệu chỉ truy cập được qua máy chủ của ứng dụng, và chỉ chủ tài khoản mới xem, sửa được thông tin của mình.'),
          SizedBox(height: 10),
          Text(
              'Thông tin sức khỏe chỉ dùng để bác sĩ chuẩn bị điều trị an toàn, chỉ chủ tài khoản xem được.'),
          SizedBox(height: 10),
          Text(
              'Ảnh đại diện và ảnh trước, sau điều trị được lưu trên máy chủ, chỉ chủ tài khoản và nhân viên phòng khám xem được.'),
          SizedBox(height: 16),
          Text('Đang được hoàn thiện',
              style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 10),
          Text(
              'Lịch hẹn, hồ sơ nha khoa, thông báo và bài viết hiện là dữ liệu minh họa, chưa phải dữ liệu thật của bạn. Ứng dụng chưa hỗ trợ thanh toán trực tuyến.'),
          SizedBox(height: 16),
          Text(
              'Vui lòng chưa nhập thông tin bệnh án thật cho tới khi các phần trên hoàn thiện.'),
        ]))
      ]);
}
