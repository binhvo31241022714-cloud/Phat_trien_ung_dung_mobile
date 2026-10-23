import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/patient_navigation.dart';
import '../../data/providers/patient_data_provider.dart';
import 'records_widgets.dart';

class FollowupScreen extends StatelessWidget {
  const FollowupScreen({required this.patientId, super.key});
  final String patientId;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final followups = data.followupsFor(patientId);
    return RecordsPage(title: 'Lịch tái khám', children: [
      if (followups.isEmpty)
        const RecordEmpty('Chưa có lịch tái khám được đề xuất.'),
      for (final f in followups)
        RecordCard(children: [
          RecordBadge(
              f.scheduledAt.isAfter(DateTime.now())
                  ? 'Sắp tới'
                  : 'Ngày đề xuất đã qua',
              color: Colors.deepOrange),
          RecordHeading(f.note.isEmpty ? 'Lịch tái khám' : f.note),
          Text(recordDateTime(f.scheduledAt)),
          const SizedBox(height: 8),
          Text(doctorName(data, f.doctorId)),
          RecordButton('Đặt lịch tái khám', () {
            data.requestBookingFor(patientId);
            PatientNavigation.selectTab(context, 1);
          }),
          if (!f.scheduledAt.isAfter(DateTime.now()))
            const Text('Vui lòng chọn ngày khám mới trong bước đặt lịch.',
                style: TextStyle(color: Color(0xFF666666))),
        ]),
    ]);
  }
}
