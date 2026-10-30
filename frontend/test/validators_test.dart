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

  test('số điện thoại hợp lệ được chuẩn hóa thành 9-11 chữ số cho máy chủ', () {
    const cases = {
      '0912345678': '0912345678',
      '0912 345 678': '0912345678',
      '0912.345.678': '0912345678',
      '(091) 234-5678': '0912345678',
      '+84912345678': '0912345678',
      '+84 912 345 678': '0912345678',
      '': '',
    };
    cases.forEach((input, expected) {
      expect(Validators.vietnamesePhone(input), isNull, reason: input);
      final phone = Validators.normalizePhone(input);
      expect(phone, expected, reason: input);
      // Quy tắc của backend (utils/profile.js): rỗng hoặc 9 đến 11 chữ số.
      expect(phone.isEmpty || RegExp(r'^\d{9,11}$').hasMatch(phone), isTrue,
          reason: input);
    });
  });
}
