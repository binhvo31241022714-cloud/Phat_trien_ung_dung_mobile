import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';
import 'me_widgets.dart';

/// Mô tả công tắc ở chế độ API (lưu trên máy chủ).
const notificationsSettingDescription =
    'Nhắc lịch hẹn trước 24 giờ và nhắc tái khám trước 3 ngày, hiện trong mục Thông báo. '
    'Thông báo đặt lịch, xác nhận, hủy và kết quả khám luôn được gửi. '
    'Ứng dụng chưa gửi thông báo đẩy ra ngoài màn hình.';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>();
    final api = AppConfig.current.dataSource == DataSource.api;
    final profile = api ? context.watch<ProfileProvider>() : null;
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
            subtitle: Text(
                api
                    ? notificationsSettingDescription
                    : 'Chỉ là tùy chọn lưu trên máy này. Ứng dụng chưa gửi thông báo đẩy.',
                style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
            value: api
                ? profile!.profile?.notificationsEnabled ?? true
                : users.receiveNotifications,
            onChanged: !api
                ? (v) => users.setReceiveNotifications(v ?? false)
                : profile!.profile == null || profile.savingNotifications
                    ? null
                    : (v) async {
                        final error =
                            await profile.setNotificationsEnabled(v ?? false);
                        if (error != null && context.mounted) {
                          meMessage(context,
                              'Chưa lưu được cài đặt thông báo: $error');
                        }
                      }),
      ])),
      MeCard(
          child: MeMenuTile('Quyền riêng tư', Icons.verified_user_outlined,
              () => MeRoutes.open(context, MeRoutes.privacy))),
      Text(
          api
              ? 'Ngôn ngữ là tùy chọn lưu trên máy này. Tài khoản, hồ sơ và tùy chọn nhận thông báo được lưu trên máy chủ.'
              : 'Ngôn ngữ và nhận thông báo là tùy chọn lưu trên máy này. Tài khoản và hồ sơ của bạn được lưu trên máy chủ.',
          style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
    ]);
  }
}
