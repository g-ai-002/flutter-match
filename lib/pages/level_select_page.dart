import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/chapters.dart';
import '../game/levels.dart';
import '../models/level.dart';
import '../providers/settings_provider.dart';
import '../theme/palette.dart';
import 'game_page.dart';
import 'widgets/star_progress.dart';
import 'widgets/star_row.dart';

class LevelSelectPage extends StatelessWidget {
  const LevelSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = settings.progress;
    final chapters = chapterViews(progress);
    final maxStars = progress.maxStars;

    return Scaffold(
      appBar: AppBar(title: const Text('关卡选择')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.outline.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 19,
                            color: appGold,
                          ),
                          const SizedBox(width: 8),
                          Text('收集福星', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          Text(
                            '${progress.totalStars} / $maxStars',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: wide ? 180 : 90,
                            child: StarProgressBar(
                              value: maxStars == 0
                                  ? 0
                                  : progress.totalStars / maxStars,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                for (final view in chapters) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    sliver: SliverToBoxAdapter(
                      child: _ChapterHeader(
                        chapter: view.chapter,
                        stars: view.stars,
                        maxStars: view.maxStars,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 178,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final level = view.levels[index];
                        final unlocked = level.id <= progress.unlocked;
                        return _LevelCard(
                          level: level,
                          stars: progress.starsOf(level.id),
                          bestScore: settings.bestScoreFor(level.id),
                          unlocked: unlocked,
                          onTap: unlocked
                              ? () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => GamePage(level: level),
                                  ),
                                )
                              : null,
                        );
                      }, childCount: view.levels.length),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.chapter,
    required this.stars,
    required this.maxStars,
  });

  final Chapter chapter;
  final int stars;
  final int maxStars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 3,
          height: 30,
          decoration: BoxDecoration(
            color: appRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(chapter.title, style: theme.textTheme.titleSmall),
              Text(
                chapter.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.star_rounded, size: 15, color: appGoldBright),
        const SizedBox(width: 3),
        Text(
          '$stars / $maxStars',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.stars,
    required this.bestScore,
    required this.unlocked,
    required this.onTap,
  });

  final Level level;
  final int stars;
  final int bestScore;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final finished = stars > 0;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: finished
                  ? appGold.withValues(alpha: 0.7)
                  : colors.outline.withValues(alpha: 0.8),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: finished
                          ? appGold.withValues(alpha: 0.18)
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${level.id}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: finished ? appGoldDeep : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (!unlocked)
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    )
                  else
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 17,
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                level.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: unlocked ? colors.onSurface : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                bestScore > 0
                    ? '最高 $bestScore 分'
                    : '${level.moves} 步 · ${level.sizeLabel}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              StarRow(stars: stars, size: 17, spacing: 1),
            ],
          ),
        ),
      ),
    );
  }
}
