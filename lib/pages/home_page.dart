import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/levels.dart';
import '../models/level.dart';
import '../models/tile.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../theme/tile_art.dart';
import '../utils/constants.dart';
import 'game_page.dart';
import 'level_select_page.dart';
import 'settings_page.dart';
import 'widgets/entry_tile.dart';
import 'widgets/star_row.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final totalStars = settings.totalStars(kLevels.length);
    final unlocked = settings.unlockedLevel.clamp(1, kLevels.length);
    final cleared = _clearedCount(settings);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xFF241C15), Color(0xFF120F0A)]
                : const [Color(0xFFFDF7EA), Color(0xFFF3E4C8)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth >= 900 && constraints.maxHeight >= 620;
              final horizontal = constraints.maxWidth >= 900 ? 40.0 : 20.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 22),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Column(
                      children: [
                        _TopBar(darkMode: settings.darkMode),
                        const SizedBox(height: 10),
                        if (wide)
                          Row(
                            children: [
                              const Expanded(child: _Hero()),
                              const SizedBox(width: 44),
                              SizedBox(
                                width: 420,
                                child: _StartPanel(
                                  settings: settings,
                                  unlocked: unlocked,
                                  cleared: cleared,
                                  totalStars: totalStars,
                                ),
                              ),
                            ],
                          )
                        else ...[
                          const _Hero(),
                          const SizedBox(height: 24),
                          _StartPanel(
                            settings: settings,
                            unlocked: unlocked,
                            cleared: cleared,
                            totalStars: totalStars,
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'v${AppConstants.version} · 本地运行，无需联网',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _clearedCount(SettingsProvider settings) {
    var count = 0;
    for (final level in kLevels) {
      if (settings.starsFor(level.id) > 0) count++;
    }
    return count;
  }
}

void _openGame(BuildContext context, Level level) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => GamePage(level: level)),
  );
}

void _openLevels(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const LevelSelectPage()));
}

void _openSettings(BuildContext context) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.darkMode});

  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.primary, width: 1.3),
          ),
          child: const TileBadge(type: TileType.coin),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                'FORTUNE MATCH',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1.6,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '玩法说明',
          onPressed: () => _showRules(context),
          icon: const Icon(Icons.help_outline_rounded, size: 21),
        ),
        IconButton(
          tooltip: darkMode ? '切换浅色' : '切换深色',
          onPressed: () => settings.setDarkMode(!darkMode),
          icon: Icon(
            darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 21,
          ),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: () => _openSettings(context),
          icon: const Icon(Icons.settings_outlined, size: 21),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        const _TileFan(),
        const SizedBox(height: 18),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 40,
            letterSpacing: 8,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OrnamentLine(color: colors.outline),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '三 消 成 趣 · 福 运 连 连',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 2,
                  ),
                ),
              ),
              _OrnamentLine(color: colors.outline),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '交换相邻棋子，连成三枚即可消除',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 五枚棋子的扇形陈列，作为首页主视觉。
class _TileFan extends StatelessWidget {
  const _TileFan();

  static const List<(TileType, double, double)> _layout = [
    (TileType.lantern, 44, -0.13),
    (TileType.jade, 52, -0.07),
    (TileType.coin, 62, 0),
    (TileType.porcelain, 52, 0.07),
    (TileType.lotus, 44, 0.13),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < _layout.length; index++)
            Transform.translate(
              offset: Offset((index - 2) * 46.0, (index - 2).abs() * 5.0),
              child: Transform.rotate(
                angle: _layout[index].$3,
                child: TileBadge(
                  type: _layout[index].$1,
                  size: _layout[index].$2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 主行动区：continue、关卡选择与设置。
class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.settings,
    required this.unlocked,
    required this.cleared,
    required this.totalStars,
  });

  final SettingsProvider settings;
  final int unlocked;
  final int cleared;
  final int totalStars;

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
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openGame(context, level),
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
                  StarRow(stars: bestStars, size: 16),
                ],
              ),
            ),
          ),
        ),
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
              onTap: () => _openLevels(context),
            );
            final settingsTile = EntryTile(
              leading: const EntryBadge(
                icon: Icons.tune_rounded,
                accent: Color(0xFF3F6B5B),
              ),
              title: '设置',
              subtitle: '音效 · 刷新率',
              onTap: () => _openSettings(context),
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
              Text(
                '$totalStars / $maxStars',
                style: theme.textTheme.titleSmall,
              ),
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

class _OrnamentLine extends StatelessWidget {
  const _OrnamentLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 40, height: 1, color: color.withValues(alpha: 0.9));
  }
}

void _showRules(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text('玩法说明'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final rule in const [
              ('交换', '点击或滑动交换相邻棋子，横竖连成三枚同色即可消除。'),
              ('连锁', '消除后上方棋子落下补充，连锁消除分数更高。'),
              ('特殊', '四连生成横扫或竖贯，拐角五连生成爆珠，五连生成福珠。'),
              ('目标', '在步数用尽前完成关卡目标；剩余步数越多越容易拿满三星。'),
            ]) ...[
              Text(rule.$1, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(rule.$2, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('明白了'),
          ),
        ],
      );
    },
  );
}
