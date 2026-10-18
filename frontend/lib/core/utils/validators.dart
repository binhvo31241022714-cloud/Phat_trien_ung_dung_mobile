class Validators {
  static String? required(String? value, {String field = 'Trường này'}) {
    if (value == null || value.trim().isEmpty) return '$field không được để trống';
    return null;
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
