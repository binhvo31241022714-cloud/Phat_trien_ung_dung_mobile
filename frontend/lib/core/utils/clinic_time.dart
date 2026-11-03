DateTime clinicInstant(int year, int month, int day, int hour, int minute) =>
    DateTime.utc(year, month, day, hour, minute);

DateTime clinicWallTime(DateTime value) => value.toUtc();
