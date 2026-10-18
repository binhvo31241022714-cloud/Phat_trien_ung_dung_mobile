import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/validators.dart';

void main() {
  test('email hợp lệ', () {
    expect(Validators.email('an@example.com'), isNull);
  });

  test('email sai định dạng', () {
    expect(Validators.email('sai-email'), isNotNull);
  });

  test('bắt buộc nhập', () {
    expect(Validators.required('  '), isNotNull);
  });
}
