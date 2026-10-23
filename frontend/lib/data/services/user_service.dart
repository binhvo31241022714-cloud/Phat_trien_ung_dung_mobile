import '../../core/config/app_config.dart';
import '../repositories/user_read_repository.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

/// Gọi các API /api/users của backend.
class UserService {
  final ApiClient _api;

  final UserReadRepository _repository;
  final bool _apiMode;

  UserService(
      {ApiClient? api, AppConfig? config, UserReadRepository? repository})
      : this._(
            api ?? ApiClient(baseUrl: (config ?? AppConfig.current).apiBaseUrl),
            config ?? AppConfig.current,
            repository);

  UserService._(this._api, AppConfig config, UserReadRepository? repository)
      : _repository = repository ?? createUserReadRepository(config, _api),
        _apiMode = config.dataSource == DataSource.api;

  Future<List<UserModel>> getAll() => _repository.getAll();

  void _requireApi() {
    if (!_apiMode) {
      throw const ApiException('CRUD user chưa được hỗ trợ trong Mock Mode.');
    }
  }

  void close() => _api.close();

  Future<UserModel> create(String name, String email) async {
    _requireApi();
    final data =
        await _api.post(ApiConstants.users, {'name': name, 'email': email});
    return UserModel.fromJson(data);
  }

  Future<UserModel> update(int id, String name, String email) async {
    _requireApi();
    final data = await _api
        .put('${ApiConstants.users}/$id', {'name': name, 'email': email});
    return UserModel.fromJson(data);
  }

  Future<void> delete(int id) async {
    _requireApi();
    await _api.delete('${ApiConstants.users}/$id');
  }
}
