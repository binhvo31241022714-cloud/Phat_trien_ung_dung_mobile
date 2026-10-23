import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/secondary_button.dart';
import '../../data/providers/patient_data_provider.dart';
import 'me_widgets.dart';

class FamilyListScreen extends StatelessWidget {
  const FamilyListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    return MePage(title: 'Quản lý người thân', children: [
      for (final p in data.patients)
        MeCard(
            child: Column(children: [
          Row(children: [
            const MeAvatar(radius: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                      '${p.isPrimary ? "Bản thân" : p.relationship} · ${formatVietnameseDate(p.dateOfBirth)}',
                      style: const TextStyle(color: Color(0xFF666666)))
                ])),
            TextButton(
                onPressed: () => MeRoutes.open(context,
                    p.isPrimary ? MeRoutes.profile : MeRoutes.familyForm,
                    arguments: p.isPrimary ? null : p),
                child: const Text('Sửa'))
          ]),
          if (!p.isPrimary)
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
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
                      if (confirmed == true && context.mounted) {
                        final reason = data.removeFamilyMember(p.id);
                        meMessage(context,
                            reason ?? 'Đã xóa người thân trong phiên demo.');
                      }
                    },
                    child: const Text('Xóa người thân'))),
        ])),
      SecondaryButton(
          label: 'Thêm người thân',
          icon: Icons.add,
          onPressed: () => MeRoutes.open(context, MeRoutes.familyForm)),
      const SizedBox(height: 12),
      const Text(demoSessionNotice,
          style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
    ]);
  }
}
