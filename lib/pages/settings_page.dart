import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/levels.dart';
import '../game/logic_rate.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/platform_info.dart';
import 'widgets/section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SectionCard(
                  title: '对局',
                  icon: Icons.tune_rounded,
                  children: [
                    Text(
                      '动画更新速率',
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '固定步长推进消除与下落动画，渲染仍按屏幕刷新绘制。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final rate in LogicRate.values)
                          ChoiceChip(
                            label: Text(rate.label),
                            selected: settings.logicRate == rate,
                            onSelected: (_) => settings.setLogicRate(rate),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '音效与反馈',
                  icon: Icons.graphic_eq_rounded,
                  children: [
                    _SwitchRow(
                      title: '游戏音效',
                      subtitle: '交换、消除、破冰与结算音效均为运行时合成',
                      value: settings.soundEnabled,
                      onChanged: settings.setSoundEnabled,
                      switchKey: const ValueKey('switch-sound'),
                    ),
                    const SizedBox(height: 10),
                    _SwitchRow(
                      title: '背景音乐',
                      subtitle: '五声音阶循环，可随时关闭',
                      value: settings.musicEnabled,
                      onChanged: settings.setMusicEnabled,
                      switchKey: const ValueKey('switch-music'),
                    ),
                    const SizedBox(height: 10),
                    _SwitchRow(
                      title: '震动反馈',
                      subtitle: '消除与连锁时给出不同强度的触感',
                      value: settings.hapticsEnabled,
                      onChanged: settings.setHapticsEnabled,
                      switchKey: const ValueKey('switch-haptics'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '外观',
                  icon: Icons.palette_outlined,
                  children: [
                    _SwitchRow(
                      title: '深色模式',
                      subtitle: '暖墨底色，夜间游戏更舒适',
                      value: settings.darkMode,
                      onChanged: settings.setDarkMode,
                      switchKey: const ValueKey('switch-dark'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '主题皮肤',
                  icon: Icons.auto_awesome_outlined,
                  children: [
                    Text(
                      '累计福星解锁新配色，棋子与场景会一起替换。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final skin in AppSkin.values)
                          _SkinCard(
                            skin: skin,
                            selected: settings.skin == skin,
                            locked:
                                settings.totalStars(kLevels.length) <
                                skin.requiredStars,
                            onTap: () => _selectSkin(context, settings, skin),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '关卡进度',
                  icon: Icons.emoji_events_outlined,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '已解锁 ${settings.unlockedLevel.clamp(1, kLevels.length)} / '
                            '${kLevels.length} 关，'
                            '福星 ${settings.totalStars(kLevels.length)} 颗',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => _confirmReset(context, settings),
                          child: const Text('重置进度'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '运行日志',
                  icon: Icons.receipt_long_outlined,
                  children: [
                    FutureBuilder<String>(
                      future: FileSystemService.instance.getLogRootPath(),
                      builder: (context, snapshot) {
                        final path = snapshot.data ?? '';
                        final text = path.isEmpty ? '当前平台日志仅保留在内存中' : path;
                        return SelectableText(
                          text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: () => _showLogs(context),
                          child: const Text('查看最近日志'),
                        ),
                        if (isDesktopPlatform)
                          OutlinedButton(
                            onPressed: () => _openLogDir(context),
                            child: const Text('打开日志目录'),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '关于',
                  icon: Icons.info_outline_rounded,
                  children: [
                    Text(
                      '${AppConstants.appName} v${AppConstants.version}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '国风三消闯关游戏，全部内容本地运行，无需联网。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openLogDir(BuildContext context) async {
    final path = await FileSystemService.instance.getLogRootPath();
    if (path.isEmpty) return;
    final opened = await FileSystemService.instance.openDirectory(path);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('无法打开日志目录')));
    }
  }

  void _showLogs(BuildContext context) {
    final logs = LogService.getRecentLogs(150);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('最近日志'),
        content: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.72,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              logs.isEmpty ? '暂无日志' : logs.join('\n'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _selectSkin(
    BuildContext context,
    SettingsProvider settings,
    AppSkin skin,
  ) {
    if (settings.totalStars(kLevels.length) < skin.requiredStars) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('累计收集 ${skin.requiredStars} 颗福星后解锁')),
      );
      return;
    }
    settings.setSkin(skin);
    LogService.info('切换主题皮肤：${skin.label}');
  }

  void _confirmReset(BuildContext context, SettingsProvider settings) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置关卡进度？'),
        content: const Text('将清空全部通关星级、最高分与解锁记录，设置项保持不变。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              settings.resetProgress();
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final AppSkin skin;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final spec = kSkinSpecs[skin]!;
    final swatches = spec.tiles.values.take(4).toList();
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 156,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? appGoldBright
                  : colors.outline.withValues(alpha: 0.8),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final palette in swatches)
                    Container(
                      width: 15,
                      height: 15,
                      margin: const EdgeInsets.only(right: 3),
                      decoration: BoxDecoration(
                        color: palette.base,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: palette.deep.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: appGoldDark,
                    )
                  else if (locked)
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                skin.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 2),
              Text(
                locked ? '${skin.requiredStars} 福星解锁' : skin.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.switchKey,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Key switchKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11.5,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Switch(key: switchKey, value: value, onChanged: onChanged),
      ],
    );
  }
}
