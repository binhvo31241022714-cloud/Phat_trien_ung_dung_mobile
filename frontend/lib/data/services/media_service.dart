import 'dart:typed_data';

import '../../core/media/photo_picker.dart';
import '../api_client.dart';

/// Ảnh lưu trên backend (collection media): ảnh đại diện, ảnh trước/sau điều trị.
class MediaService {
  final ApiClient _api;
  MediaService({ApiClient? client}) : _api = client ?? api;

  /// Dùng chung cho widget hiển thị ảnh; test gán bản có ApiClient giả.
  static MediaService shared = MediaService();

  Future<Uint8List> bytes(String mediaId) =>
      _api.getBytes('/api/media/$mediaId');

  /// Trả về avatarMediaId mới (null khi gỡ ảnh).
  Future<String?> setMyAvatar(PickedImage? image) =>
      _avatar('/api/users/me/avatar', image);

  Future<String?> setFamilyAvatar(String memberId, PickedImage? image) =>
      _avatar('/api/family-members/$memberId/avatar', image);

  Future<String?> _avatar(String path, PickedImage? image) async {
    final result = image == null
        ? await _api.delete(path)
        : await _api.put(path, image.toJson());
    if (result is! Map) throw _invalid;
    final id = result['avatarMediaId'];
    return id is String && id.isNotEmpty ? id : null;
  }

  /// Ảnh cũ và ảnh mới của liệu trình (GET /api/treatments/:id/photos).
  Future<List<Map<String, dynamic>>> treatmentPhotos(String treatmentId) async {
    final result = await _api.get('/api/treatments/$treatmentId/photos');
    if (result is! List) throw _invalid;
    return result.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> uploadTreatmentPhoto(
    String treatmentId, {
    required String phase,
    required PickedImage image,
    String? sessionId,
    String? note,
  }) async {
    final result = await _api.post('/api/treatments/$treatmentId/photos', {
      'phase': phase,
      ...image.toJson(),
      if (sessionId != null) 'sessionId': sessionId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    if (result is! Map<String, dynamic>) throw _invalid;
    return result;
  }

  Future<void> deleteTreatmentPhoto(String treatmentId, String photoId) =>
      _api.delete('/api/treatments/$treatmentId/photos/$photoId');

  static const _invalid =
      ApiException('Dữ liệu máy chủ trả về không đúng định dạng.');
}
