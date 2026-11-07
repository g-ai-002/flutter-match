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
import '../utils/constants.dart';
import '../utils/immersive_landscape.dart';
import 'level_select_page.dart';
import 'widgets/game_hud.dart';
import 'widgets/prop_bar.dart';
import 'widgets/result_overlay.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.level});

  final Level level;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final SettingsProvider _settings;
  late final MatchController _controller;
  late final MatchGame _game;
  late final Widget _boardWidget;
  final ValueNotifier<bool> _darkMode = ValueNotifier(false);
  bool _resultSaved = false;
  bool _shuffleToastShown = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    final stock = PropStock({
      for (final kind in PropKind.values) kind: _settings.propCount(kind),
    });
    _controller = MatchController(
      level: widget.level,
      props: stock,
      seed: widget.level.dailySeed,
    )..onPropUsed = _persistProp;
    _game = MatchGame(
      controller: _controller,
      darkMode: _darkMode,
      logicRate: _settings.logicRate,
    );
    // 保持同一个 Widget 实例，setState 只重建 HUD，不触碰棋盘。
    _boardWidget = GameWidget(game: _game);
    _controller.addListener(_onControllerChanged);
    LogService.info(
      '进入关卡 ${widget.level.id}（${widget.level.name}），'
      '步数 ${widget.level.moves}，逻辑 ${_settings.logicRate.hz}Hz',
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
      _saveResult();
    }
    _showShuffleToastIfNeeded();
    setState(() {});
  }

  /// 通关结算：福币奖励、闯关进度或每日挑战成绩。
  void _saveResult() {
    final stars = _controller.stars;
    final score = _controller.score;
    unawaited(_settings.grantCoins(AppConstants.winCoins(stars)));
    if (widget.level.isDaily) {
      unawaited(_claimDaily(stars: stars, score: score));
      return;
    }
    unawaited(
      _settings.recordLevelResult(
        levelId: widget.level.id,
        stars: stars,
        score: score,
        levelCount: kLevels.length,
      ),
    );
    LogService.info(
      '关卡 ${widget.level.id} 记录成绩：$stars 星，$score 分，'
      '福币 +${AppConstants.winCoins(stars)}',
    );
  }

  Future<void> _claimDaily({required int stars, required int score}) async {
    final key = widget.level.dailyKey;
    if (key == null) return;
    final reward = await _settings.recordDailyResult(
      dateKey: key,
      stars: stars,
      score: score,
    );
    LogService.info('每日挑战 $key 记录成绩：$stars 星，$score 分，奖励 $reward 福币');
    if (!mounted || reward <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('每日挑战首次通关，额外奖励 $reward 福币')),
    );
  }

  void _persistProp(PropKind kind) {
    unawaited(_settings.setPropCount(kind, _controller.propCount(kind)));
  }

  void _onPropTap(PropKind kind) {
    if (_controller.propCount(kind) <= 0) {
      _openPropShop();
      return;
    }
    _controller.activateProp(kind);
  }

  void _openPropShop() {
    unawaited(
      showPropShop(
        context,
        settings: _settings,
        countOf: _controller.propCount,
        onBought: (kind) {
          _controller.addProp(kind);
          _persistProp(kind);
          LogService.info('购买道具 ${kind.label}，余额 ${_settings.coins} 福币');
        },
      ),
    );
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已经是最后一关啦')));
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GamePage(level: next)),
    );
  }

  /// 道具待命时的操作提示，与普通提示共用棋盘上方的悬浮条。
  String? get _propPrompt => switch (_controller.activeProp) {
    PropKind.hammer => '点击一枚棋子，用小锤敲掉它',
    PropKind.swap => '依次点击两枚棋子，交换它们',
    PropKind.shuffle => null,
    null => null,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasNext = nextLevelOf(widget.level.id) != null;
    final prompt = _propPrompt ?? (_controller.hint != null ? '试试交换闪动的两枚棋子' : null);

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
                      child: RepaintBoundary(child: _boardWidget),
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
                        propCount: _controller.propCount,
                        activeProp: _controller.activeProp,
                        onProp: _onPropTap,
                        onHint: _controller.canInteract
                            ? _controller.requestHint
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
                        daily: widget.level.isDaily,
                        onNext: _nextLevel,
                        onReplay: _restart,
                        onLevels: _goLevels,
                      ),
                    ),
                  if (_controller.canInteract && prompt != null)
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
                              prompt,
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
