DateTime? contentDate(Object? value) {
  try {
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanos = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
      if (seconds is num &&
          seconds.isFinite &&
          nanos is num &&
          nanos.isFinite) {
        return DateTime.fromMicrosecondsSinceEpoch(
                (seconds * 1000000 + nanos / 1000).round(),
                isUtc: true)
            .toLocal();
      }
    }
  } catch (_) {/* Malformed/out-of-range timestamps are unknown dates. */}
  return null;
}
