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
import '../theme/app_theme.dart';
import '../utils/immersive_landscape.dart';
import 'level_select_page.dart';
import 'widgets/game_hud.dart';
import 'widgets/result_overlay.dart';

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
    _showShuffleToastIfNeeded();
    setState(() {});
  }

  /// 死局自动重排时提示一次，直到棋盘恢复可操作才允许再次提示。
  void _showShuffleToastIfNeeded() {
    final shuffled =
        _controller.status == GameStatus.ready && _controller.autoShuffled;
    if (!shuffled) {
      _shuffleToastShown = false;
      return;
    }
    if (_shuffleToastShown) return;
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
          decoration: BoxDecoration(gradient: sceneGradient(isDark)),
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
                      child: GameTopHud(
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
                      child: GameBottomBar(
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
                      child: ResultOverlay(
                        controller: _controller,
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
