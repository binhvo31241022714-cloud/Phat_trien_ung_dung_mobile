import 'json_read.dart';

class AvailabilitySlot {
  final String doctorId;
  final String doctorName;
  final String date;
  final String startTime;
  final String endTime;
  final int durationMinutes;

  const AvailabilitySlot({
    required this.doctorId,
    required this.doctorName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      doctorId: readString(json['doctorId']),
      doctorName: readString(json['doctorName']),
      date: readString(json['date']),
      startTime: readString(json['startTime']),
      endTime: readString(json['endTime']),
      durationMinutes: readInt(json['durationMinutes']),
    );
  }
}