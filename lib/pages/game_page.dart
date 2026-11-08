import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../flame/match_game.dart';
import '../game/endless.dart';
import '../game/levels.dart';
import '../game/match_controller.dart';
import '../game/scoring.dart';
import '../models/level.dart';
import '../providers/settings_provider.dart';
import '../services/log_service.dart';
import '../theme/app_theme.dart';
import '../utils/immersive_landscape.dart';
import 'level_select_page.dart';
import 'widgets/game_hud.dart';
import 'widgets/prop_bar.dart';
import 'widgets/result_overlay.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.level, this.endless});

  final Level level;

  /// 无尽模式的本轮进度；闯关与每日挑战为 null。
  final EndlessRun? endless;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final SettingsProvider _settings;
  late final PropStock _stock;
  late final MatchController _controller;
  late final MatchGame _game;
  late final Widget _boardWidget;
  final ValueNotifier<bool> _darkMode = ValueNotifier(false);
  bool _endRecorded = false;
  bool _shuffleToastShown = false;

  /// 结算浮层的可见状态；只有它翻转时才重建页面骨架。
  bool _resultVisible = false;

  @override
  void initState() {
    super.initState();
    _settings = context.read<SettingsProvider>();
    _stock = PropStock({
      for (final kind in PropKind.values) kind: _settings.propCount(kind),
    }, (kind, count) => unawaited(_settings.setPropCount(kind, count)));
    _controller = MatchController(
      level: widget.level,
      props: _stock,
      seed: widget.level.dailySeed,
    );
    _game = MatchGame(
      controller: _controller,
      darkMode: _darkMode,
      logicRate: _settings.logicRate,
    );
    // 保持同一个 Widget 实例，setState 只重建 HUD，不触碰棋盘。
    _boardWidget = GameWidget(game: _game);
    _controller.addListener(_onControllerChanged);
    LogService.info(
      widget.level.isEndless
          ? '进入无尽模式第 ${widget.level.endlessStage} 层，'
                '步数 ${widget.level.moves}，逻辑 ${_settings.logicRate.hz}Hz'
          : '进入关卡 ${widget.level.id}（${widget.level.name}），'
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
    // 先停引擎并拆除棋盘，再释放控制器，离开对局页后不残留计时器与监听。
    _game.shutdown();
    _controller.dispose();
    _darkMode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller.isOver && !_endRecorded) {
      _endRecorded = true;
      unawaited(_recordEnd());
    }
    _showShuffleToastIfNeeded();
    // 动画期间分数与目标由 AnimatedBuilder 局部刷新，页面骨架只在结算浮层
    // 出现或消失时重建一次，避免每个消除步骤都跑一遍整页 build。
    final visible = _controller.isOver;
    if (visible != _resultVisible) {
      _resultVisible = visible;
      setState(() {});
    }
  }

  /// 对局结束结算：通关奖励、成就统计与本次新解锁的成就。
  Future<void> _recordEnd() async {
    final won = _controller.status == GameStatus.won;
    final before = _unlockedAchievementIds();
    var dailyReward = 0;
    final run = widget.endless;
    if (run != null) {
      // 无尽模式按层结算：通关记本层，失手也保留本轮累计分。
      final total = run.totalScore + _controller.score;
      final cleared = won ? run.stage : run.stage - 1;
      await _settings.recordEndless(stage: cleared, totalScore: total);
      LogService.info(
        '无尽模式第 ${run.stage} 层${won ? '通关' : '结束'}：'
        '${_controller.score} 分，累计 $total 分',
      );
    } else if (won) {
      dailyReward = await _settings.recordWin(
        level: widget.level,
        stars: _controller.stars,
        score: _controller.score,
        levelCount: kLevels.length,
      );
      if (widget.level.isDaily) {
        LogService.info(
          '每日挑战 ${widget.level.dailyKey} 记录成绩：'
          '${_controller.stars} 星，${_controller.score} 分，奖励 $dailyReward 福币',
        );
      } else {
        LogService.info(
          '关卡 ${widget.level.id} 记录成绩：${_controller.stars} 星，'
          '${_controller.score} 分，福币 +${ScoreRules.rewardCoins(_controller.stars)}',
        );
      }
    }
    await _settings.recordStats(
      maxCombo: _controller.bestCombo,
      iceBroken: _controller.iceBroken,
      propsUsed: _controller.propsUsed,
    );
    final unlocked = [
      for (final status in _settings.achievements)
        if (status.unlocked && !before.contains(status.achievement.id))
          status.achievement.title,
    ];
    if (unlocked.isNotEmpty) LogService.info('解锁成就：${unlocked.join('、')}');
    if (!mounted) return;
    final messages = [
      if (dailyReward > 0) '每日挑战首次通关，额外奖励 $dailyReward 福币',
      if (unlocked.isNotEmpty) '解锁成就：${unlocked.join('、')}',
    ];
    if (messages.isEmpty) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(messages.join('　'))));
  }

  Set<String> _unlockedAchievementIds() => {
    for (final status in _settings.achievements)
      if (status.unlocked) status.achievement.id,
  };

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
        stock: _stock,
        onBought: (kind) {
          setState(() {});
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
    if (widget.endless != null) {
      const run = EndlessRun();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GamePage(level: run.level, endless: run),
        ),
      );
      return;
    }
    _controller.restart();
    _endRecorded = false;
    _shuffleToastShown = false;
    LogService.info('重开关卡 ${widget.level.id}');
  }

  void _confirmRestart() {
    final endless = widget.endless != null;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(endless ? '重新开始挑战？' : '重开本关？'),
        content: Text(
          endless ? '累计分数将清空，回到第 1 层重新开始。' : '当前得分与进度将清空，步数恢复为关卡初始值。',
        ),
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
            child: Text(endless ? '重新开始' : '重开'),
          ),
        ],
      ),
    );
  }

  void _goLevels() {
    if (widget.endless != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LevelSelectPage()),
      (route) => route.isFirst,
    );
  }

  void _nextLevel() {
    final run = widget.endless;
    if (run != null) {
      final next = run.afterWin(_controller.score);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GamePage(level: next.level, endless: next),
        ),
      );
      return;
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasNext =
        widget.endless != null || nextLevelOf(widget.level.id) != null;

    return BoardDisplayMode(
      cols: widget.level.cols,
      rows: widget.level.rows,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: sceneGradient(isDark)),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < kBoardCompactHeight;
                // 上下留白对称，棋盘中心与屏幕中心重合；提示与按钮悬浮在留白里。
                final gap = boardGapFor(constraints.maxHeight);
                final side = compact ? 6.0 : 10.0;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: side,
                          vertical: gap,
                        ),
                        child: RepaintBoundary(child: _boardWidget),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _topHud(compact),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _bottomBar(compact),
                    ),
                    if (_resultVisible)
                      Positioned.fill(
                        child: ResultOverlay(
                          controller: _controller,
                          hasNext: hasNext,
                          daily: widget.level.isDaily,
                          endless: widget.endless != null,
                          totalScore:
                              (widget.endless?.totalScore ?? 0) +
                              _controller.score,
                          onNext: _nextLevel,
                          onReplay: _restart,
                          onLevels: _goLevels,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部信息只订阅控制器，动画期间不牵动页面骨架与棋盘。
  Widget _topHud(bool compact) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => GameTopHud(
      level: widget.level,
      controller: _controller,
      compact: compact,
      prompt: _promptBar,
    ),
  );

  /// 底部工具条同样局部重建，道具数量与待命状态随控制器即时刷新。
  Widget _bottomBar(bool compact) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => GameBottomBar(
      compact: compact,
      propCount: _controller.propCount,
      activeProp: _controller.activeProp,
      onProp: _onPropTap,
      onHint: _controller.canInteract ? _controller.requestHint : null,
      onRestart: _confirmRestart,
    ),
  );

  /// 棋盘上方左侧的操作提示；没有提示时留空，不影响棋盘与目标信息。
  String? get _promptBar {
    if (!_controller.canInteract) return null;
    return _propPrompt ?? (_controller.hint != null ? '试试交换闪动的两枚棋子' : null);
  }
}
