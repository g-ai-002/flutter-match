import 'package:flutter/material.dart';

import '../../game/levels.dart';
import '../../models/level.dart';
import '../../providers/settings_provider.dart';
import 'entry_tile.dart';
import 'star_row.dart';

/// 首页主行动区：继续闯关、关卡选择、设置与福星总进度。
class HomeStartPanel extends StatelessWidget {
  const HomeStartPanel({
    super.key,
    required this.settings,
    required this.unlocked,
    required this.cleared,
    required this.totalStars,
    required this.onStart,
    required this.onOpenLevels,
    required this.onOpenSettings,
  });

  final SettingsProvider settings;
  final int unlocked;
  final int cleared;
  final int totalStars;
  final ValueChanged<Level> onStart;
  final VoidCallback onOpenLevels;
  final VoidCallback onOpenSettings;

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
        _ContinueCard(level: level, unlocked: unlocked, stars: bestStars, onTap: () => onStart(level)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final levels = EntryTile(
              leading: const EntryBadge(
                icon: Icons.grid_view_rounded,
                accent: Color(0xFFA63A2B),
              ),
              title: '关卡选择',
              subtitle: '${kLevels.length} 关 · 已通关 $cleared',
              onTap: onOpenLevels,
            );
            final settingsTile = EntryTile(
              leading: const EntryBadge(
                icon: Icons.tune_rounded,
                accent: Color(0xFF3F6B5B),
              ),
              title: '设置',
              subtitle: '音效 · 刷新率',
              onTap: onOpenSettings,
            );
            if (constraints.maxWidth < 460) {
              return Column(
                children: [
                  levels,
                  const SizedBox(height: 10),
                  settingsTile,
                ],
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
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: Color(0xFFE9B44C),
              ),
              const SizedBox(width: 6),
              Text('$totalStars / $maxStars', style: theme.textTheme.titleSmall),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: maxStars == 0 ? 0 : totalStars / maxStars,
                    minHeight: 6,
                    backgroundColor: colors.outline.withValues(alpha: 0.4),
                    color: const Color(0xFFD9985C),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
              colors: [Color(0xFFB0422F), Color(0xFF8C2F24)],
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
