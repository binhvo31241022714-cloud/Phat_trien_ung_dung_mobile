import 'dart:async';
import '../../core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../providers/content_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../app/patient_navigation.dart';
import 'me_widgets.dart';

const _appointmentTypes = {
  'appointment_booked',
  'appointment_cancelled',
  'appointment_confirmed',
  'appointment_rejected',
  'appointment_completed',
};

/// Thông báo kết quả khám: refId là visitId.
const _visitResultType = 'visit_result';

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
                ? n.type.startsWith('appointment_') ||
                    n.type == 'follow_up' ||
                    n.type == _visitResultType
                : filter == 'offer'
                    ? n.type == 'offer'
                    : !n.type.startsWith('appointment_') &&
                        n.type != 'follow_up' &&
                        n.type != _visitResultType &&
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
                        final session = content.sessionGeneration;
                        final data = context.read<PatientDataProvider>();
                        final dataSession = data.sessionGeneration;
                        final appointments =
                            context.read<AppointmentsProvider>();
                        final appointmentSession =
                            appointments.sessionGeneration;
                        bool current() =>
                            context.mounted &&
                            content.isSessionCurrent(session) &&
                            content.signedIn &&
                            data.isSessionCurrent(dataSession) &&
                            appointments.isSessionCurrent(appointmentSession);
                        // Read-state is independent of opening the linked resource.
                        unawaited(() async {
                          await content.markRead(n.id);
                          if (context.mounted &&
                              current() &&
                              content.errors['read'] != null) {
                            meMessage(context, content.errors['read']!);
                          }
                        }());
                        if (n.type == _visitResultType && current()) {
                          try {
                            final opened = await data.focusVisit(n.refId);
                            if (!opened || !context.mounted || !current()) {
                              return;
                            }
                          } on ApiException catch (error) {
                            if (context.mounted && current()) {
                              meMessage(context, error.message);
                            }
                            return;
                          } catch (_) {
                            if (context.mounted && current()) {
                              meMessage(context,
                                  'Không thể tải kết quả khám. Vui lòng thử lại.');
                            }
                            return;
                          }
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                          PatientNavigation.selectTab(context, 2);
                          return;
                        }
                        if (!_appointmentTypes.contains(n.type) || !current()) {
                          return;
                        }
                        try {
                          await appointments.refreshOne(n.refId);
                        } on ApiException catch (error) {
                          if (context.mounted && current()) {
                            if (error.statusCode == 403 ||
                                error.statusCode == 404) {
                              data.removeApiAppointment(n.refId,
                                  generation: dataSession);
                            }
                            meMessage(context, error.message);
                          }
                          return;
                        } catch (_) {
                          if (context.mounted && current()) {
                            meMessage(context,
                                'Không thể tải lịch hẹn. Vui lòng thử lại.');
                          }
                          return;
                        }
                        if (!context.mounted || !current()) return;
                        final matches = appointments.appointments
                            .where((a) => a.id == n.refId);
                        if (matches.isEmpty) return;
                        data.replaceAppointments(appointments.appointments,
                            generation: dataSession);
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
