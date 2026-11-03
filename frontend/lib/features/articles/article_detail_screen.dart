import '../../core/theme/app_tokens.dart';
import '../../core/constants/app_colors.dart';
import '../../core/config/app_config.dart';
import '../../core/widgets/error_state.dart';
import '../../providers/content_provider.dart';
import '../shared/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/article.dart';
import '../../data/providers/patient_data_provider.dart';

class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({required this.article, super.key});
  final Article article;
  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  bool get isApi => AppConfig.current.dataSource == DataSource.api;
  @override
  void initState() {
    super.initState();
    if (isApi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ContentProvider>().loadArticle(widget.article.id);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = isApi ? null : context.watch<PatientDataProvider>();
    final content = isApi ? context.watch<ContentProvider>() : null;
    final key = 'article:${widget.article.id}';
    if (content != null) {
      if (content.loading(key) ||
          !content.loaded.contains(key) && content.errors[key] == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (content.errors[key] != null) {
        return ErrorState(
            message: content.errors[key]!,
            onRetry: () => content.loadArticle(widget.article.id));
      }
    }
    final article =
        isApi ? content!.details[widget.article.id] : widget.article;
    if (article == null) {
      return ErrorState(
          message: 'Chưa tải được bài viết từ máy chủ.',
          onRetry: () => content!.loadArticle(widget.article.id));
    }
    final saved = !isApi && data!.savedArticleIds.contains(article.id);
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(padding: AppTokens.scrollInsets, children: [
              AppCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(article.title,
                        style: const TextStyle(
                            fontSize: 22,
                            height: 1.3,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                        [
                          article.category,
                          if (article.hasPublishedDate)
                            formatVietnameseDate(article.publishedAt),
                          if (article.readingMinutes != null)
                            '${article.readingMinutes} phút'
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    if (article.imageUrl != null)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.network(article.imageUrl!,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                              color: AppColors.accent,
                                              child: Center(
                                                  child: Icon(Icons
                                                      .menu_book_outlined))))))),
                    Text(article.body,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.65,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    if (isApi)
                      FavoriteButton(type: 'article', itemId: article.id)
                    else
                      OutlinedButton.icon(
                          onPressed: () => data!.toggleSavedArticle(article.id),
                          icon: Icon(
                              saved ? Icons.bookmark : Icons.bookmark_border),
                          label: Text(
                              saved ? 'Đã lưu · Bỏ lưu' : 'Lưu để xem sau')),
                  ]))
            ])));
  }
}
