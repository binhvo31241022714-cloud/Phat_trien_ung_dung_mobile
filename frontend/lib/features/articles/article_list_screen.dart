import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/patient_data_provider.dart';
import '../shared/catalog_navigation.dart';
import '../shared/article_card.dart';
import 'article_detail_screen.dart';

class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final data = context.watch<PatientDataProvider>();
    if (data.articles.isEmpty) {
      return const Center(child: Text('Chưa có bài viết.'));
    }
    return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: data.articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final a = data.articles[index];
          return ArticleCard(
              article: a,
              isSaved: data.savedArticleIds.contains(a.id),
              onToggleSaved: () => data.toggleSavedArticle(a.id),
              onTap: () => CatalogNavigation.open(context, 'Chi tiết bài viết',
                  ArticleDetailScreen(article: a)));
        });
  }
}
