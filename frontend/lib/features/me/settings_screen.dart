import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'me_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>();
    return MePage(title: 'Cài đặt', children: [
      MeCard(
          child: Column(children: [
        MeMenuTile('Ngôn ngữ', Icons.translate,
            () => MeRoutes.open(context, MeRoutes.language),
            value: users.languageName),
        const Divider(height: 1),
        MeMenuTile('Đổi mật khẩu', Icons.lock_outline,
            () => MeRoutes.open(context, MeRoutes.password)),
        const Divider(height: 1),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.black,
            title: const Text('Nhận thông báo'),
            subtitle: const Text(
                'Chỉ là tùy chọn lưu trên máy này. Ứng dụng chưa gửi thông báo đẩy.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
            value: users.receiveNotifications,
            onChanged: (v) => users.setReceiveNotifications(v ?? false)),
      ])),
      MeCard(
          child: MeMenuTile('Quyền riêng tư', Icons.verified_user_outlined,
              () => MeRoutes.open(context, MeRoutes.privacy))),
      const Text(
          'Ngôn ngữ và nhận thông báo là tùy chọn lưu trên máy này. Tài khoản và hồ sơ của bạn được lưu trên máy chủ.',
          style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
    ]);
  }
}
