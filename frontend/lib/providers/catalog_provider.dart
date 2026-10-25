import 'package:flutter/foundation.dart';

import '../data/api_client.dart';
import '../data/models/dental_service.dart';
import '../data/models/doctor.dart';
import '../data/services/catalog_service.dart';

/// Dịch vụ, combo, bác sĩ và mục yêu thích lấy từ backend.
///
/// Tách riêng khỏi PatientDataProvider: các bước chọn dịch vụ, bác sĩ trong
/// đặt lịch vẫn dùng dữ liệu mock cho tới khi module đặt lịch nối API.
class CatalogProvider extends ChangeNotifier {
  final CatalogService _service;

  CatalogProvider({CatalogService? service})
      : _service = service ?? CatalogService();

  // Tăng mỗi lần đăng xuất, để kết quả API của phiên cũ trả về muộn bị bỏ qua.
  int _session = 0;

  // ===== Danh mục =====
  List<DentalService> _services = const [];
  List<DentalService> _combos = const [];
  List<Doctor> _doctors = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  List<DentalService> get services => _services;
  List<DentalService> get combos => _combos;
  List<Doctor> get doctors => _doctors;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  /// Đang tải lần đầu (chưa có dữ liệu cũ để hiện).
  bool get firstLoading => _loading && !_loaded;

  DentalService? serviceById(String id) =>
      _services.where((s) => s.id == id).firstOrNull;

  /// Bác sĩ thực hiện được dịch vụ: serviceIds của bác sĩ chứa id dịch vụ.
  /// Với combo: bác sĩ phải làm được TẤT CẢ dịch vụ trong combo. Combo chưa
  /// có danh sách dịch vụ thì không có bác sĩ nào.
  List<Doctor> doctorsFor(DentalService service) {
    final ids = service.isCombo ? service.serviceIds.toSet() : {service.id};
    if (ids.isEmpty) return const [];
    return _doctors.where((d) => ids.every(d.serviceIds.contains)).toList();
  }

  /// Tải nếu chưa có (gọi khi vào trang chính).
  Future<void> ensureLoaded() async {
    if (!_loaded && !_loading) await load();
    if (!_favoritesLoaded && !_favoritesLoading) await loadFavorites();
  }

  Future<void> load() async {
    final session = _session;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getServices(),
        _service.getCombos(),
        _service.getDoctors(),
      ]);
      if (session != _session) return;
      _services = List.unmodifiable(results[0] as List<DentalService>);
      _combos = List.unmodifiable(results[1] as List<DentalService>);
      _doctors = List.unmodifiable(results[2] as List<Doctor>);
      _loaded = true;
    } on ApiException catch (e) {
      if (session != _session) return;
      _error = e.message;
    }
    _loading = false;
    notifyListeners();
  }

  // ===== Yêu thích =====
  List<Favorite> _favorites = const [];
  bool _favoritesLoading = false;
  bool _favoritesLoaded = false;
  String? _favoritesError;
  final Set<String> _pending = {};
  List<Favorite> get favorites => _favorites;
  bool get favoritesLoading => _favoritesLoading;
  bool get favoritesLoaded => _favoritesLoaded;
  String? get favoritesError => _favoritesError;

  /// Id mục yêu thích theo quy ước backend: `${type}_${itemId}`.
  static String favoriteId(String type, String itemId) => '${type}_$itemId';

  bool isSaved(String type, String itemId) =>
      _favorites.any((f) => f.id == favoriteId(type, itemId));

  /// Đang gửi lưu/bỏ lưu cho mục này (để khóa nút tránh bấm 2 lần).
  bool isPending(String type, String itemId) =>
      _pending.contains(favoriteId(type, itemId));

  Future<void> loadFavorites() async {
    final session = _session;
    _favoritesLoading = true;
    _favoritesError = null;
    notifyListeners();
    try {
      final result = await _service.getFavorites();
      if (session != _session) return;
      _favorites = List.unmodifiable(result);
      _favoritesLoaded = true;
    } on ApiException catch (e) {
      if (session != _session) return;
      _favoritesError = e.message;
    }
    _favoritesLoading = false;
    notifyListeners();
  }

  /// Lưu hoặc bỏ lưu. Trả về null nếu thành công, ngược lại trả về lỗi.
  Future<String?> toggleFavorite(String type, String itemId) async {
    final id = favoriteId(type, itemId);
    if (!_pending.add(id)) return null;
    final saved = isSaved(type, itemId);
    notifyListeners();
    String? error;
    try {
      if (saved) {
        await _service.removeFavorite(id);
        _favorites = List.unmodifiable(_favorites.where((f) => f.id != id));
      } else {
        await _service.addFavorite(type, itemId);
        _favorites = List.unmodifiable(
            [..._favorites, Favorite(id: id, type: type, itemId: itemId)]);
      }
    } on ApiException catch (e) {
      error = e.message;
    }
    _pending.remove(id);
    notifyListeners();
    return error;
  }

  /// Tải chi tiết các mục đã lưu cho màn hình "Đã lưu". Dùng GET /:id nên
  /// vẫn xem được mục đã ngừng hoạt động. Mục đã bị xóa hẳn thì bỏ qua.
  Future<SavedCatalogItems> loadSavedItems() async {
    await loadFavorites();
    if (_favoritesError != null) throw ApiException(_favoritesError!);
    Future<T?> fetch<T>(Future<T> Function() get) async {
      try {
        return await get();
      } on ApiException catch (e) {
        if (e.kind == ApiErrorKind.notFound) return null;
        rethrow;
      }
    }

    final services = <Future<DentalService?>>[];
    final doctors = <Future<Doctor?>>[];
    for (final f in _favorites) {
      switch (f.type) {
        case 'service':
          services.add(fetch(() => _service.getService(f.itemId)));
        case 'combo':
          services.add(fetch(() => _service.getCombo(f.itemId)));
        case 'doctor':
          doctors.add(fetch(() => _service.getDoctor(f.itemId)));
        // 'article': bài viết vẫn là mock của module Nội dung, chưa hiện ở đây.
      }
    }
    return SavedCatalogItems(
      services: (await Future.wait(services)).nonNulls.toList(),
      doctors: (await Future.wait(doctors)).nonNulls.toList(),
    );
  }

  /// Gọi khi đăng xuất để người dùng sau không thấy dữ liệu người trước.
  void clear() {
    _session++;
    _favorites = const [];
    _favoritesLoading = false;
    _favoritesLoaded = false;
    _favoritesError = null;
    _pending.clear();
    notifyListeners();
  }
}

class SavedCatalogItems {
  final List<DentalService> services;
  final List<Doctor> doctors;
  const SavedCatalogItems({required this.services, required this.doctors});
}
