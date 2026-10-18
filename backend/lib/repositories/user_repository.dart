import '../models/user.dart';

/// Lưu dữ liệu tạm trong bộ nhớ. Thay bằng database (PostgreSQL, MySQL,
/// MongoDB...) khi cần, giữ nguyên các method để service không phải sửa.
class UserRepository {
  final Map<int, User> _store = {};
  int _nextId = 1;

  List<User> findAll() => _store.values.toList();

  User? findById(int id) => _store[id];

  User? findByEmail(String email) {
    for (final user in _store.values) {
      if (user.email == email) return user;
    }
    return null;
  }

  User create({required String name, required String email}) {
    final user = User(
      id: _nextId++,
      name: name,
      email: email,
      createdAt: DateTime.now(),
    );
    _store[user.id] = user;
    return user;
  }

  User update(User user) => _store[user.id] = user;

  bool delete(int id) => _store.remove(id) != null;
}
