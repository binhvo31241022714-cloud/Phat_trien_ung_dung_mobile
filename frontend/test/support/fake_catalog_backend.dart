import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/data/services/catalog_service.dart';
import 'package:frontend/providers/catalog_provider.dart';

/// Backend giả trong bộ nhớ cho /api/services, /api/combos, /api/doctors và
/// /api/favorites, dữ liệu giống mẫu trên Firestore. Không gọi mạng.
class FakeCatalogBackend {
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> combos;
  final List<Map<String, dynamic>> doctors;
  final List<Map<String, dynamic>> favorites = [];

  /// Đặt khác null để mọi request trả lỗi HTTP này.
  int? failStatus;

  FakeCatalogBackend({
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? combos,
    List<Map<String, dynamic>>? doctors,
  })  : services = services ??
            [
              {
                'id': 'svc_01',
                'name': 'Khám răng tổng quát',
                'price': 100000,
                'durationMinutes': 30,
                'description': 'Kiểm tra tình trạng răng, nướu.',
                'imageUrl': '',
                'isActive': true,
              },
              {
                'id': 'svc_02',
                'name': 'Lấy cao răng',
                'price': 200000,
                'durationMinutes': 30,
                'imageUrl': '',
              },
            ],
        combos = combos ??
            [
              {
                'id': 'combo_01',
                'name': 'Combo chăm sóc răng miệng cơ bản',
                'price': 250000,
                'durationMinutes': 60,
                'serviceIds': ['svc_01', 'svc_02'],
              },
            ],
        doctors = doctors ??
            [
              {
                'id': 'doc_01',
                'name': 'BS. Nguyễn Văn API',
                'specialty': 'Nha khoa tổng quát',
                'experienceYears': 8,
                'avatarUrl': '',
                'serviceIds': ['svc_01'],
              },
            ];

  CatalogService service() => CatalogService(
      client: ApiClient(
          baseUrl: 'http://fake.invalid:3000', client: MockClient(_handle)));

  CatalogProvider provider() => CatalogProvider(service: service());

  Future<http.Response> _handle(http.Request request) async {
    if (failStatus != null) {
      return _json({'message': 'Lỗi giả lập'}, failStatus!);
    }
    final parts = request.url.pathSegments; // ['api', 'services', 'svc_01']
    final collections = {
      'services': services,
      'combos': combos,
      'doctors': doctors,
    };
    if (parts.length >= 2 && collections.containsKey(parts[1])) {
      final rows = collections[parts[1]]!;
      if (parts.length == 2) {
        return _json(rows.where((r) => r['isActive'] != false).toList());
      }
      final row = rows.where((r) => r['id'] == parts[2]);
      return row.isEmpty
          ? _json({'message': 'Không tìm thấy'}, 404)
          : _json(row.first);
    }
    if (parts.length >= 2 && parts[1] == 'favorites') {
      if (request.method == 'GET') return _json(favorites);
      if (request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final id = '${body['type']}_${body['itemId']}';
        favorites.removeWhere((f) => f['id'] == id);
        favorites.add({'id': id, ...body});
        return _json({'id': id}, 201);
      }
      if (request.method == 'DELETE') {
        final before = favorites.length;
        favorites.removeWhere((f) => f['id'] == parts[2]);
        return favorites.length == before
            ? _json({'message': 'Không tìm thấy'}, 404)
            : _json({'message': 'Đã xóa'});
      }
    }
    return _json({'message': 'API không tồn tại'}, 404);
  }

  http.Response _json(Object data, [int status = 200]) =>
      http.Response.bytes(utf8.encode(jsonEncode(data)), status,
          headers: {'content-type': 'application/json; charset=utf-8'});
}
