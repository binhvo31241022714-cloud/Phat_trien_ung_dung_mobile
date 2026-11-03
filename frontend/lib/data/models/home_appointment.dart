import 'appointment.dart';

class HomeAppointment extends Appointment {
  final String? serviceName;
  HomeAppointment({
    required super.id,
    required super.patientId,
    required super.scheduledAt,
    required super.status,
    required super.serviceIds,
    this.serviceName,
    super.doctorId,
    super.doctorName,
    super.accountId,
    super.comboId,
    super.voucherCode,
    super.totalPrice,
    super.discount,
    super.durationMinutes,
    super.hasValidScheduledAt,
    super.endAt,
    super.note,
    super.followUpId,
    super.isDemo,
  });

  static HomeAppointment? read(Map<String, dynamic> json) {
    final appointment = Appointment.fromJson(json);
    if (!appointment.hasValidScheduledAt) return null;
    return HomeAppointment(
      id: appointment.id,
      patientId: appointment.patientId,
      scheduledAt: appointment.scheduledAt,
      status: appointment.status,
      serviceIds: appointment.serviceIds,
      serviceName: json['serviceName']?.toString(),
      doctorId: appointment.doctorId,
      doctorName: appointment.doctorName,
      accountId: appointment.accountId,
      comboId: appointment.comboId,
      voucherCode: appointment.voucherCode,
      totalPrice: appointment.totalPrice,
      discount: appointment.discount,
      durationMinutes: appointment.durationMinutes,
      endAt: appointment.endAt,
      note: appointment.note,
      followUpId: appointment.followUpId,
      isDemo: appointment.isDemo,
    );
  }
}
