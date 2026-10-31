import '../api_client.dart';
import '../models/appointment.dart';

/// Các API phục vụ Module 2: Đặt lịch nha khoa.
/// Tất cả request đều sử dụng ApiClient dùng chung của ứng dụng.
class BookingService {
  final ApiClient _api;

  BookingService({ApiClient? client}) : _api = client ?? api;

  static const ApiException _invalidResponse = ApiException(
    'Dữ liệu máy chủ trả về không đúng định dạng.',
  );

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    throw _invalidResponse;
  }

  /// Báo giá được tính ở backend dựa trên giá lưu trong Firestore.
  Future<BookingQuote> quote({
    List<String> serviceIds = const [],
    String? comboId,
    String? voucherCode,
  }) async {
    final body = <String, dynamic>{
      'serviceIds': serviceIds,
      if (comboId != null && comboId.isNotEmpty) 'comboId': comboId,
      if (voucherCode != null && voucherCode.trim().isNotEmpty)
        'voucherCode': voucherCode.trim(),
    };

    final result = _readMap(await _api.post('/api/bookings/quote', body));
    return BookingQuote.fromJson(result);
  }

  /// Xác thực voucher ở backend.
  /// Nếu mã không hợp lệ, ApiClient sẽ ném ApiException.
  Future<VoucherValidation> validateVoucher({
    required String code,
    List<String> serviceIds = const [],
    String? comboId,
  }) async {
    final body = <String, dynamic>{
      'code': code.trim(),
      'serviceIds': serviceIds,
      if (comboId != null && comboId.isNotEmpty) 'comboId': comboId,
    };

    final result = _readMap(
      await _api.post('/api/vouchers/validate', body),
    );

    return VoucherValidation.fromJson(result);
  }

  /// Lấy các khung giờ còn trống của một ngày.
  /// Nếu không chỉ định bác sĩ, backend trả các khung giờ của những bác sĩ
  /// đáp ứng dịch vụ/combo đã chọn.
  Future<List<AvailabilitySlot>> getAvailability({
    required DateTime date,
    String? doctorId,
    List<String> serviceIds = const [],
    String? comboId,
    int? durationMinutes,
  }) async {
    final query = <String, String>{
      'date': _dateKey(date),
      if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
      if (serviceIds.isNotEmpty) 'serviceIds': serviceIds.join(','),
      if (comboId != null && comboId.isNotEmpty) 'comboId': comboId,
      if (durationMinutes != null && durationMinutes > 0)
        'durationMinutes': durationMinutes.toString(),
    };

    final queryString = Uri(queryParameters: query).query;
    final result = _readMap(
      await _api.get('/api/availability?$queryString'),
    );

    final rawSlots = result['slots'];
    if (rawSlots is! List) throw _invalidResponse;

    return rawSlots
        .whereType<Map<String, dynamic>>()
        .map(AvailabilitySlot.fromJson)
        .toList();
  }

  /// Tạo lịch hẹn thật.
  /// [requestKey] gửi qua header Idempotency-Key: gửi lại cùng key thì máy chủ
  /// trả lại đúng lịch đã tạo, không tạo trùng.
  Future<Appointment> createAppointment({
    required String patientId,
    required DateTime date,
    required String startTime,
    String? doctorId,
    List<String> serviceIds = const [],
    String? comboId,
    String? voucherCode,
    String note = '',
    String? requestKey,
    String? followUpId,
  }) async {
    final body = <String, dynamic>{
      'patientId': patientId,
      'date': _dateKey(date),
      'startTime': startTime,
      'serviceIds': serviceIds,
      if (doctorId != null && doctorId.isNotEmpty) 'doctorId': doctorId,
      if (comboId != null && comboId.isNotEmpty) 'comboId': comboId,
      if (voucherCode != null && voucherCode.trim().isNotEmpty)
        'voucherCode': voucherCode.trim(),
      'note': note.trim(),
      if (followUpId != null && followUpId.isNotEmpty) 'followUpId': followUpId,
    };

    final result = _readMap(
      await _api.post('/api/appointments', body,
          headers: requestKey == null ? null : {'Idempotency-Key': requestKey}),
    );

    return Appointment.fromJson(result);
  }

  /// Lịch hẹn của tài khoản đăng nhập, bao gồm lịch cho người thân.
  Future<List<Appointment>> getAppointments() async {
    final result = await _api.get('/api/appointments');
    if (result is! List) throw _invalidResponse;

    return result
        .whereType<Map<String, dynamic>>()
        .map(Appointment.fromJson)
        .toList();
  }

  /// Chi tiết một lịch hẹn.
  Future<Appointment> getAppointment(String id) async {
    final result = _readMap(
      await _api.get('/api/appointments/${Uri.encodeComponent(id)}'),
    );
    return Appointment.fromJson(result);
  }

  Future<AppointmentCancellationInfo> cancellationInfo(String id) async {
    final json = _readMap(
        await _api.get('/api/appointments/${Uri.encodeComponent(id)}'));
    if (json['id'] != id) throw _invalidResponse;
    return AppointmentCancellationInfo(json);
  }

  /// Hủy lịch hẹn trên máy chủ.
  Future<void> cancelAppointment(String id) async {
    final result = _readMap(await _api.patch(
      '/api/appointments/${Uri.encodeComponent(id)}/cancel',
      <String, dynamic>{},
    ));
    if (result['id'] != id || result['status'] != 'cancelled') {
      throw _invalidResponse;
    }
  }
}

class BookingQuote {
  final List<String> serviceIds;
  final String? comboId;
  final int subtotal;
  final int discount;
  final int totalPrice;
  final int durationMinutes;
  final String? voucherCode;

  const BookingQuote({
    required this.serviceIds,
    required this.comboId,
    required this.subtotal,
    required this.discount,
    required this.totalPrice,
    required this.durationMinutes,
    required this.voucherCode,
  });

  factory BookingQuote.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value) =>
        value is num ? value.round() : int.tryParse('$value') ?? 0;

    final rawServices = json['serviceIds'];

    return BookingQuote(
      serviceIds: rawServices is List
          ? rawServices.map((value) => '$value').toList()
          : const [],
      comboId: json['comboId'] is String ? json['comboId'] as String : null,
      subtotal: readInt(json['subtotal']),
      discount: readInt(json['discount']),
      totalPrice: readInt(json['totalPrice']),
      durationMinutes: readInt(json['durationMinutes']),
      voucherCode:
          json['voucherCode'] is String ? json['voucherCode'] as String : null,
    );
  }
}

class VoucherValidation {
  final bool valid;
  final String code;
  final int subtotal;
  final int discount;
  final int totalPrice;

  const VoucherValidation({
    required this.valid,
    required this.code,
    required this.subtotal,
    required this.discount,
    required this.totalPrice,
  });

  factory VoucherValidation.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value) =>
        value is num ? value.round() : int.tryParse('$value') ?? 0;

    return VoucherValidation(
      valid: json['valid'] == true,
      code: json['code']?.toString() ?? '',
      subtotal: readInt(json['subtotal']),
      discount: readInt(json['discount']),
      totalPrice: readInt(json['totalPrice']),
    );
  }
}

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
      doctorId: json['doctorId']?.toString() ?? '',
      doctorName: json['doctorName']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      durationMinutes: json['durationMinutes'] is num
          ? (json['durationMinutes'] as num).round()
          : int.tryParse('${json['durationMinutes']}') ?? 0,
    );
  }
}

/// Raw API fields are retained for eligibility; the general appointment model
/// normalizes unknown statuses/dates and must not decide cancellation rights.
class AppointmentCancellationInfo {
  final Map<String, dynamic> json;
  AppointmentCancellationInfo(Map<String, dynamic> value)
      : json = Map.unmodifiable(value);
  Appointment get appointment => Appointment.fromJson(json);
  bool canCancelFor(String uid, {DateTime? now}) {
    if (uid.isEmpty || json['accountId'] != uid) return false;
    final status = (json['status'] ?? '').toString().toLowerCase();
    if ([
      'cancelled',
      'canceled',
      'rejected',
      'declined',
      'expired',
      'completed'
    ].contains(status)) {
      return false;
    }
    final date = json['date'];
    final time = json['startTime'];
    final end = json['endTime'];
    if (date is! String ||
        time is! String ||
        end is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time) ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(end) ||
        json['doctorId'] is! String ||
        (json['doctorId'] as String).trim().isEmpty) {
      return false;
    }
    final start = DateTime.tryParse('${date}T$time:00+07:00');
    final day = DateTime.tryParse(date);
    if (start == null ||
        day == null ||
        day.toIso8601String().substring(0, 10) != date) {
      return false;
    }
    return start.isAfter(now ?? DateTime.now());
  }
}
