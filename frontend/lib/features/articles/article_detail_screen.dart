import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/article.dart';
import '../../data/providers/patient_data_provider.dart';

class ArticleDetailScreen extends StatelessWidget {
  const ArticleDetailScreen({required this.article, super.key});
  final Article article;
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    final saved = data.savedArticleIds.contains(article.id);
    return ListView(padding: const EdgeInsets.all(16), children: [
      AppCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(article.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(
            '${article.category} · ${formatVietnameseDate(article.publishedAt)} · ${article.readingMinutes} phút',
            style: const TextStyle(color: Color(0xFF666666))),
        const SizedBox(height: 16),
        Text(article.body),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: () => data.toggleSavedArticle(article.id),
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
            label: Text(saved ? 'Đã lưu · Bỏ lưu' : 'Lưu để xem sau')),
      ]))
    ]);
  }
}
