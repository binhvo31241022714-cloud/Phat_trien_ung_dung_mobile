import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../providers/content_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../app/patient_navigation.dart';
import '../records/appointment_api_status.dart';
import 'me_widgets.dart';

const _appointmentTypes = {
  'appointment_booked',
  'appointment_cancelled',
  'appointment_confirmed',
  'appointment_rejected',
  'appointment_completed',
};

class ApiNotificationsView extends StatefulWidget {
  const ApiNotificationsView({super.key});
  @override
  State<ApiNotificationsView> createState() => _ApiNotificationsViewState();
}

class _ApiNotificationsViewState extends State<ApiNotificationsView> {
  String? filter;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ContentProvider>().loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final items = content.notifications
        .where((n) =>
            filter == null ||
            (filter == 'appointment'
                ? n.type.startsWith('appointment_') || n.type == 'follow_up'
                : filter == 'offer'
                    ? n.type == 'offer'
                    : !n.type.startsWith('appointment_') &&
                        n.type != 'follow_up' &&
                        n.type != 'offer'))
        .toList();
    return MePage(title: 'Thông báo', children: [
      if (!content.signedIn)
        const Text('Vui lòng đăng nhập để xem thông báo.')
      else ...[
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final entry in <String?, String>{
                null: 'Tất cả',
                'appointment': 'Lịch hẹn',
                'offer': 'Ưu đãi',
                'system': 'Hệ thống'
              }.entries)
                Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 12),
                    child: ChoiceChip(
                        label: Text(entry.value),
                        selected: filter == entry.key,
                        onSelected: (_) => setState(() => filter = entry.key))),
            ])),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: content.loading('read') ||
                        content.loading('notifications')
                    ? null
                    : () async {
                        await content.readAll();
                        if (context.mounted && content.errors['read'] != null) {
                          meMessage(context, content.errors['read']!);
                        }
                      },
                child: const Text('Đọc tất cả'))),
        if (content.loading('notifications'))
          const Center(child: CircularProgressIndicator())
        else if (content.errors['notifications'] != null)
          MeCard(
              child: Column(children: [
            Text(content.errors['notifications']!),
            TextButton(
                onPressed: content.loadNotifications,
                child: const Text('Thử lại'))
          ]))
        else if (items.isEmpty)
          const MeCard(
              child:
                  Center(child: Text('Chưa có thông báo trong danh mục này.')))
        else
          for (final n in items)
            MeCard(
                onTap: content.loading('read')
                    ? null
                    : () async {
                        await content.markRead(n.id);
                        if (!context.mounted) return;
                        if (content.errors['read'] != null) {
                          meMessage(context, content.errors['read']!);
                          return;
                        }
                        if (!_appointmentTypes.contains(n.type)) return;
                        // Tải lại (cả AppointmentsProvider lẫn PatientDataProvider
                        // mà màn Hồ sơ đọc) để thấy trạng thái mới. Chỉ mở lịch có
                        // trong danh sách lấy từ API có phân quyền.
                        final appointments =
                            context.read<AppointmentsProvider>();
                        await reloadAppointments(context);
                        if (!context.mounted) return;
                        final matches = appointments.appointments
                            .where((a) => a.id == n.refId);
                        if (matches.isEmpty) {
                          meMessage(
                              context, 'Lịch hẹn liên kết không còn khả dụng.');
                          return;
                        }
                        final appointment = matches.first;
                        context
                            .read<PatientDataProvider>()
                            .focusAppointmentsFor(appointment.patientId,
                                appointmentId: appointment.id);
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                        PatientNavigation.selectTab(context, 2);
                      },
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.notifications_none,
                            color: meBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                n.title.trim().isEmpty ? 'Thông báo' : n.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                        if (!n.isRead)
                          const Icon(Icons.circle, size: 8, color: meBlue)
                      ]),
                      const SizedBox(height: 10),
                      Text(n.body.trim().isEmpty
                          ? 'Chưa có nội dung thông báo.'
                          : n.body),
                      if (n.createdAt != null)
                        Text(
                            '${formatVietnameseDate(n.createdAt!)} ${formatVietnameseTime(n.createdAt!)}',
                            style: const TextStyle(fontSize: 11)),
                      Text(n.isRead ? 'Đã đọc' : 'Chưa đọc',
                          style: const TextStyle(fontSize: 11)),
                    ])),
      ],
    ]);
  }
}
