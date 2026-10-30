import 'content_date.dart';

enum AppointmentStatus {
  pending,
  confirmed,
  rejected,
  completed,
  cancelled,
  unknown,
}

extension AppointmentStatusLabel on AppointmentStatus {
  String get label => switch (this) {
        AppointmentStatus.pending => 'Chờ xác nhận',
        AppointmentStatus.confirmed => 'Đã xác nhận',
        AppointmentStatus.rejected => 'Bị từ chối',
        AppointmentStatus.completed => 'Đã hoàn tất',
        AppointmentStatus.cancelled => 'Đã hủy',
        AppointmentStatus.unknown => 'Không xác định',
      };

  /// Lịch còn hiệu lực sắp tới: chờ xác nhận hoặc đã xác nhận.
  bool get isUpcomingStatus =>
      this == AppointmentStatus.pending || this == AppointmentStatus.confirmed;
}

class Appointment {
  final String id;
  final String patientId;
  final String? doctorId;
  final String? doctorName;
  final String? accountId;
  final String? comboId;
  final String? voucherCode;

  final int totalPrice;
  final int discount;
  final int durationMinutes;

  final List<String> serviceIds;

  /// False when API date/time is absent or malformed; epoch is only a storage sentinel.
  final bool hasValidScheduledAt;
  final DateTime scheduledAt;
  final DateTime? endAt;
  final AppointmentStatus status;
  final String note;

  /// true: dữ liệu mẫu; false: lịch đọc hoặc tạo từ API thật.
  final bool isDemo;

  Appointment({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.doctorName,
    this.accountId,
    this.comboId,
    this.voucherCode,
    this.totalPrice = 0,
    this.discount = 0,
    this.durationMinutes = 30,
    required List<String> serviceIds,
    this.hasValidScheduledAt = true,
    required this.scheduledAt,
    this.endAt,
    required this.status,
    this.note = '',
    this.isDemo = true,
  }) : serviceIds = List.unmodifiable(serviceIds);

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final date = json['date']?.toString();
    final startTime = json['startTime']?.toString();

    DateTime? parseDateTime(String? dateKey, String? time) {
      if (dateKey == null ||
          time == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateKey) ||
          !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
        return null;
      }
      final result = DateTime.tryParse('${dateKey}T$time:00');
      if (result == null ||
          result.year != int.parse(dateKey.substring(0, 4)) ||
          result.month != int.parse(dateKey.substring(5, 7)) ||
          result.day != int.parse(dateKey.substring(8, 10))) {
        return null;
      }
      return result;
    }

    DateTime? timestamp(Object? value) {
      if (value is String) {
        if (!RegExp(
                r'^\d{4}-\d{2}-\d{2}T([01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d+)?)?(?:Z|[+-]([01]\d|2[0-3]):?[0-5]\d)?$')
            .hasMatch(value)) {
          return null;
        }
        final parts =
            RegExp(r'^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2})').firstMatch(value);
        if (parts == null || parseDateTime(parts[1], parts[2]) == null) {
          return null;
        }
      }
      return contentDate(value);
    }

    final start =
        parseDateTime(date, startTime) ?? timestamp(json['scheduledAt']);
    final parsedStart = start ?? DateTime.fromMillisecondsSinceEpoch(0);
    final candidateEnd = timestamp(json['endAt']) ??
        parseDateTime(
            date, json['endTime'] is String ? json['endTime'] as String : null);
    final rawDuration = json['durationMinutes'];
    final explicitDuration = rawDuration is num &&
            rawDuration.isFinite &&
            rawDuration > 0 &&
            rawDuration == rawDuration.round()
        ? rawDuration.toInt()
        : 0;
    final validEnd =
        start != null && candidateEnd != null && candidateEnd.isAfter(start)
            ? candidateEnd
            : null;
    final duration = validEnd != null
        ? validEnd.difference(parsedStart).inMinutes
        : explicitDuration;
    DateTime? parsedEnd = validEnd;
    if (parsedEnd == null && start != null && explicitDuration > 0) {
      try {
        parsedEnd = start.add(Duration(minutes: explicitDuration));
      } catch (_) {/* Unknown end. */}
    }

    final rawServices = json['serviceIds'];
    final services = rawServices is List
        ? rawServices.map((value) => '$value').toList()
        : <String>[];

    final rawStatus = (json['status']?.toString() ?? '').trim().toLowerCase();

    // Backend dùng 5 trạng thái: booked (hiển thị "Chờ xác nhận"), confirmed,
    // rejected, cancelled, completed. Trạng thái lạ hiển thị "Không xác định".
    final status = switch (rawStatus) {
      'cancelled' || 'canceled' => AppointmentStatus.cancelled,
      'completed' => AppointmentStatus.completed,
      'confirmed' => AppointmentStatus.confirmed,
      'rejected' || 'declined' => AppointmentStatus.rejected,
      'pending' || 'booked' => AppointmentStatus.pending,
      _ => AppointmentStatus.unknown,
    };

    int readInt(dynamic value) =>
        value is num ? value.round() : int.tryParse('$value') ?? 0;

    return Appointment(
      id: json['id']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      doctorId: json['doctorId']?.toString(),
      doctorName: json['doctorName']?.toString(),
      accountId: json['accountId']?.toString(),
      comboId: json['comboId']?.toString(),
      voucherCode: json['voucherCode']?.toString(),
      totalPrice: readInt(json['totalPrice']),
      discount: readInt(json['discount']),
      durationMinutes: duration,
      hasValidScheduledAt: start != null,
      serviceIds: services,
      scheduledAt: parsedStart,
      endAt: parsedEnd,
      status: status,
      note: json['note']?.toString() ?? '',
      isDemo: false,
    );
  }
}
