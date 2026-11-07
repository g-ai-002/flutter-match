import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/board_step.dart';
import '../game/logic_rate.dart';
import '../game/match_controller.dart';
import '../services/sound_service.dart';
import '../theme/tile_art.dart';
import 'board_layout.dart';
import 'board_painter.dart';
import 'board_timings.dart';
import 'spark.dart';
import 'tile_sprite_cache.dart';
import 'tile_visual.dart';

/// Flame 棋盘组件：驱动动画队列、同步引擎状态，并处理点选与滑动。
///
/// 绘制交给 [BoardPainter]，排版交给 [BoardLayout]，贴图交给
/// [TileSpriteCache]，组件本身只维护动画阶段与输入。
class BoardComponent extends PositionComponent
    with TapCallbacks, DragCallbacks {
  BoardComponent({
    required this.controller,
    required this.darkMode,
    LogicRate logicRate = LogicRate.hz60,
  }) : _clock = FixedStepClock(logicRate.step);

  final MatchController controller;
  final ValueListenable<bool> darkMode;
  final FixedStepClock _clock;

  final List<TileVisual> _visuals = [];
  final List<Spark> _sparks = [];
  final TileSpriteCache _sprites = TileSpriteCache();
  final math.Random _random = math.Random(7);

  late final BoardLayout _layout = BoardLayout(cols: _cols, rows: _rows);
  late final BoardPainter _painter = BoardPainter(
    controller: controller,
    layout: _layout,
    sprites: _sprites,
    darkMode: darkMode,
  );

  double _time = 0;

  List<BoardStep> _steps = const [];
  int _stepIndex = 0;
  double _phaseElapsed = 0;
  double _phaseDuration = 0;
  bool _running = false;

  int _seenEpoch = 0;
  int _seenRevision = 0;

  /// 视觉状态版本号：棋盘内容、选中或提示变化时自增，用于静态帧缓存失效。
  int _frameRevision = 0;

  Vector2? _dragStart;
  Vector2? _dragLast;
  int? _dragStartCell;

  int get _cols => controller.level.cols;
  int get _rows => controller.level.rows;

  /// 暴露绘制器，供渲染缓存测试断言。
  @visibleForTesting
  BoardPainter get painter => _painter;

  @override
  Future<void> onLoad() async {
    _layout.fit(size);
    _syncFromBoard();
    _seenEpoch = controller.stepEpoch;
    _seenRevision = controller.boardRevision;
    controller.addListener(_onControllerChanged);
    if (controller.hasPendingSteps) {
      _enqueue(controller.takeSteps());
    }
  }

  @override
  void onRemove() {
    controller.removeListener(_onControllerChanged);
    _sprites.dispose();
    _painter.dispose();
    super.onRemove();
  }

  void _onControllerChanged() {
    if (isRemoved) return;
    _frameRevision++;
    if (controller.boardRevision != _seenRevision) {
      _seenRevision = controller.boardRevision;
      if (!_running) _syncFromBoard();
    }
    if (controller.stepEpoch != _seenEpoch) {
      _seenEpoch = controller.stepEpoch;
      _enqueue(controller.takeSteps());
    }
  }

  void _enqueue(List<BoardStep> steps) {
    if (steps.isEmpty) {
      controller.finishAnimation();
      return;
    }
    _steps = steps;
    _stepIndex = 0;
    _running = true;
    _startStep();
  }

  void _startStep() {
    _phaseElapsed = 0;
    _frameRevision++;
    switch (_steps[_stepIndex]) {
      case final SwapStep step:
        _startSwap(step);
        _phaseDuration = BoardTimings.swap;
      case final ClearStep step:
        _startClear(step);
        _phaseDuration = BoardTimings.clear;
      case final FallStep step:
        _startFall(step);
      // 由 _startFall 按最大下落距离设置时长。
    }
  }

  void _startSwap(SwapStep step) {
    final first = _visualAt(step.a);
    final second = _visualAt(step.b);
    if (first == null || second == null) {
      _phaseDuration = 0.02;
      return;
    }
    _tweenTo(first, step.b, BoardTimings.swap);
    _tweenTo(second, step.a, BoardTimings.swap);
  }

  void _startClear(ClearStep step) {
    final byCell = _liveByCell();
    for (final cell in step.cells) {
      final visual = byCell[cell];
      if (visual == null) continue;
      visual
        ..dying = true
        ..dieElapsed = 0;
      _sparks.add(
        Spark(
          center: _layout.cellCenter(visual.cell),
          color: kTilePalettes[visual.type]!.base,
          seed: _random.nextDouble(),
        ),
      );
    }
    for (final placed in step.specials) {
      final existing = byCell[placed.index];
      if (existing != null) _visuals.remove(existing);
      _visuals.add(
        TileVisual(
          id: placed.tile.id,
          type: placed.tile.type,
          special: placed.tile.special,
          cell: placed.index,
          col: (placed.index % _cols).toDouble(),
          row: (placed.index ~/ _cols).toDouble(),
        )..popIn = true,
      );
      _sparks.add(
        Spark(
          center: _layout.cellCenter(placed.index),
          color: const Color(0xFFFFE7A8),
          seed: _random.nextDouble(),
        ),
      );
    }
    if (_sparks.length > 140) {
      _sparks.removeRange(0, _sparks.length - 140);
    }
    _playClearSound(step);
  }

  /// 破冰、特殊棋子、大连锁与普通消除使用不同音效。
  void _playClearSound(ClearStep step) {
    final iceBroken = step.iceChanges.any((change) => change.broken);
    final hasSpecial =
        step.specials.isNotEmpty ||
        step.tiles.any((tile) => tile.special.isSpecial);
    if (iceBroken) {
      SoundService.play(FeedbackKind.ice);
    } else if (hasSpecial) {
      SoundService.play(FeedbackKind.special);
    } else if (step.combo >= 2 || step.tiles.length >= 5) {
      SoundService.play(FeedbackKind.clearBig);
    } else {
      SoundService.play(FeedbackKind.clear);
    }
  }

  void _startFall(FallStep step) {
    var maxDistance = 0.0;
    final byId = _byId();
    final byCell = _liveByCell();
    for (final move in step.moves) {
      final visual = byId[move.tileId] ?? byCell[move.from];
      if (visual == null) continue;
      final fromCol = move.from % _cols;
      final fromRow = move.from ~/ _cols;
      final toCol = move.to % _cols;
      final toRow = move.to ~/ _cols;
      maxDistance = math.max(
        maxDistance,
        ((fromCol - toCol).abs() + (fromRow - toRow).abs()).toDouble(),
      );
      if (visual.cell != move.from) {
        visual
          ..col = fromCol.toDouble()
          ..row = fromRow.toDouble();
      }
      _tweenTo(visual, move.to, 0.01);
    }
    for (final spawn in step.spawns) {
      final visual = TileVisual(
        id: spawn.tile.id,
        type: spawn.tile.type,
        special: spawn.tile.special,
        cell: spawn.to,
        col: (spawn.to % _cols).toDouble(),
        row: spawn.fromRow.toDouble(),
      );
      _visuals.add(visual);
      _tweenTo(visual, spawn.to, 0.01);
      maxDistance = math.max(
        maxDistance,
        (spawn.to ~/ _cols - spawn.fromRow).abs().toDouble(),
      );
    }
    final duration = (BoardTimings.fallBase + BoardTimings.fallPerCell * maxDistance)
        .clamp(BoardTimings.fallBase, BoardTimings.fallMax);
    for (final visual in _visuals) {
      if (!visual.tweening) continue;
      visual
        ..tweenElapsed = 0
        ..tweenDuration = duration;
    }
    _phaseDuration = duration;
  }

  void _tweenTo(TileVisual visual, int cell, double duration) {
    visual
      ..startCol = visual.col
      ..startRow = visual.row
      ..endCol = (cell % _cols).toDouble()
      ..endRow = (cell ~/ _cols).toDouble()
      ..tweenElapsed = 0
      ..tweenDuration = duration
      ..tweening = true
      ..cell = cell;
  }

  TileVisual? _visualAt(int cell) {
    for (final visual in _visuals) {
      if (visual.cell == cell && !visual.dying) return visual;
    }
    return null;
  }

  /// 未消失的视觉按格子下标建表，避免逐步长扫描。
  Map<int, TileVisual> _liveByCell() {
    final map = <int, TileVisual>{};
    for (final visual in _visuals) {
      if (!visual.dying) map[visual.cell] = visual;
    }
    return map;
  }

  Map<int, TileVisual> _byId() => {
    for (final visual in _visuals) visual.id: visual,
  };

  /// 用引擎状态重建视觉列表：保留仍在棋盘上的棋子，补齐新增的棋子。
  void _syncFromBoard() {
    final board = controller.board;
    final byId = _byId();
    final keep = <int>{};
    for (var index = 0; index < board.length; index++) {
      final tile = board.tiles[index];
      if (tile == null) continue;
      keep.add(tile.id);
      final existing = byId[tile.id];
      final col = (index % _cols).toDouble();
      final row = (index ~/ _cols).toDouble();
      if (existing == null) {
        _visuals.add(
          TileVisual(
            id: tile.id,
            type: tile.type,
            special: tile.special,
            cell: index,
            col: col,
            row: row,
          ),
        );
      } else {
        existing
          ..type = tile.type
          ..special = tile.special
          ..cell = index
          ..col = col
          ..row = row
          ..tweening = false
          ..dying = false
          ..popIn = false;
      }
    }
    _visuals.removeWhere(
      (visual) => !keep.contains(visual.id) && !visual.dying,
    );
    _frameRevision++;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _clock.advance(dt, _stepLogic);
  }

  void _stepLogic(double span) {
    _time += span;
    for (final visual in _visuals) {
      if (visual.tweening) {
        visual.tweenElapsed += span;
        final progress = (visual.tweenElapsed / visual.tweenDuration)
            .clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        visual
          ..col = visual.startCol + (visual.endCol - visual.startCol) * eased
          ..row = visual.startRow + (visual.endRow - visual.startRow) * eased;
        if (progress >= 1) {
          visual
            ..tweening = false
            ..col = visual.endCol
            ..row = visual.endRow;
        }
      }
      if (visual.dying) visual.dieElapsed += span;
      if (visual.popIn) {
        visual.popElapsed += span;
        if (visual.popElapsed >= BoardTimings.pop) visual.popIn = false;
      }
    }
    _visuals.removeWhere(
      (visual) => visual.dying && visual.dieElapsed >= BoardTimings.clear,
    );

    for (final spark in _sparks) {
      spark.elapsed += span;
    }
    _sparks.removeWhere((spark) => spark.finished);

    if (!_running) return;
    _phaseElapsed += span;
    if (_phaseElapsed < _phaseDuration) return;
    final step = _steps[_stepIndex];
    if (step is ClearStep) controller.onStepShown(step);
    _stepIndex++;
    if (_stepIndex >= _steps.length) {
      _finishBatch();
    } else {
      _startStep();
    }
  }

  void _finishBatch() {
    _running = false;
    _steps = const [];
    _stepIndex = 0;
    _syncFromBoard();
    controller.finishAnimation();
    // finishAnimation 可能触发死局自动重排，把新版本号带上避免重复同步。
    _seenRevision = controller.boardRevision;
  }

  /// 是否有补间、消失、弹入或粒子需要逐帧重绘。
  bool get _isAnimating {
    if (_running || _sparks.isNotEmpty) return true;
    for (final visual in _visuals) {
      if (visual.tweening || visual.dying || visual.popIn) return true;
    }
    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _layout.fit(size);
    _painter.paint(
      canvas,
      visuals: _visuals,
      sparks: _sparks,
      time: _time,
      animated: _isAnimating,
      revision: _frameRevision,
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!controller.canInteract) return;
    final cell = _layout.cellAt(event.localPosition);
    if (cell == null) return;
    controller.tapCell(cell);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!controller.canInteract) return;
    _dragStart = event.localPosition;
    _dragLast = _dragStart;
    _dragStartCell = _layout.cellAt(event.localPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _dragLast = event.localEndPosition;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    final start = _dragStart;
    final last = _dragLast ?? start;
    final cell = _dragStartCell;
    _dragStart = null;
    _dragLast = null;
    _dragStartCell = null;
    if (start == null || last == null || cell == null) return;
    if (!controller.canInteract) return;
    final delta = last - start;
    if (delta.length < _layout.cell * 0.26) return;
    final int dCol;
    final int dRow;
    if (delta.x.abs() > delta.y.abs()) {
      dCol = delta.x > 0 ? 1 : -1;
      dRow = 0;
    } else {
      dCol = 0;
      dRow = delta.y > 0 ? 1 : -1;
    }
    final col = cell % _cols + dCol;
    final row = cell ~/ _cols + dRow;
    if (col < 0 || col >= _cols || row < 0 || row >= _rows) return;
    controller.swipe(cell, row * _cols + col);
  }
}
