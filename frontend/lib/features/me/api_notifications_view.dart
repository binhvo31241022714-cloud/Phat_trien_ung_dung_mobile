import 'dart:async';
import '../../core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../data/services/content_service.dart' show ContentNotification;
import '../../providers/content_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../providers/profile_provider.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../app/patient_navigation.dart';
import 'me_widgets.dart';

/// Thông báo gắn với một lịch hẹn: refId là id lịch.
const appointmentNotificationTypes = {
  'appointment_booked',
  'appointment_cancelled',
  'appointment_confirmed',
  'appointment_rejected',
  'appointment_completed',
  'appointment_reminder',
};

/// Thông báo kết quả khám: refId là visitId.
const visitNotificationTypes = {'visit_result'};

/// Thông báo đề xuất tái khám: refId là followUpId.
const followUpNotificationTypes = {'follow_up', 'follow_up_reminder'};

bool _isClinical(String type) =>
    type.startsWith('appointment_') ||
    visitNotificationTypes.contains(type) ||
    followUpNotificationTypes.contains(type);

IconData _icon(String type) {
  if (type == 'appointment_reminder' || type == 'follow_up_reminder') {
    return Icons.alarm;
  }
  if (type.startsWith('appointment_')) return Icons.calendar_month_outlined;
  if (visitNotificationTypes.contains(type)) return Icons.assignment_outlined;
  if (followUpNotificationTypes.contains(type)) return Icons.event_repeat;
  if (type == 'offer') return Icons.card_giftcard;
  return Icons.notifications_none;
}

class ApiNotificationsView extends StatefulWidget {
  const ApiNotificationsView({super.key});
  @override
  State<ApiNotificationsView> createState() => _ApiNotificationsViewState();
}

class _ApiNotificationsViewState extends State<ApiNotificationsView> {
  String? filter;
  ContentProvider? _content;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ContentProvider>().loadNotifications();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _content = context.read<ContentProvider>();
  }

  @override
  void dispose() {
    // Rời màn Thông báo: cập nhật số chưa đọc trên chuông.
    final content = _content;
    if (content != null && content.signedIn) unawaited(content.loadUnread());
    super.dispose();
  }

  /// Bấm thông báo: đánh dấu đã đọc (lỗi vẫn mở, chỉ báo nhẹ), tải dữ liệu mới
  /// từ máy chủ rồi mở đúng màn trong tab Hồ sơ. Không dùng dữ liệu cũ trong máy.
  Future<void> _open(ContentNotification n) async {
    final content = context.read<ContentProvider>();
    final session = content.sessionGeneration;
    final data = context.read<PatientDataProvider>();
    final dataSession = data.sessionGeneration;
    final appointments = context.read<AppointmentsProvider>();
    final appointmentSession = appointments.sessionGeneration;
    bool current() =>
        mounted &&
        content.isSessionCurrent(session) &&
        content.signedIn &&
        data.isSessionCurrent(dataSession) &&
        appointments.isSessionCurrent(appointmentSession);

    // Dùng context chỉ trong hàm đồng bộ, sau khi kiểm tra còn đúng phiên.
    void say(String message) {
      if (context.mounted && current()) meMessage(context, message);
    }

    void showTab() {
      if (!context.mounted || !current()) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      PatientNavigation.selectTab(context, 2);
    }

    unawaited(() async {
      await content.markRead(n.id);
      final error = content.errors['read'];
      if (error != null) say(error);
    }());
    if (!current() || n.refId.isEmpty) return;

    Future<void> openWith(Future<bool> Function() focus, String fallback) async {
      try {
        if (await focus()) showTab();
      } on ApiException catch (error) {
        say(error.message);
      } catch (_) {
        say(fallback);
      }
    }

    if (visitNotificationTypes.contains(n.type)) {
      await openWith(() => data.focusVisit(n.refId),
          'Không thể tải kết quả khám. Vui lòng thử lại.');
      return;
    }
    if (followUpNotificationTypes.contains(n.type)) {
      await openWith(() => data.focusFollowUp(n.refId),
          'Không thể tải đề xuất tái khám. Vui lòng thử lại.');
      return;
    }
    if (!appointmentNotificationTypes.contains(n.type)) return;
    try {
      await appointments.refreshOne(n.refId);
    } on ApiException catch (error) {
      if (current() &&
          (error.statusCode == 403 || error.statusCode == 404)) {
        data.removeApiAppointment(n.refId, generation: dataSession);
      }
      say(error.message);
      return;
    } catch (_) {
      say('Không thể tải lịch hẹn. Vui lòng thử lại.');
      return;
    }
    if (!current()) return;
    final matches = appointments.appointments.where((a) => a.id == n.refId);
    if (matches.isEmpty) return;
    data.replaceAppointments(appointments.appointments,
        generation: dataSession);
    final appointment = matches.first;
    data.focusAppointmentsFor(appointment.patientId,
        appointmentId: appointment.id);
    showTab();
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentProvider>();
    final remindersOff =
        context.watch<ProfileProvider?>()?.profile?.notificationsEnabled ==
            false;
    final items = content.notifications
        .where((n) =>
            filter == null ||
            (filter == 'appointment'
                ? _isClinical(n.type)
                : filter == 'offer'
                    ? n.type == 'offer'
                    : !_isClinical(n.type) && n.type != 'offer'))
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
        if (remindersOff)
          const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Bạn đã tắt "Nhận thông báo" trong Cài đặt: sẽ không có nhắc lịch hẹn và nhắc tái khám. Thông báo đặt lịch, xác nhận, hủy và kết quả khám vẫn được gửi.',
                  style: TextStyle(color: Color(0xFF666666)))),
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
                onTap: content.loading('read') ? null : () => _open(n),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_icon(n.type), color: meBlue, size: 20),
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
