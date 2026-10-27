import '../api_client.dart';
import '../models/availability_slot.dart';

class AvailabilityService {
  final ApiClient _api;

  AvailabilityService({ApiClient? client}) : _api = client ?? api;

  Future<List<AvailabilitySlot>> getSlots({
    required DateTime date,
    required List<String> serviceIds,
    String? doctorId,
    String? comboId,
  }) async {
    if (serviceIds.isEmpty &&
        (comboId == null || comboId.isEmpty)) {
      throw const ApiException(
        'Vui lòng chọn ít nhất một dịch vụ hoặc combo.',
        kind: ApiErrorKind.validation,
      );
    }

    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    final query = <String, String>{
      'date': dateKey,
    };

    if (serviceIds.isNotEmpty) {
      query['serviceIds'] = serviceIds.join(',');
    }

    if (comboId != null && comboId.isNotEmpty) {
      query['comboId'] = comboId;
    }

    if (doctorId != null && doctorId.isNotEmpty) {
      query['doctorId'] = doctorId;
    }

    final path = Uri(
      path: '/api/availability',
      queryParameters: query,
    ).toString();

    final response = await _api.get(path);

    if (response is! Map<String, dynamic> ||
        response['slots'] is! List) {
      throw const ApiException(
        'Dữ liệu khung giờ khám từ máy chủ không hợp lệ.',
      );
    }

    final rows = response['slots'] as List;

    return [
      for (final row in rows)
        if (row is Map<String, dynamic>)
          AvailabilitySlot.fromJson(row),
    ];
  }
}