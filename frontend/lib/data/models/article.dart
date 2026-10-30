import 'content_date.dart';

class Article {
  final String id;
  final String title;
  final String summary;

  /// Optional plain-text content returned by the articles API.
  final String? content;
  final String category;
  final DateTime publishedAt;
  final int? readingMinutes;
  final String? imageUrl;
  final bool hasPublishedDate;
  final String? imageAsset;

  const Article({
    required this.id,
    required this.title,
    required this.summary,
    this.content,
    required this.category,
    required this.publishedAt,
    this.readingMinutes,
    this.imageUrl,
    this.hasPublishedDate = true,
    this.imageAsset,
  });

  factory Article.fromJson(Map<String, dynamic> j) {
    final date = contentDate(j['publishedAt']);
    String text(String k) => j[k] is String ? j[k] as String : '';
    return Article(
        id: text('id'),
        title: text('title'),
        summary: text('summary'),
        content: text('content'),
        category: text('category'),
        publishedAt: date ?? DateTime(1970),
        hasPublishedDate: date != null,
        imageUrl: text('imageUrl').isEmpty ? null : text('imageUrl'),
        readingMinutes: j['readingMinutes'] is num &&
                (j['readingMinutes'] as num).isFinite &&
                j['readingMinutes'] > 0
            ? (j['readingMinutes'] as num).round()
            : null);
  }

  String get body {
    if (content != null && content!.trim().isNotEmpty) return content!;
    return summary.trim().isNotEmpty ? summary : 'Chưa có nội dung bài viết.';
  }
}
