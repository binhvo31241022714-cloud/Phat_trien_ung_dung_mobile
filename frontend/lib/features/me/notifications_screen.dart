import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/patient_navigation.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/appointment.dart';
import '../../data/models/patient_records.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/user_provider.dart';
import 'me_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationCategory? _filter;
  Appointment? _appointment(
      PatientDataProvider data, PatientNotification notification) {
    for (final a in data.appointments) {
      if (a.id == notification.appointmentId) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final receive = context.watch<UserProvider>().receiveNotifications;
    final categories = <NotificationCategory?, String>{
      null: 'Tất cả',
      NotificationCategory.appointment: 'Lịch hẹn',
      NotificationCategory.offer: 'Ưu đãi',
      NotificationCategory.system: 'Hệ thống'
    };
    final notifications = data.notifications
        .where((n) => _filter == null || n.category == _filter)
        .toList();
    return MePage(title: 'Thông báo', children: [
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final entry in categories.entries)
              Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 12),
                  child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      showCheckmark: false,
                      selectedColor: Colors.black,
                      labelStyle: TextStyle(
                          color: _filter == entry.key
                              ? Colors.white
                              : Colors.grey),
                      onSelected: (_) => setState(() => _filter = entry.key)))
          ])),
      if (!receive)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
                'Bạn đã tắt nhận thông báo trong phiên demo. Cài đặt này không thay đổi quyền thông báo của hệ điều hành.',
                style: TextStyle(color: Color(0xFF666666)))),
      if (notifications.isEmpty)
        const MeCard(
            child:
                Center(child: Text('Chưa có thông báo trong danh mục này.'))),
      for (final n in notifications)
        Builder(builder: (context) {
          final a = _appointment(data, n);
          final names = a == null
              ? ''
              : data.services
                  .where((s) => a.serviceIds.contains(s.id))
                  .map((s) => s.name)
                  .join(', ');
          return MeCard(
              onTap: () {
                data.markNotificationRead(n.id);
                if (a != null) {
                  data.focusAppointmentsFor(a.patientId, appointmentId: a.id);
                  PatientNavigation.selectTab(context, 2);
                }
              },
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(
                          switch (n.category) {
                            NotificationCategory.appointment =>
                              Icons.calendar_month_outlined,
                            NotificationCategory.offer => Icons.card_giftcard,
                            NotificationCategory.system =>
                              Icons.notifications_none
                          },
                          color: meBlue,
                          size: 20),
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
                    Text(
                        a == null
                            ? (n.category == NotificationCategory.appointment
                                ? 'Lịch hẹn liên kết không còn khả dụng. Đây là thông báo demo.'
                                : (n.message.trim().isEmpty
                                    ? 'Chưa có nội dung thông báo.'
                                    : n.message))
                            : 'Lịch $names ngày ${formatVietnameseDate(a.scheduledAt)} lúc ${formatVietnameseTime(a.scheduledAt)} · ${a.status.label}.',
                        style: const TextStyle(color: Color(0xFF666666))),
                    const SizedBox(height: 6),
                    Text(n.isRead ? 'Đã đọc' : 'Chưa đọc',
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 11)),
                  ]));
        }),
      const Text('Thông báo mẫu trong phiên demo.',
          style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
    ]);
  }
}
