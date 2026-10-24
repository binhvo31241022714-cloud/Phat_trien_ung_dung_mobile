import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/empty_view.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_view.dart';
import '../../core/widgets/secondary_button.dart';
import '../../providers/profile_provider.dart';
import '../../providers/user_provider.dart';
import 'health_info_section.dart';
import 'me_widgets.dart';

class FamilyListScreen extends StatefulWidget {
  const FamilyListScreen({super.key});
  @override
  State<FamilyListScreen> createState() => _FamilyListScreenState();
}

class _FamilyListScreenState extends State<FamilyListScreen> {
  @override
  void initState() {
    super.initState();
    // Mỗi lần mở màn hình thì tải lại để khớp với máy chủ.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProfileProvider>().loadFamily();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final email = context.watch<UserProvider>().account.email;
    final birthday = profile.profile?.birthday;
    return MePage(title: 'Quản lý người thân', children: [
      // Bản thân luôn ở đầu, bấm Sửa mở màn hình thông tin cá nhân.
      _row(context,
          name: profile.displayName(email),
          subtitle: 'Bản thân · ${_date(birthday)}',
          healthWarning: profile.profile?.health.hasWarning ?? false,
          onEdit: () => MeRoutes.open(context, MeRoutes.profile)),
      if (profile.familyLoading && !profile.familyLoaded)
        const Padding(padding: EdgeInsets.all(24), child: LoadingView())
      else if (profile.familyError != null && !profile.familyLoading)
        ErrorState(message: profile.familyError!, onRetry: profile.loadFamily)
      else if (profile.family.isEmpty)
        const EmptyState(
            title: 'Chưa có người thân',
            message:
                'Thêm người thân để đặt lịch và theo dõi hồ sơ cho cả gia đình.',
            icon: Icons.people_outline)
      else
        for (final p in profile.family)
          _row(context,
              name: p.fullName,
              subtitle:
                  '${p.relationship.isEmpty ? 'Người thân' : p.relationship} · ${_date(p.birthday)}',
              healthWarning: p.health.hasWarning,
              onEdit: () =>
                  MeRoutes.open(context, MeRoutes.familyForm, arguments: p),
              onDelete: () async {
                final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                            title: const Text('Xóa người thân?'),
                            content: Text(
                                'Bạn có muốn xóa ${p.fullName} khỏi danh sách người thân?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Hủy')),
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Xác nhận xóa'))
                            ]));
                if (confirmed != true || !context.mounted) return;
                final error = await profile.deleteFamily(p.id);
                if (!context.mounted) return;
                meMessage(
                    context,
                    error == null
                        ? 'Đã xóa người thân.'
                        : 'Chưa xóa được: $error');
              }),
      SecondaryButton(
          label: 'Thêm người thân',
          icon: Icons.add,
          onPressed: () => MeRoutes.open(context, MeRoutes.familyForm)),
    ]);
  }

  static String _date(DateTime? date) =>
      date == null ? 'Chưa có ngày sinh' : formatVietnameseDate(date);

  Widget _row(BuildContext context,
          {required String name,
          required String subtitle,
          bool healthWarning = false,
          required VoidCallback onEdit,
          VoidCallback? onDelete}) =>
      MeCard(
          child: Column(children: [
        Row(children: [
          const MeAvatar(radius: 22),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: Color(0xFF666666))),
                if (healthWarning) ...[
                  const SizedBox(height: 6),
                  const HealthWarningBadge(),
                ],
              ])),
          TextButton(onPressed: onEdit, child: const Text('Sửa'))
        ]),
        if (onDelete != null)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: onDelete,
                  child: const Text('Xóa người thân'))),
      ]));
}
