import 'package:flutter/material.dart';
import '../booking/booking_controller.dart';
class BookingDoctorName extends StatelessWidget {
  final BookingController? controller;
  final String? doctorId;
  final String? payloadName;
  const BookingDoctorName({this.controller, this.doctorId, this.payloadName, super.key});
  @override Widget build(BuildContext context) {
    final name = payloadName ?? (controller?.data.doctors.where((d) => d.id == doctorId).firstOrNull?.fullName ?? 'Chưa chọn bác sĩ');
    return Text('Bác sĩ: $name');
  }
}
