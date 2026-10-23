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
            value: 'Tiếng Việt'),
        const Divider(height: 1),
        MeMenuTile('Đổi mật khẩu', Icons.lock_outline,
            () => MeRoutes.open(context, MeRoutes.password)),
        const Divider(height: 1),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.black,
            title: const Text('Nhận thông báo'),
            value: users.receiveNotifications,
            onChanged: (v) => users.setReceiveNotifications(v ?? false)),
        const Divider(height: 1),
        CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.black,
            title: const Text('Đăng nhập sinh trắc học (mô phỏng)'),
            value: users.biometricDemo,
            onChanged: (v) {
              users.setBiometricDemo(v ?? false);
              meMessage(context,
                  'Chỉ lưu tùy chọn mô phỏng; chưa sử dụng Face ID hay vân tay thật.');
            }),
      ])),
      MeCard(
          child: MeMenuTile('Quyền riêng tư', Icons.verified_user_outlined,
              () => MeRoutes.open(context, MeRoutes.privacy))),
      const Text('Các tùy chọn chỉ được lưu trong bộ nhớ của bản demo.',
          style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
    ]);
  }
}
