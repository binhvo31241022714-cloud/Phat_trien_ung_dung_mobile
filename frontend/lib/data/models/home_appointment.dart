import 'appointment.dart';
import 'content_date.dart';

/// Home-only mapping: preserves missing timing data without changing booking models.
class HomeAppointment extends Appointment {
  final String? serviceName;
  HomeAppointment._(Appointment source, DateTime start, DateTime? end,
      int? duration, this.serviceName)
      : super(
            id: source.id,
            patientId: source.patientId,
            doctorId: source.doctorId,
            doctorName: source.doctorName,
            accountId: source.accountId,
            comboId: source.comboId,
            voucherCode: source.voucherCode,
            totalPrice: source.totalPrice,
            discount: source.discount,
            durationMinutes: duration ?? 0,
            serviceIds: source.serviceIds,
            scheduledAt: start,
            endAt: end,
            status: source.status,
            note: source.note,
            isDemo: false);

  static DateTime? _slot(Object? day, Object? time) {
    if (day is! String ||
        time is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      return null;
    }
    final date = DateTime.tryParse('${day}T$time:00Z');
    if (date == null ||
        date.year != int.parse(day.substring(0, 4)) ||
        date.month != int.parse(day.substring(5, 7)) ||
        date.day != int.parse(day.substring(8, 10))) {
      return null;
    }
    return date.subtract(const Duration(hours: 7));
  }

  static HomeAppointment? read(Map<String, dynamic> json) {
    final mapped = Appointment.fromJson(json);
    final start = mapped.hasValidScheduledAt ? mapped.scheduledAt : null;
    if (start == null) return null;
    final rawDuration = json['durationMinutes'];
    // Backend appointments cannot span more than a day. Reject malformed values.
    final duration = rawDuration is num &&
            rawDuration.isFinite &&
            rawDuration > 0 &&
            rawDuration <= 1440 &&
            rawDuration == rawDuration.round()
        ? rawDuration.toInt()
        : null;
    DateTime? end = contentDate(json['endAt']);
    if (end == null || !end.isAfter(start)) {
      end = _slot(json['date'], json['endTime']);
    }
    if (end != null && !end.isAfter(start)) end = null;
    end ??= duration == null ? null : start.add(Duration(minutes: duration));
    // Sanitize fields before using the shared mapper; it must not infer a duration.
    final source = Appointment.fromJson({
      ...json,
      'date': null,
      'startTime': null,
      'scheduledAt': start.toUtc().toIso8601String(),
      'endTime': null,
      'durationMinutes': duration ?? 0
    });
    final name = json['serviceName'];
    return HomeAppointment._(source, start, end, duration,
        name is String && name.trim().isNotEmpty ? name.trim() : null);
  }
}
