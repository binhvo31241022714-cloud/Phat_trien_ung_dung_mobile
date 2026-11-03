import 'package:flutter/material.dart';
class BookingShortcutButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final String? doctorId;
  final String? serviceId;
  final List<String>? serviceIds;
  final String? comboId;
  const BookingShortcutButton({this.onPressed, this.label = 'Đặt lịch', this.doctorId, this.serviceId, this.serviceIds, this.comboId, super.key});
  @override Widget build(BuildContext context) => SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onPressed, child: Text(label)));
}
