import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

/// Gọi các API /api/users của backend.
class UserService {
  final ApiClient _api;

  UserService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<UserModel>> getAll() async {
    final data = await _api.get(ApiConstants.users) as List;
    return data.map((e) => UserModel.fromJson(e)).toList();
  }

  Future<UserModel> create(String name, String email) async {
    final data =
        await _api.post(ApiConstants.users, {'name': name, 'email': email});
    return UserModel.fromJson(data);
  }

  Future<UserModel> update(int id, String name, String email) async {
    final data = await _api
        .put('${ApiConstants.users}/$id', {'name': name, 'email': email});
    return UserModel.fromJson(data);
  }

  Future<void> delete(int id) => _api.delete('${ApiConstants.users}/$id');
}
