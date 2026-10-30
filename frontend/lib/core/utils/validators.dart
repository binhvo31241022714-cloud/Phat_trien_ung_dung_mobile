class Validators {
  static String? required(String? value, {String field = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field không được để trống';
    }
    return null;
  }

  static String? optionalEmail(String? value) =>
      value == null || value.trim().isEmpty ? null : email(value);
  /// Đưa số đã qua [vietnamesePhone] về dạng máy chủ nhận (chỉ chữ số):
  /// bỏ dấu cách, chấm, ngoặc, gạch ngang; +84 đổi thành 0.
  static String normalizePhone(String value) {
    final phone = value.replaceAll(RegExp(r'[\s.()-]'), '');
    return phone.startsWith('+84') ? '0${phone.substring(3)}' : phone;
  }

  static String? vietnamesePhone(String? value) {
    final phone = (value ?? '').replaceAll(RegExp(r'[\s.()-]'), '');
    if (phone.isEmpty) return null;
    return RegExp(r'^(0[35789]\d{8}|\+84[35789]\d{8})$').hasMatch(phone)
        ? null
        : 'Số điện thoại Việt Nam không hợp lệ';
  }

  static String? email(String? value) {
    final empty = required(value, field: 'Email');
    if (empty != null) return empty;
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(value!.trim())) {
      return 'Email không hợp lệ';
    }
    return null;
  }
}
