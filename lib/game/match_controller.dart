import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/level.dart';
import '../models/tile.dart';
import '../services/log_service.dart';
import '../services/sound_service.dart';
import 'board_step.dart';
import 'engine.dart';

/// 对局状态：可操作、动画中、胜利、失败。
enum GameStatus { ready, animating, won, lost }

/// 单条目标的实时进度。
class GoalProgress {
  const GoalProgress({required this.goal, required this.current});

  final LevelGoal goal;
  final int current;

  int get target => goal.target;

  bool get done => current >= target;

  double get ratio =>
      target <= 0 ? 1 : (current / target).clamp(0.0, 1.0).toDouble();

  String get display => '$current/$target';
}

/// 关卡控制器：衔接三消引擎、计分目标与 Flame 动画队列。
///
/// 引擎在交换时一次性算出整段连锁的动画脚本，Flame 组件逐条播放，
/// 每播完一条由组件回调 [onStepShown]，分数与目标进度随之推进。
class MatchController extends ChangeNotifier {
  MatchController({required this.level, int? seed})
    : _engine = MatchEngine(level: level, seed: seed),
      _movesLeft = level.moves;

  final Level level;
  final MatchEngine _engine;

  int _movesLeft;
  int _score = 0;
  int _iceBroken = 0;
  int _combo = 0;
  int _selected = -1;
  int _stars = 0;
  GameStatus _status = GameStatus.ready;
  SwapHint? _hint;
  Timer? _hintTimer;

  List<BoardStep> _pending = const [];
  int _epoch = 0;
  int _boardRevision = 0;
  bool _autoShuffled = false;

  final Map<TileType, int> _collected = {};

  GameBoard get board => _engine.board;
  int get movesLeft => _movesLeft;
  int get score => _score;
  int get combo => _combo;
  int get iceBroken => _iceBroken;
  GameStatus get status => _status;
  int get selected => _selected;
  SwapHint? get hint => _hint;
  int get stepEpoch => _epoch;
  int get boardRevision => _boardRevision;
  bool get autoShuffled => _autoShuffled;
  int get stars => _stars;
  int get levelId => level.id;

  bool get canInteract => _status == GameStatus.ready;

  bool get isOver => _status == GameStatus.won || _status == GameStatus.lost;

  bool get hasPendingSteps => _pending.isNotEmpty;

  int collectedCount(TileType type) => _collected[type] ?? 0;

  int progressValue(LevelGoal goal) => switch (goal.kind) {
    GoalKind.score => _score,
    GoalKind.collect => collectedCount(goal.type ?? TileType.coin),
    GoalKind.ice => _iceBroken,
  };

  List<GoalProgress> get goalProgress => [
    for (final goal in level.goals)
      GoalProgress(goal: goal, current: progressValue(goal)),
  ];

  bool get _allGoalsDone => level.goals.every(
    (goal) => progressValue(goal) >= goal.target,
  );

  /// 取出本轮待播放的步骤，由 Flame 组件持有。
  List<BoardStep> takeSteps() {
    final steps = List<BoardStep>.of(_pending);
    _pending = const [];
    return steps;
  }

  /// 点选棋子：首次选中，再点相邻棋子交换，点自身取消。
  void tapCell(int index) {
    if (!canInteract) return;
    if (board.tileAt(index) == null) return;
    if (_selected == index) {
      _selected = -1;
      notifyListeners();
      return;
    }
    if (_selected >= 0 && board.isAdjacent(_selected, index)) {
      final from = _selected;
      _selected = -1;
      swap(from, index);
      return;
    }
    _selected = index;
    _hint = null;
    SoundService.tap();
    notifyListeners();
  }

  /// 拖拽或滑动落子。
  void swipe(int from, int to) {
    if (!canInteract) return;
    if (!board.isAdjacent(from, to)) return;
    _selected = -1;
    swap(from, to);
  }

  /// 尝试交换，成功时扣一步并播放整段连锁，失败时播放回退动画。
  void swap(int a, int b) {
    if (!canInteract) return;
    _hint = null;
    _hintTimer?.cancel();
    final outcome = _engine.trySwap(a, b);
    _pending = outcome.steps;
    _status = GameStatus.animating;
    _epoch++;
    if (!outcome.valid) {
      SoundService.play(FeedbackKind.invalid);
    } else {
      _movesLeft--;
      SoundService.play(FeedbackKind.swap);
    }
    notifyListeners();
  }

  /// 组件每播放完一条消除步骤时回调，推进分数与目标进度。
  void onStepShown(BoardStep step) {
    if (step is! ClearStep) return;
    _combo = step.combo;
    final multiplier = step.combo.clamp(1, 6);
    var gained = step.tiles.length * 50 * multiplier;
    gained += step.specials.length * 150;
    for (final change in step.iceChanges) {
      if (change.broken) {
        _iceBroken++;
        gained += 100;
      }
    }
    _score += gained;
    for (final tile in step.tiles) {
      _collected[tile.type] = (_collected[tile.type] ?? 0) + 1;
    }
    notifyListeners();
  }

  /// 整段动画播完后收尾：判胜负、检查死局并自动重排。
  void finishAnimation() {
    if (_status != GameStatus.animating) return;
    _combo = 0;
    _pending = const [];
    _autoShuffled = false;
    if (_allGoalsDone) {
      final remaining = level.moves <= 0 ? 0.0 : _movesLeft / level.moves;
      _stars = remaining >= 0.34
          ? 3
          : remaining >= 0.12
          ? 2
          : 1;
      _status = GameStatus.won;
      LogService.info(
        '关卡 ${level.id} 通关: 分数 $score, 星级 $_stars, 剩余步数 $_movesLeft',
      );
      SoundService.play(FeedbackKind.win);
      notifyListeners();
      return;
    }
    if (_movesLeft <= 0) {
      _status = GameStatus.lost;
      LogService.info('关卡 ${level.id} 步数用尽: 分数 $score');
      SoundService.play(FeedbackKind.lose);
      notifyListeners();
      return;
    }
    _status = GameStatus.ready;
    if (_engine.findHint() == null) {
      _engine.shuffle();
      _boardRevision++;
      _autoShuffled = true;
      LogService.info('关卡 ${level.id} 无可消除组合，自动重排');
    }
    notifyListeners();
  }

  /// 无界面环境（测试）下一次推进完整段动画。
  void settleImmediately() {
    while (_pending.isNotEmpty) {
      onStepShown(_pending.first);
      _pending = _pending.sublist(1);
    }
    finishAnimation();
  }

  /// 提示：按当前目标挑选收益最高的交换，3.5 秒后自动消失。
  void requestHint() {
    if (!canInteract) return;
    final hints = _engine.findHints();
    if (hints.isEmpty) {
      shuffleBoard();
      return;
    }
    final evaluations = [
      for (final hint in hints) _engine.evaluateHint(hint),
    ]..sort((a, b) => _hintScore(b).compareTo(_hintScore(a)));
    // 在得分最高的几组里随机取一个，避免连续提示总指向同一处。
    final top = evaluations.take(3).toList();
    _hint = top[math.Random().nextInt(top.length)].hint;
    _selected = -1;
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 3500), () {
      _hint = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 目标导向的提示权重：冰面与未完成的收集目标优先，其次多消与特殊棋子。
  double _hintScore(HintEvaluation evaluation) {
    var score = evaluation.tileCount.toDouble();
    if (evaluation.createsSpecial) score += 1.5;
    for (final progress in goalProgress) {
      if (progress.done) continue;
      switch (progress.goal.kind) {
        case GoalKind.ice:
          score += evaluation.iceCount * 25;
        case GoalKind.collect:
          score +=
              (evaluation.typeCounts[progress.goal.type] ?? 0) * 6;
        case GoalKind.score:
          score += evaluation.tileCount * 0.4;
      }
    }
    return score;
  }

  /// 手动重排：不消耗步数，洗牌后清空选中与提示。
  void shuffleBoard() {
    if (!canInteract) return;
    _engine.shuffle();
    _selected = -1;
    _hint = null;
    _boardRevision++;
    LogService.info('关卡 ${level.id} 手动重排棋盘');
    notifyListeners();
  }

  /// 重开本关：分数、步数与冰层全部重置。
  void restart() {
    _hintTimer?.cancel();
    _engine.resetBoard();
    _movesLeft = level.moves;
    _score = 0;
    _iceBroken = 0;
    _combo = 0;
    _selected = -1;
    _hint = null;
    _stars = 0;
    _pending = const [];
    _status = GameStatus.ready;
    _collected.clear();
    _boardRevision++;
    _autoShuffled = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }
}
