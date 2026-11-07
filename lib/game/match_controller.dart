import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/level.dart';
import '../models/tile.dart';
import '../services/log_service.dart';
import '../services/sound_service.dart';
import 'board_step.dart';
import 'engine.dart';
import 'game_status.dart';
import 'goal_progress.dart';
import 'hint_advisor.dart';
import 'props.dart';
import 'scoring.dart';

export 'game_status.dart';
export 'goal_progress.dart';
export 'props.dart';

/// 关卡控制器：衔接三消引擎、计分目标与 Flame 动画队列。
///
/// 引擎在交换时一次性算出整段连锁的动画脚本，Flame 组件逐条播放，
/// 每播完一条由组件回调 [onStepShown]，分数与目标进度随之推进。
/// 道具同样通过引擎生成脚本，只是不消耗步数。
class MatchController extends ChangeNotifier {
  MatchController({
    required this.level,
    int? seed,
    HintAdvisor? hintAdvisor,
    PropStock? props,
  }) : _engine = MatchEngine(level: level, seed: seed),
       _advisor = hintAdvisor ?? HintAdvisor(random: math.Random(seed)),
       _props = props ?? PropStock(),
       _movesLeft = level.moves;

  final Level level;
  final MatchEngine _engine;
  final HintAdvisor _advisor;
  final PropStock _props;

  /// 道具消耗后的回调，界面层据此把新库存写回本地存储。
  ValueChanged<PropKind>? onPropUsed;

  int _movesLeft;
  int _score = 0;
  int _iceBroken = 0;
  int _combo = 0;
  int _selected = -1;
  int _stars = 0;
  GameStatus _status = GameStatus.ready;
  PropKind? _activeProp;
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

  /// 当前待命中的道具；null 表示普通消除模式。
  PropKind? get activeProp => _activeProp;

  int propCount(PropKind kind) => _props.count(kind);

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
  ///
  /// 道具待命时改为道具操作：小锤一步生效，换位需要依次点两枚棋子。
  void tapCell(int index) {
    if (!canInteract) return;
    if (board.tileAt(index) == null) return;
    switch (_activeProp) {
      case PropKind.hammer:
        _useHammer(index);
        return;
      case PropKind.swap:
        _pickForSwap(index);
        return;
      case PropKind.shuffle:
      case null:
        break;
    }
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
    _activeProp = null;
    _hint = null;
    _hintTimer?.cancel();
    final outcome = _engine.trySwap(a, b);
    if (!outcome.valid) {
      _pending = outcome.steps;
      _status = GameStatus.animating;
      _epoch++;
      SoundService.play(FeedbackKind.invalid);
    } else {
      _movesLeft--;
      _beginSteps(outcome.steps, FeedbackKind.swap);
    }
    notifyListeners();
  }

  /// 启用道具：洗牌立即生效，小锤与换位进入待点击状态。
  ///
  /// 库存不足时返回 false，由界面层引导到道具铺。
  bool activateProp(PropKind kind) {
    if (!canInteract || !_props.has(kind)) return false;
    if (kind == PropKind.shuffle) {
      _props.take(kind);
      _activeProp = null;
      _selected = -1;
      _hint = null;
      _hintTimer?.cancel();
      _engine.shuffle();
      _boardRevision++;
      LogService.info('关卡 ${level.id} 使用洗牌道具');
      SoundService.play(FeedbackKind.prop);
      _notifyPropUsed(kind);
      notifyListeners();
      return true;
    }
    _activeProp = _activeProp == kind ? null : kind;
    _selected = -1;
    _hint = null;
    _hintTimer?.cancel();
    SoundService.tap();
    notifyListeners();
    return true;
  }

  /// 取消道具待命状态。
  void cancelProp() {
    if (_activeProp == null) return;
    _activeProp = null;
    _selected = -1;
    notifyListeners();
  }

  /// 道具铺购买成功后同步局内库存。
  void addProp(PropKind kind) {
    _props.add(kind);
    notifyListeners();
  }

  void _useHammer(int index) {
    final steps = _engine.smash(index);
    if (steps.isEmpty) return;
    _props.take(PropKind.hammer);
    _activeProp = null;
    _selected = -1;
    LogService.info('关卡 ${level.id} 使用小锤：格 $index');
    _beginSteps(steps, FeedbackKind.prop);
    _notifyPropUsed(PropKind.hammer);
    notifyListeners();
  }

  void _pickForSwap(int index) {
    if (_selected < 0) {
      _selected = index;
      SoundService.tap();
      notifyListeners();
      return;
    }
    if (_selected == index) {
      _selected = -1;
      notifyListeners();
      return;
    }
    final from = _selected;
    final outcome = _engine.trySwap(from, index, anywhere: true);
    if (!outcome.valid) {
      // 没形成消除就退回，道具不消耗，并把锚点挪到刚点的棋子上。
      _selected = index;
      SoundService.play(FeedbackKind.invalid);
      notifyListeners();
      return;
    }
    _props.take(PropKind.swap);
    _activeProp = null;
    _selected = -1;
    LogService.info('关卡 ${level.id} 使用换位：$from ↔ $index');
    _beginSteps(outcome.steps, FeedbackKind.prop);
    _notifyPropUsed(PropKind.swap);
    notifyListeners();
  }

  void _beginSteps(List<BoardStep> steps, FeedbackKind sound) {
    _pending = steps;
    _status = GameStatus.animating;
    _epoch++;
    SoundService.play(sound);
  }

  void _notifyPropUsed(PropKind kind) => onPropUsed?.call(kind);

  /// 组件每播放完一条消除步骤时回调，推进分数与目标进度。
  void onStepShown(BoardStep step) {
    if (step is! ClearStep) return;
    _combo = step.combo;
    final broken = step.iceChanges.where((change) => change.broken).length;
    _score += ScoreRules.forClear(
      tiles: step.tiles.length,
      specials: step.specials.length,
      iceBroken: broken,
      combo: step.combo,
    );
    _iceBroken += broken;
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
      _stars = ScoreRules.starsFor(movesLeft: movesLeft, moves: level.moves);
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
    _activeProp = null;
    final picked = _advisor.pick(engine: _engine, goals: goalProgress);
    if (picked == null) {
      shuffleBoard();
      return;
    }
    _hint = picked;
    _selected = -1;
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 3500), () {
      _hint = null;
      notifyListeners();
    });
    notifyListeners();
  }

  /// 手动重排：不消耗步数，洗牌后清空选中与提示。
  void shuffleBoard() {
    if (!canInteract) return;
    _engine.shuffle();
    _selected = -1;
    _activeProp = null;
    _hint = null;
    _boardRevision++;
    LogService.info('关卡 ${level.id} 手动重排棋盘');
    notifyListeners();
  }

  /// 重开本关：分数、步数与冰层全部重置，已消耗的道具不返还。
  void restart() {
    _hintTimer?.cancel();
    _engine.resetBoard();
    _movesLeft = level.moves;
    _score = 0;
    _iceBroken = 0;
    _combo = 0;
    _selected = -1;
    _activeProp = null;
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
