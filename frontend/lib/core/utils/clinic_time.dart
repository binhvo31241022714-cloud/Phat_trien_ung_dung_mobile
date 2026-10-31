/// Clinic contract: Asia/Ho_Chi_Minh, fixed UTC+07:00 (no DST).
/// Store instants as UTC; this wall-clock value is for display/date pickers only.
DateTime clinicWallTime(DateTime instant) {
  final wall = instant.toUtc().add(const Duration(hours: 7));
  return DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute,
      wall.second, wall.millisecond, wall.microsecond);
}

DateTime clinicInstant(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(year, month, day, hour, minute)
        .subtract(const Duration(hours: 7));
