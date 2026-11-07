import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/achievements.dart';
import '../game/levels.dart';
import '../providers/settings_provider.dart';
import '../theme/palette.dart';
import 'widgets/star_progress.dart';

/// 成就页：展示累计进度与全部成就的解锁状态。
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final statuses = settings.achievements(kLevels.length);
    final unlocked = statuses.where((status) => status.unlocked).length;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('成就')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.outline.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.workspace_premium_rounded,
                            size: 20,
                            color: appGoldBright,
                          ),
                          const SizedBox(width: 8),
                          Text('已解锁成就', style: theme.textTheme.titleSmall),
                          const Spacer(),
                          Text(
                            '$unlocked / ${statuses.length}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      StarProgressBar(
                        value: statuses.isEmpty
                            ? 0
                            : unlocked / statuses.length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (final status in statuses) ...[
                  _AchievementCard(status: status),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.status});

  final AchievementStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final unlocked = status.unlocked;
    final accent = unlocked ? appGoldBright : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? appGold.withValues(alpha: 0.65)
              : colors.outline.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: unlocked ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              _iconFor(status.achievement.metric),
              size: 21,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      status.achievement.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: unlocked
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (unlocked)
                      Text(
                        '已解锁',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: appGoldDeep,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  status.achievement.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Expanded(
                      child: StarProgressBar(value: status.progress, height: 4),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${status.value.clamp(0, status.achievement.target)}'
                      ' / ${status.achievement.target}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(AchievementMetric metric) => switch (metric) {
  AchievementMetric.cleared => Icons.flag_rounded,
  AchievementMetric.perfect => Icons.workspace_premium_rounded,
  AchievementMetric.stars => Icons.star_rounded,
  AchievementMetric.dailyClears => Icons.event_available_rounded,
  AchievementMetric.maxCombo => Icons.bolt_rounded,
  AchievementMetric.iceBroken => Icons.ac_unit_rounded,
  AchievementMetric.propsUsed => Icons.handyman_rounded,
};
