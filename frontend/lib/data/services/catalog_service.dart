import '../models/article.dart';
import '../api_client.dart';
import '../models/dental_service.dart';
import '../models/doctor.dart';
import '../models/json_read.dart';

/// Một mục trong /api/favorites, ví dụ { id: "service_svc_01",
/// type: "service", itemId: "svc_01" }.
class Favorite {
  final String id;
  final String type;
  final String itemId;
  const Favorite({required this.id, required this.type, required this.itemId});

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        id: readString(json['id']),
        type: readString(json['type']),
        itemId: readString(json['itemId']),
      );
}

/// Gọi /api/services, /api/combos, /api/doctors và /api/favorites.
/// Lỗi ném ra [ApiException].
class CatalogService {
  final ApiClient _api;

  /// Test truyền ApiClient giả; app dùng biến [api] dùng chung.
  CatalogService({ApiClient? client}) : _api = client ?? api;

  Future<List<DentalService>> getServices() async => [
        for (final row in await _list('/api/services'))
          DentalService.fromJson(row)
      ];

  Future<List<DentalService>> getCombos() async => [
        for (final row in await _list('/api/combos'))
          DentalService.fromJson(row, isCombo: true)
      ];

  Future<List<Doctor>> getDoctors() async =>
      [for (final row in await _list('/api/doctors')) Doctor.fromJson(row)];

  Future<Article> getArticle(String id) async =>
      Article.fromJson(await _one('/api/articles/${Uri.encodeComponent(id)}'));

  Future<DentalService> getService(String id) async =>
      DentalService.fromJson(await _one('/api/services/$id'));

  Future<DentalService> getCombo(String id) async =>
      DentalService.fromJson(await _one('/api/combos/$id'), isCombo: true);

  Future<Doctor> getDoctor(String id) async =>
      Doctor.fromJson(await _one('/api/doctors/$id'));

  Future<List<Favorite>> getFavorites() async =>
      [for (final row in await _list('/api/favorites')) Favorite.fromJson(row)];

  Future<void> addFavorite(String type, String itemId) =>
      _api.post('/api/favorites', {'type': type, 'itemId': itemId});

  Future<void> removeFavorite(String favoriteId) =>
      _api.delete('/api/favorites/$favoriteId');

  Future<List<Map<String, dynamic>>> _list(String path) async {
    final data = await _api.get(path);
    if (data is! List) throw _invalid;
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> _one(String path) async {
    final data = await _api.get(path);
    if (data is! Map<String, dynamic>) throw _invalid;
    return data;
  }

  static const _invalid =
      ApiException('Dữ liệu máy chủ trả về không đúng định dạng.');
}
