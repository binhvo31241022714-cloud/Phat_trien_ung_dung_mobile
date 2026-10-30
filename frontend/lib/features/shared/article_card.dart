import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../data/models/article.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onTap;
  final bool isSaved;
  final VoidCallback? onToggleSaved;

  const ArticleCard({
    required this.article,
    this.onTap,
    this.isSaved = false,
    this.onToggleSaved,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 144,
              width: double.infinity,
              child: article.imageUrl != null
                  ? Image.network(article.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ArticlePlaceholder())
                  : article.imageAsset == null
                      ? const _ArticlePlaceholder()
                      : Image.asset(
                          article.imageAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const _ArticlePlaceholder(),
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: StatusChip(
                          label: article.category,
                          tone: StatusTone.info,
                        ),
                      ),
                    ),
                    if (onToggleSaved != null)
                      IconButton(
                        tooltip: isSaved ? 'Bỏ lưu bài viết' : 'Lưu bài viết',
                        onPressed: onToggleSaved,
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  article.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  article.summary,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  [
                    if (article.hasPublishedDate)
                      formatVietnameseDate(article.publishedAt),
                    if (article.readingMinutes != null)
                      '${article.readingMinutes} phút đọc'
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticlePlaceholder extends StatelessWidget {
  const _ArticlePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.accent,
      child: Center(
        child: Icon(
          Icons.menu_book_outlined,
          color: AppColors.primary,
          size: 40,
        ),
      ),
    );
  }
}
