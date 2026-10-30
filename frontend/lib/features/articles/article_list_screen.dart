import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/error_state.dart';
import '../../data/providers/patient_data_provider.dart';
import '../../providers/content_provider.dart';
import '../../providers/catalog_provider.dart';
import '../shared/catalog_navigation.dart';
import '../shared/article_card.dart';
import 'article_detail_screen.dart';

class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});
  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  bool get isApi => AppConfig.current.dataSource == DataSource.api;
  @override
  void initState() {
    super.initState();
    if (isApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ContentProvider>().loadArticles();
        if (context.read<ContentProvider>().signedIn) {
          context.read<CatalogProvider>().loadFavorites();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = isApi ? null : context.watch<PatientDataProvider>();
    final content = isApi ? context.watch<ContentProvider>() : null;
    final catalog = isApi ? context.watch<CatalogProvider>() : null;
    if (content != null) {
      if (content.loading('articles') ||
          !content.loaded.contains('articles') &&
              content.errors['articles'] == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (content.errors['articles'] != null) {
        return ErrorState(
            message: content.errors['articles']!,
            onRetry: content.loadArticles);
      }
    }
    final articles = isApi ? content!.articles : data!.articles;
    if (articles.isEmpty) return const Center(child: Text('Chưa có bài viết.'));
    if (isApi && catalog!.favoritesError != null) {
      return ErrorState(
          message: catalog.favoritesError!, onRetry: catalog.loadFavorites);
    }
    return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: articles.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final a = articles[index];
          return ArticleCard(
              article: a,
              isSaved: isApi
                  ? catalog!.isSaved('article', a.id)
                  : data!.savedArticleIds.contains(a.id),
              onToggleSaved: isApi &&
                      (catalog!.isPending('article', a.id) ||
                          catalog.favoritesLoading ||
                          catalog.favoritesError != null)
                  ? null
                  : () async {
                      if (!isApi) {
                        data!.toggleSavedArticle(a.id);
                        return;
                      }
                      if (!content!.signedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Vui lòng đăng nhập để lưu bài viết.')));
                        return;
                      }
                      final error =
                          await catalog!.toggleFavorite('article', a.id);
                      if (context.mounted && error != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(error)));
                      }
                    },
              onTap: () => CatalogNavigation.open(context, 'Chi tiết bài viết',
                  ArticleDetailScreen(article: a)));
        });
  }
}
