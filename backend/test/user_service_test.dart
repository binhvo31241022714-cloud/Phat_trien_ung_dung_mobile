import 'package:backend/core/app_exception.dart';
import 'package:backend/repositories/user_repository.dart';
import 'package:backend/services/user_service.dart';
import 'package:test/test.dart';

void main() {
  late UserService service;

  setUp(() => service = UserService(UserRepository()));

  test('tạo user hợp lệ', () {
    final user = service.create({'name': 'An', 'email': 'an@example.com'});
    expect(user.id, 1);
    expect(service.getAll(), hasLength(1));
  });

  test('báo lỗi khi email sai định dạng', () {
    expect(
      () => service.create({'name': 'An', 'email': 'sai-email'}),
      throwsA(isA<AppException>()),
    );
  });

  test('báo lỗi khi email bị trùng', () {
    service.create({'name': 'An', 'email': 'an@example.com'});
    expect(
      () => service.create({'name': 'Bình', 'email': 'an@example.com'}),
      throwsA(isA<AppException>()),
    );
  });

  test('cập nhật và xoá user', () {
    final user = service.create({'name': 'An', 'email': 'an@example.com'});
    expect(service.update(user.id, {'name': 'An Nguyễn'}).name, 'An Nguyễn');
    service.delete(user.id);
    expect(service.getAll(), isEmpty);
  });
}
