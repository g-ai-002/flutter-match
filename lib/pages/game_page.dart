import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/match_game.dart';
import '../game/levels.dart';
import '../game/match_controller.dart';
import '../models/level.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../utils/immersive_landscape.dart';
import 'level_select_page.dart';
import 'widgets/goal_chip.dart';
import 'widgets/hud_action_button.dart';
import 'widgets/star_row.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.level});

  final Level level;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final MatchController _controller;
  late final MatchGame _game;
  final ValueNotifier<bool> _darkMode = ValueNotifier(false);
  bool _resultSaved = false;
  bool _shuffleToastShown = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = MatchController(level: widget.level);
    _game = MatchGame(
      controller: _controller,
      darkMode: _darkMode,
      logicRate: settings.logicRate,
    );
    _controller.addListener(_onControllerChanged);
    LogService.info(
      '进入关卡 ${widget.level.id}（${widget.level.name}），'
      '步数 ${widget.level.moves}，逻辑 ${settings.logicRate.hz}Hz',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _darkMode.value = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _darkMode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.status == GameStatus.won && !_resultSaved) {
      _resultSaved = true;
      final settings = context.read<SettingsProvider>();
      unawaited(
        settings.recordLevelResult(
          levelId: widget.level.id,
          stars: _controller.stars,
          score: _controller.score,
          levelCount: kLevels.length,
        ),
      );
      LogService.info(
        '关卡 ${widget.level.id} 记录成绩：${_controller.stars} 星，'
        '${_controller.score} 分',
      );
    }
    if (_controller.status == GameStatus.ready && _controller.autoShuffled) {
      if (!_shuffleToastShown) {
        _shuffleToastShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无可消除组合，已自动重排棋盘'),
              duration: Duration(seconds: 2),
            ),
          );
        });
      }
    } else {
      _shuffleToastShown = false;
    }
    setState(() {});
  }

  void _restart() {
    _controller.restart();
    _resultSaved = false;
    _shuffleToastShown = false;
    LogService.info('重开关卡 ${widget.level.id}');
  }

  void _confirmRestart() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重开本关？'),
        content: const Text('当前得分与进度将清空，步数恢复为关卡初始值。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _restart();
            },
            child: const Text('重开'),
          ),
        ],
      ),
    );
  }

  void _goLevels() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LevelSelectPage()),
      (route) => route.isFirst,
    );
  }

  void _nextLevel() {
    final next = nextLevelOf(widget.level.id);
    if (next == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已经是最后一关啦')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GamePage(level: next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasNext = nextLevelOf(widget.level.id) != null;

    return BoardDisplayMode(
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [Color(0xFF241C15), Color(0xFF120F0A)]
                  : const [Color(0xFFFDF7EA), Color(0xFFF0DFC0)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 560;
              final topInset = compact ? 74.0 : 94.0;
              final bottomInset = compact ? 60.0 : 76.0;
              return Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 4 : 10,
                        topInset,
                        compact ? 4 : 10,
                        bottomInset,
                      ),
                      child: GameWidget(game: _game),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: _TopHud(
                        level: widget.level,
                        controller: _controller,
                        compact: compact,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      top: false,
                      child: _BottomBar(
                        compact: compact,
                        onHint: _controller.canInteract
                            ? _controller.requestHint
                            : null,
                        onShuffle: _controller.canInteract
                            ? _controller.shuffleBoard
                            : null,
                        onRestart: _confirmRestart,
                      ),
                    ),
                  ),
                  if (_controller.isOver)
                    Positioned.fill(
                      child: _ResultOverlay(
                        controller: _controller,
                        level: widget.level,
                        hasNext: hasNext,
                        onNext: _nextLevel,
                        onReplay: _restart,
                        onLevels: _goLevels,
                      ),
                    ),
                  if (_controller.canInteract && _controller.hint != null)
                    Positioned(
                      top: topInset + 4,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: colors.outline),
                            ),
                            child: Text(
                              '试试交换闪动的两枚棋子',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TopHud extends StatelessWidget {
  const _TopHud({
    required this.level,
    required this.controller,
    required this.compact,
  });

  final Level level;
  final MatchController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 14,
        compact ? 6 : 8,
        compact ? 8 : 14,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: '返回',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '第 ${level.id} 关 · ${level.sizeLabel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _MovesChip(moves: controller.movesLeft),
            ],
          ),
          SizedBox(height: compact ? 5 : 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final progress in controller.goalProgress)
                  GoalChip(progress: progress, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovesChip extends StatelessWidget {
  const _MovesChip({required this.moves});

  final int moves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final urgent = moves <= 5;
    final accent = urgent ? const Color(0xFFC0392B) : colors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent
              ? const Color(0xFFC0392B).withValues(alpha: 0.5)
              : colors.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 15, color: accent),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '剩余步数',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                '$moves',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 16,
                  height: 1.05,
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surface.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: colors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.compact,
    required this.onHint,
    required this.onShuffle,
    required this.onRestart,
  });

  final bool compact;
  final VoidCallback? onHint;
  final VoidCallback? onShuffle;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, compact ? 6 : 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HudActionButton(
            icon: Icons.lightbulb_outline_rounded,
            label: '提示',
            highlight: true,
            compact: compact,
            onPressed: onHint,
          ),
          SizedBox(width: compact ? 8 : 12),
          HudActionButton(
            icon: Icons.shuffle_rounded,
            label: '重排',
            compact: compact,
            onPressed: onShuffle,
          ),
          SizedBox(width: compact ? 8 : 12),
          HudActionButton(
            icon: Icons.refresh_rounded,
            label: '重开',
            compact: compact,
            onPressed: onRestart,
          ),
        ],
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.controller,
    required this.level,
    required this.hasNext,
    required this.onNext,
    required this.onReplay,
    required this.onLevels,
  });

  final MatchController controller;
  final Level level;
  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final won = controller.status == GameStatus.won;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.8),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: won
                          ? const [Color(0xFFE7B24B), Color(0xFFC47A24)]
                          : const [Color(0xFF9A8F80), Color(0xFF6B6258)],
                    ),
                  ),
                  child: Text(
                    won ? '福' : '叹',
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFF8EA),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  won ? '通关！' : '步数用尽',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  won
                      ? (hasNext ? '福运正旺，继续下一关吧' : '全部关卡已通关，福运圆满')
                      : '目标还没完成，调整思路再试一次',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                if (won) StarRow(stars: controller.stars, size: 34, spacing: 4),
                const SizedBox(height: 12),
                Text(
                  '${controller.score} 分',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFA63A2B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final progress in controller.goalProgress)
                      GoalChip(progress: progress),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReplay,
                        child: const Text('再来一局'),
                      ),
                    ),
                    if (won && hasNext) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onNext,
                          child: const Text('下一关'),
                        ),
                      ),
                    ] else if (!won) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onReplay,
                          child: const Text('再试一次'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onLevels,
                  child: const Text('返回关卡列表'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
