import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/services/profile_service.dart';
import 'package:frontend/providers/profile_provider.dart';

/// Backend giả trong bộ nhớ cho /api/users/me và /api/family-members,
/// trả JSON giống backend Node thật. Không gọi mạng.
class FakeProfileBackend {
  Map<String, dynamic> me;
  final List<Map<String, dynamic>> family;

  /// Đặt khác null để mọi request trả lỗi HTTP này.
  int? failStatus;

  /// Id người thân còn lịch hẹn sắp tới: DELETE trả 409 như backend thật.
  final Set<String> withUpcomingAppointments = {};
  static const upcomingMessage =
      'Người thân này còn lịch hẹn sắp tới. Vui lòng hủy lịch hẹn trước khi xóa.';
  int _nextId = 1;

  FakeProfileBackend(
      {Map<String, dynamic>? me, List<Map<String, dynamic>>? family})
      : me = me ??
            {
              'id': 'uid-test',
              'email': 'patient@example.com',
              'fullName': 'Trần Thị Test',
              'phone': '0900000000',
            },
        family = family ?? [];

  ProfileService service() => ProfileService(
      client: ApiClient(
          baseUrl: 'http://fake.invalid:3000', client: MockClient(_handle)));

  ProfileProvider provider() => ProfileProvider(service: service());

  Future<http.Response> _handle(http.Request request) async {
    if (failStatus != null) {
      return _json({'message': 'Lỗi giả lập'}, failStatus!);
    }
    final path = request.url.path;
    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    if (path == '/api/users/me') {
      if (request.method == 'PATCH') {
        me = {...me, ...body};
        return _json({'message': 'Cập nhật thành công'});
      }
      return _json(me);
    }
    if (path == '/api/family-members') {
      if (request.method == 'POST') {
        final id = 'fam-${_nextId++}';
        family.add({'id': id, ...body});
        return _json({'id': id}, 201);
      }
      return _json(family);
    }
    if (path.startsWith('/api/family-members/')) {
      final id = path.split('/').last;
      final index = family.indexWhere((m) => m['id'] == id);
      if (index < 0) return _json({'message': 'Không tìm thấy'}, 404);
      if (request.method == 'DELETE') {
        if (withUpcomingAppointments.contains(id)) {
          return _json({'message': upcomingMessage}, 409);
        }
        family.removeAt(index);
        return _json({'message': 'Đã xóa'});
      }
      family[index] = {...family[index], ...body};
      return _json({'message': 'Cập nhật thành công'});
    }
    return _json({'message': 'API không tồn tại'}, 404);
  }

  http.Response _json(Object data, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(data)), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
}
