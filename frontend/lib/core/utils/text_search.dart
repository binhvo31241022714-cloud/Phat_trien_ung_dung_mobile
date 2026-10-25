// Tìm kiếm không phân biệt dấu và hoa thường: "cao rang" khớp "Lấy cao răng".

const _groups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _plain = {
  for (final entry in _groups.entries)
    for (final char in entry.value.split('')) char: entry.key,
};

/// Viết thường, bỏ dấu tiếng Việt, gộp khoảng trắng thừa.
String foldVietnamese(String text) => text
    .toLowerCase()
    .split('')
    .map((c) => _plain[c] ?? c)
    .join()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// [query] rỗng thì luôn khớp.
bool matchesSearch(String text, String query) {
  final q = foldVietnamese(query);
  return q.isEmpty || foldVietnamese(text).contains(q);
}
