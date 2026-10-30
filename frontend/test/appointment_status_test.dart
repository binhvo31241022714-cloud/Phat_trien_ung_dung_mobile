import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/appointment.dart';
import 'package:frontend/providers/appointments_provider.dart';

Appointment fromStatus(Object? status,
        {String id = 'a', String date = '2099-01-01'}) =>
    Appointment.fromJson({
      'id': id,
      'patientId': 'A',
      'date': date,
      'startTime': '09:00',
      'endTime': '09:30',
      if (status != null) 'status': status,
    });

void main() {
  test('A14: mapper nhận đủ 5 trạng thái với nhãn tiếng Việt', () {
    final cases = {
      'booked': ('Chờ xác nhận', AppointmentStatus.pending),
      'confirmed': ('Đã xác nhận', AppointmentStatus.confirmed),
      'rejected': ('Bị từ chối', AppointmentStatus.rejected),
      'cancelled': ('Đã hủy', AppointmentStatus.cancelled),
      'completed': ('Đã hoàn tất', AppointmentStatus.completed),
      'CONFIRMED': ('Đã xác nhận', AppointmentStatus.confirmed),
    };
    cases.forEach((raw, expected) {
      final a = fromStatus(raw);
      expect(a.status, expected.$2, reason: raw);
      expect(a.status.label, expected.$1, reason: raw);
    });
  });

  test('A14: trạng thái lạ hoặc thiếu hiện "Không xác định"', () {
    for (final raw in ['abc', '', 42, null]) {
      final a = fromStatus(raw);
      expect(a.status, AppointmentStatus.unknown, reason: '$raw');
      expect(a.status.label, 'Không xác định');
    }
  });

  test('A14: lịch bị từ chối hoặc không xác định không vào "Lịch hẹn sắp tới"',
      () {
    final p = AppointmentsProvider();
    p.addCreated(fromStatus('rejected', id: 'rejected', date: '2098-01-01'));
    p.addCreated(fromStatus('abc', id: 'unknown', date: '2098-01-02'));
    p.addCreated(fromStatus('cancelled', id: 'cancelled', date: '2098-01-03'));
    expect(p.upcomingAppointment, isNull);
    p.addCreated(fromStatus('confirmed', id: 'confirmed', date: '2099-06-01'));
    p.addCreated(fromStatus('booked', id: 'booked', date: '2099-03-01'));
    expect(p.upcomingAppointment?.id, 'booked');
    p.dispose();
  });
}
