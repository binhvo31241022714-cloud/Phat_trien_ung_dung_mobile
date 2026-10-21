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
  final int totalPrice;
  final List<String> serviceIds;
  final DateTime scheduledAt;
  final AppointmentStatus status;
  final String note;
  final bool isDemo;

  Appointment({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.totalPrice = 0,
    required List<String> serviceIds,
    required this.scheduledAt,
    required this.status,
    this.note = '',
    this.isDemo = true,
  }) : serviceIds = List.unmodifiable(serviceIds);
}
