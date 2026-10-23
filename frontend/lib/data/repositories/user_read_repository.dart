import '../../core/config/app_config.dart';
import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

/// Legacy users are not patients or authenticated accounts.
abstract interface class UserReadRepository {
  Future<List<UserModel>> getAll();
}

class MockUserReadRepository implements UserReadRepository {
  // There were no demo CRUD users; do not invent patient/account mappings.
  final List<UserModel> users;
  const MockUserReadRepository({this.users = const []});
  @override
  Future<List<UserModel>> getAll() async => List.unmodifiable(users);
}

class ApiUserReadRepository implements UserReadRepository {
  final ApiClient api;
  ApiUserReadRepository(this.api);
  @override
  Future<List<UserModel>> getAll() async {
    final data = await api.get(ApiConstants.users);
    if (data is! List) {
      throw const ApiException('Danh sách user không đúng hợp đồng dữ liệu.');
    }
    try {
      return List.unmodifiable(data.map((row) {
        if (row is! Map<String, dynamic>) throw const FormatException();
        return UserModel.fromJson(row);
      }));
    } on FormatException {
      throw const ApiException('Dữ liệu user không đúng hợp đồng.');
    }
  }
}

UserReadRepository createUserReadRepository(AppConfig config, ApiClient api) =>
    config.dataSource == DataSource.api
        ? ApiUserReadRepository(api)
        : const MockUserReadRepository();
