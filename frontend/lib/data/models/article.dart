class Article {
  final String id;
  final String title;
  final String summary;

  /// Optional plain-text body. Backend field/format is still to be agreed.
  final String? content;
  final String category;
  final DateTime publishedAt;
  final int readingMinutes;
  final String? imageAsset;

  const Article({
    required this.id,
    required this.title,
    required this.summary,
    this.content,
    required this.category,
    required this.publishedAt,
    required this.readingMinutes,
    this.imageAsset,
  });

  String get body {
    if (content != null && content!.trim().isNotEmpty) return content!;
    return summary.trim().isNotEmpty ? summary : 'Chưa có nội dung bài viết.';
  }
}
