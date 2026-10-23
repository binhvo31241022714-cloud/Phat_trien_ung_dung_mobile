String formatVnd(num amount) {
  final value = amount.round();
  final digits = value.abs().toString();
  final grouped = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      grouped.write('.');
    }
    grouped.write(digits[index]);
  }
  return '${value < 0 ? '-' : ''}$grouped ₫';
}

String formatVietnameseDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

String formatVietnameseTime(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String formatVietnameseDateTime(DateTime date) =>
    '${formatVietnameseDate(date)} lúc ${formatVietnameseTime(date)}';
