// Hàm đọc JSON an toàn cho các model: trường thiếu, null hoặc sai kiểu
// đều trả về giá trị mặc định thay vì làm app lỗi.

String readString(Object? value) => value is String ? value.trim() : '';

int readInt(Object? value) => value is num ? value.round() : 0;

List<String> readStringList(Object? value) => value is List
    ? List.unmodifiable(value.whereType<String>())
    : const <String>[];

/// Đọc ngày dạng "2000-05-31" (hoặc ISO đầy đủ). Rỗng hoặc sai thì trả null.
DateTime? readDate(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  final date = DateTime.tryParse(value.trim());
  return date == null ? null : DateTime(date.year, date.month, date.day);
}

/// Ghi ngày gửi lên backend dạng "2000-05-31".
String writeDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
