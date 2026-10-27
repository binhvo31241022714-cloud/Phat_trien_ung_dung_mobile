enum AppointmentStatus {
  pending,
  confirmed,
  completed,
  cancelled,
}

extension AppointmentStatusLabel on AppointmentStatus {
  String get label => switch (this) {
        AppointmentStatus.pending => 'Chờ xác nhận',
        AppointmentStatus.confirmed => 'Đã xác nhận',
        AppointmentStatus.completed => 'Đã hoàn tất',
        AppointmentStatus.cancelled => 'Đã hủy',
      };
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
      if (dateKey == null || time == null || time.isEmpty) return null;
      return DateTime.tryParse('${dateKey}T$time:00');
    }

    final parsedStart = parseDateTime(date, startTime) ??
        DateTime.tryParse(json['scheduledAt']?.toString() ?? '') ??
        DateTime.now();

    final parsedEnd = parseDateTime(
      date,
      json['endTime']?.toString(),
    );

    final duration = json['durationMinutes'] is num
        ? (json['durationMinutes'] as num).round()
        : parsedEnd != null
            ? parsedEnd.difference(parsedStart).inMinutes
            : 30;

    final rawServices = json['serviceIds'];
    final services = rawServices is List
        ? rawServices.map((value) => '$value').toList()
        : <String>[];

    final rawStatus = (json['status']?.toString() ?? 'booked').toLowerCase();

    // Backend sử dụng "booked" cho lịch vừa đặt.
    // Trong giao diện hiện tại, trạng thái này hiển thị là "Chờ xác nhận".
    final status = switch (rawStatus) {
      'cancelled' || 'canceled' => AppointmentStatus.cancelled,
      'completed' => AppointmentStatus.completed,
      'confirmed' => AppointmentStatus.confirmed,
      'pending' || 'booked' => AppointmentStatus.pending,
      _ => AppointmentStatus.pending,
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
      durationMinutes: duration > 0 ? duration : 30,
      serviceIds: services,
      scheduledAt: parsedStart,
      endAt: parsedEnd,
      status: status,
      note: json['note']?.toString() ?? '',
      isDemo: false,
    );
  }
}