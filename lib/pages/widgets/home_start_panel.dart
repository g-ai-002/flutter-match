import 'package:flutter/material.dart';

import '../../game/achievements.dart';
import '../../game/daily_challenge.dart';
import '../../game/levels.dart';
import '../../models/level.dart';
import '../../providers/settings_provider.dart';
import '../../theme/palette.dart';
import 'entry_tile.dart';
import 'star_progress.dart';
import 'star_row.dart';

/// 首页主行动区：继续闯关、每日挑战、关卡选择、设置、成就与福星总进度。
class HomeStartPanel extends StatelessWidget {
  const HomeStartPanel({
    super.key,
    required this.settings,
    required this.unlocked,
    required this.cleared,
    required this.totalStars,
    required this.daily,
    required this.onStart,
    required this.onStartDaily,
    required this.onOpenLevels,
    required this.onOpenSettings,
    required this.onOpenAchievements,
  });

  final SettingsProvider settings;
  final int unlocked;
  final int cleared;
  final int totalStars;
  final DailyChallenge daily;
  final ValueChanged<Level> onStart;
  final VoidCallback onStartDaily;
  final VoidCallback onOpenLevels;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenAchievements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final level = levelById(unlocked);
    final bestStars = settings.starsFor(level.id);
    final maxStars = kLevels.length * 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContinueCard(
          level: level,
          unlocked: unlocked,
          stars: bestStars,
          onTap: () => onStart(level),
        ),
        const SizedBox(height: 10),
        _DailyCard(
          daily: daily,
          stars: settings.dailyStars(daily.dateKey),
          bestScore: settings.dailyBestScore(daily.dateKey),
          onTap: onStartDaily,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final levels = EntryTile(
              leading: const EntryBadge(
                icon: Icons.grid_view_rounded,
                accent: appRed,
              ),
              title: '关卡选择',
              subtitle: '${kLevels.length} 关 · 已通关 $cleared',
              onTap: onOpenLevels,
            );
            final settingsTile = EntryTile(
              leading: const EntryBadge(
                icon: Icons.tune_rounded,
                accent: appJade,
              ),
              title: '设置',
              subtitle: '音效 · 刷新率',
              onTap: onOpenSettings,
            );
            if (constraints.maxWidth < 460) {
              return Column(
                children: [levels, const SizedBox(height: 10), settingsTile],
              );
            }
            return Row(
              children: [
                Expanded(child: levels),
                const SizedBox(width: 12),
                Expanded(child: settingsTile),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        EntryTile(
          leading: const EntryBadge(
            icon: Icons.workspace_premium_rounded,
            accent: appGoldDark,
          ),
          title: '成就',
          subtitle:
              '已解锁 ${unlockedAchievementCount(settings.playerStats(kLevels.length))}'
              ' / ${kAchievements.length}',
          onTap: onOpenAchievements,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              const Icon(Icons.star_rounded, size: 18, color: appGoldBright),
              const SizedBox(width: 6),
              Text(
                '$totalStars / $maxStars',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StarProgressBar(
                  value: maxStars == 0 ? 0 : totalStars / maxStars,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 每日挑战入口：今日目标、当日成绩与挑战按钮。
class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.daily,
    required this.stars,
    required this.bestScore,
    required this.onTap,
  });

  final DailyChallenge daily;
  final int stars;
  final int bestScore;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final done = stars > 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: appJade.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: appJade.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: appJade.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  size: 20,
                  color: appJade,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('每日挑战', style: theme.textTheme.titleSmall),
                        const SizedBox(width: 6),
                        Text(
                          daily.level.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10.5,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      done ? '今日最佳 $bestScore 分' : daily.goalSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (done)
                StarRow(stars: stars, size: 15, spacing: 1)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: appJade,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '去挑战',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 继续闯关主按钮：显示当前解锁关卡与已获星级。
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.level,
    required this.unlocked,
    required this.stars,
    required this.onTap,
  });

  final Level level;
  final int unlocked;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [appRedBright, appRedDeep],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x338C2F24),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E3BF).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFFFF3DE),
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '开始闯关',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFFFF6E8),
                        fontSize: 19,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '第 $unlocked 关 · ${level.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFF3D6B4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StarRow(stars: stars, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
