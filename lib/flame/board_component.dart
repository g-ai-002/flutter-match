import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/board_step.dart';
import '../game/logic_rate.dart';
import '../game/match_controller.dart';
import '../models/tile.dart';
import '../services/sound_service.dart';
import '../theme/tile_art.dart';

const double _swapDuration = 0.14;
const double _clearDuration = 0.26;
const double _fallBaseDuration = 0.1;
const double _fallPerCell = 0.045;
const double _fallMaxDuration = 0.4;
const double _popDuration = 0.2;

class _TileVisual {
  _TileVisual({
    required this.id,
    required this.type,
    required this.special,
    required this.cell,
    required this.col,
    required this.row,
  });

  final int id;
  TileType type;
  SpecialType special;
  int cell;

  double col;
  double row;

  double startCol = 0;
  double startRow = 0;
  double endCol = 0;
  double endRow = 0;
  double tweenElapsed = 0;
  double tweenDuration = 0;
  bool tweening = false;

  bool dying = false;
  double dieElapsed = 0;

  bool popIn = false;
  double popElapsed = 0;

  double get scale {
    if (popIn) {
      final t = (popElapsed / _popDuration).clamp(0.0, 1.0);
      return 0.55 + 0.45 * Curves.easeOutBack.transform(t);
    }
    return 1;
  }

  double get opacity {
    if (dying) {
      return (1 - dieElapsed / _clearDuration).clamp(0.0, 1.0);
    }
    if (popIn) return (popElapsed / _popDuration).clamp(0.0, 1.0);
    return 1;
  }

  Offset get positionOffset => Offset(col, row);
}

class _Spark {
  _Spark({required this.center, required this.color, required this.seed});

  final Offset center;
  final Color color;
  final double seed;
  double elapsed = 0;
  static const double duration = 0.42;

  double get progress => (elapsed / duration).clamp(0.0, 1.0);
}

/// Flame 棋盘组件：绘制棋子、冰层、消除特效与提示，并处理点选与滑动。
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

  final List<_TileVisual> _visuals = [];
  final List<_Spark> _sparks = [];
  final TileGlyphCache _glyphs = TileGlyphCache();
  final math.Random _random = math.Random(7);
  final Map<String, Picture> _tileSprites = {};
  final Map<int, Picture> _iceSprites = {};
  int _spriteCellKey = 0;

  double _cell = 1;
  double _left = 0;
  double _top = 0;
  double _layoutWidth = -1;
  double _layoutHeight = -1;
  double _time = 0;

  List<BoardStep> _steps = const [];
  int _stepIndex = 0;
  double _phaseElapsed = 0;
  double _phaseDuration = 0;
  bool _running = false;

  int _seenEpoch = 0;
  int _seenRevision = 0;

  Vector2? _dragStart;
  Vector2? _dragLast;
  int? _dragStartCell;

  int get _cols => controller.level.cols;
  int get _rows => controller.level.rows;

  @override
  Future<void> onLoad() async {
    _fitToSize();
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
    _glyphs.clear();
    _clearSprites();
    super.onRemove();
  }

  void _onControllerChanged() {
    if (isRemoved) return;
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
    final step = _steps[_stepIndex];
    switch (step) {
      case SwapStep():
        _startSwap(step);
        _phaseDuration = _swapDuration;
      case ClearStep():
        _startClear(step);
        _phaseDuration = _clearDuration;
      case FallStep():
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
    _tweenTo(first, step.b, _swapDuration);
    _tweenTo(second, step.a, _swapDuration);
  }

  void _startClear(ClearStep step) {
    for (final cell in step.cells) {
      final visual = _visualAt(cell);
      if (visual == null) continue;
      visual.dying = true;
      visual.dieElapsed = 0;
      _sparks.add(
        _Spark(
          center: _cellCenter(visual.cell),
          color: kTilePalettes[visual.type]!.base,
          seed: _random.nextDouble(),
        ),
      );
    }
    for (final placed in step.specials) {
      final existing = _visualAt(placed.index);
      if (existing != null) _visuals.remove(existing);
      final visual = _TileVisual(
        id: placed.tile.id,
        type: placed.tile.type,
        special: placed.tile.special,
        cell: placed.index,
        col: (placed.index % _cols).toDouble(),
        row: (placed.index ~/ _cols).toDouble(),
      )..popIn = true;
      _visuals.add(visual);
      _sparks.add(
        _Spark(
          center: _cellCenter(placed.index),
          color: const Color(0xFFFFE7A8),
          seed: _random.nextDouble(),
        ),
      );
    }
    if (_sparks.length > 140) {
      _sparks.removeRange(0, _sparks.length - 140);
    }

    final iceBroken = step.iceChanges.any((change) => change.broken);
    final hasSpecial = step.specials.isNotEmpty ||
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
    for (final move in step.moves) {
      final visual = _visualById(move.tileId) ?? _visualAt(move.from);
      if (visual == null) continue;
      final fromCol = move.from % _cols;
      final fromRow = move.from ~/ _cols;
      final toCol = move.to % _cols;
      final toRow = move.to ~/ _cols;
      final distance =
          (fromCol - toCol).abs() + (fromRow - toRow).abs();
      maxDistance = math.max(maxDistance, distance.toDouble());
      if (visual.cell != move.from) {
        visual
          ..col = fromCol.toDouble()
          ..row = fromRow.toDouble();
      }
      _tweenTo(visual, move.to, 0.01);
    }
    for (final spawn in step.spawns) {
      final visual = _TileVisual(
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
    final duration = (_fallBaseDuration + _fallPerCell * maxDistance)
        .clamp(_fallBaseDuration, _fallMaxDuration);
    for (final visual in _visuals) {
      if (!visual.tweening) continue;
      visual
        ..tweenElapsed = 0
        ..tweenDuration = duration;
    }
    _phaseDuration = duration;
  }

  void _tweenTo(_TileVisual visual, int cell, double duration) {
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

  _TileVisual? _visualAt(int cell) {
    for (final visual in _visuals) {
      if (visual.cell == cell && !visual.dying) return visual;
    }
    return null;
  }

  _TileVisual? _visualById(int id) {
    for (final visual in _visuals) {
      if (visual.id == id) return visual;
    }
    return null;
  }

  Offset _cellCenter(int cell) =>
      Offset(_left + (cell % _cols + 0.5) * _cell, _top + (cell ~/ _cols + 0.5) * _cell);

  void _syncFromBoard() {
    final board = controller.board;
    final keep = <int>{};
    for (var index = 0; index < board.length; index++) {
      final tile = board.tiles[index];
      if (tile == null) continue;
      keep.add(tile.id);
      final existing = _visualById(tile.id);
      final col = (index % _cols).toDouble();
      final row = (index ~/ _cols).toDouble();
      if (existing == null) {
        _visuals.add(
          _TileVisual(
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
        if (visual.popElapsed >= _popDuration) visual.popIn = false;
      }
    }
    _visuals.removeWhere(
      (visual) => visual.dying && visual.dieElapsed >= _clearDuration,
    );

    for (final spark in _sparks) {
      spark.elapsed += span;
    }
    _sparks.removeWhere((spark) => spark.elapsed >= _Spark.duration);

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
    _seenRevision = controller.boardRevision;
    controller.finishAnimation();
    _seenRevision = controller.boardRevision;
  }

  void _clearSprites() {
    for (final sprite in _tileSprites.values) {
      sprite.dispose();
    }
    for (final sprite in _iceSprites.values) {
      sprite.dispose();
    }
    _tileSprites.clear();
    _iceSprites.clear();
    _spriteCellKey = 0;
  }

  void _ensureSpriteCell() {
    final key = (_cell * 4).round();
    if (key == _spriteCellKey) return;
    _clearSprites();
    _spriteCellKey = key;
    _glyphs.clear();
  }

  Picture _tileSprite(TileType type, SpecialType special) {
    final key = '${type.name}|${special.name}';
    return _tileSprites.putIfAbsent(key, () {
      final recorder = PictureRecorder();
      paintTile(
        Canvas(recorder),
        Rect.fromLTWH(0, 0, _cell, _cell),
        type,
        special,
        _glyphs,
      );
      return recorder.endRecording();
    });
  }

  Picture _iceSprite(int layers) {
    return _iceSprites.putIfAbsent(layers, () {
      final recorder = PictureRecorder();
      paintIce(
        Canvas(recorder),
        Rect.fromLTWH(0, 0, _cell, _cell),
        layers,
      );
      return recorder.endRecording();
    });
  }

  void _fitToSize() {
    if (size.x <= 0 || size.y <= 0) return;
    if (size.x == _layoutWidth && size.y == _layoutHeight) return;
    _layoutWidth = size.x;
    _layoutHeight = size.y;
    final padding = math.min(size.x, size.y) * 0.02 + 4;
    final availableWidth = math.max(1.0, size.x - padding * 2);
    final availableHeight = math.max(1.0, size.y - padding * 2);
    _cell = math.min(availableWidth / _cols, availableHeight / _rows);
    _left = (size.x - _cell * _cols) / 2;
    _top = (size.y - _cell * _rows) / 2;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _fitToSize();
    _ensureSpriteCell();
    _paintPanel(canvas);

    final sorted = [..._visuals]
      ..sort((a, b) {
        final rowCompare = a.row.compareTo(b.row);
        if (rowCompare != 0) return rowCompare;
        return a.col.compareTo(b.col);
      });
    for (final visual in sorted) {
      _paintTileVisual(canvas, visual);
    }

    final board = controller.board;
    for (var index = 0; index < board.length; index++) {
      final ice = board.ice[index];
      if (ice <= 0) continue;
      final rect = _cellRect(index);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.drawPicture(_iceSprite(ice));
      canvas.restore();
    }

    _paintSelection(canvas);
    _paintHint(canvas);
    _paintSparks(canvas);
  }

  Rect _cellRect(int cell) => Rect.fromLTWH(
    _left + (cell % _cols) * _cell,
    _top + (cell ~/ _cols) * _cell,
    _cell,
    _cell,
  );

  void _paintPanel(Canvas canvas) {
    final rect = Rect.fromLTWH(
      _left,
      _top,
      _cell * _cols,
      _cell * _rows,
    );
    final radius = Radius.circular(_cell * 0.35);
    final outer = RRect.fromRectAndRadius(rect.inflate(_cell * 0.16), radius);
    canvas.drawRRect(
      outer.shift(Offset(0, _cell * 0.07)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _cell * 0.14),
    );
    final dark = darkMode.value;
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [Color(0xFF3A2E22), Color(0xFF241C15)]
              : const [Color(0xFFF4E3BF), Color(0xFFE2C795)],
        ).createShader(rect),
    );
    final inner = RRect.fromRectAndRadius(rect, radius * 0.7);
    canvas.drawRRect(
      inner,
      Paint()
        ..color = dark ? const Color(0xFF221B14) : const Color(0xFFF1DFBB),
    );
    final cellPaint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.035);
    for (var row = 0; row < _rows; row++) {
      for (var col = 0; col < _cols; col++) {
        if ((row + col).isOdd) continue;
        final cellRect = Rect.fromLTWH(
          _left + col * _cell,
          _top + row * _cell,
          _cell,
          _cell,
        ).deflate(_cell * 0.08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect, Radius.circular(_cell * 0.2)),
          cellPaint,
        );
      }
    }
  }

  void _paintTileVisual(Canvas canvas, _TileVisual visual) {
    final center = Offset(
      _left + (visual.col + 0.5) * _cell,
      _top + (visual.row + 0.5) * _cell,
    );
    final rect = Rect.fromCenter(center: center, width: _cell, height: _cell);
    final selected = controller.selected == visual.cell;
    final scale = visual.scale * (selected ? 1.08 : 1.0);
    final opacity = visual.opacity;
    final sprite = _tileSprite(visual.type, visual.special);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    if (opacity < 0.999) {
      canvas.saveLayer(
        rect.inflate(_cell * 0.2),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(_cell * 0.06),
          Radius.circular(_cell * 0.26),
        ),
        Paint()
          ..color = const Color(0xFFFFD27A).withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, _cell * 0.1),
      );
    }
    canvas.drawPicture(sprite);
    if (opacity < 0.999) canvas.restore();
    canvas.restore();
  }

  void _paintSelection(Canvas canvas) {
    final selected = controller.selected;
    if (selected < 0) return;
    _paintRing(
      canvas,
      _cellRect(selected),
      const Color(0xFFFFD27A),
      width: _cell * 0.055,
      inset: _cell * 0.02,
    );
  }

  void _paintHint(Canvas canvas) {
    final hint = controller.hint;
    if (hint == null) return;
    final pulse = 0.5 + 0.5 * math.sin(_time * 7);
    final color = Color.lerp(
      const Color(0xFF8C2F24),
      const Color(0xFFE9B44C),
      pulse,
    )!;
    for (final cell in [hint.a, hint.b]) {
      _paintRing(
        canvas,
        _cellRect(cell),
        color,
        width: _cell * (0.035 + 0.02 * pulse),
        inset: _cell * 0.03,
      );
    }
  }

  void _paintRing(
    Canvas canvas,
    Rect cellRect,
    Color color, {
    required double width,
    required double inset,
  }) {
    final rect = cellRect.deflate(inset + width / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(_cell * 0.26)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: 0.9),
    );
  }

  void _paintSparks(Canvas canvas) {
    for (final spark in _sparks) {
      final t = spark.progress;
      final fade = (1 - t).clamp(0.0, 1.0);
      final radius = _cell * (0.08 + 0.42 * Curves.easeOutQuad.transform(t));
      canvas.drawCircle(
        spark.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _cell * 0.05 * fade
          ..color = spark.color.withValues(alpha: 0.7 * fade),
      );
      final angle = spark.seed * math.pi * 2;
      final dotCenter = spark.center +
          Offset(math.cos(angle), math.sin(angle)) * radius * 0.8;
      canvas.drawCircle(
        dotCenter,
        _cell * 0.035 * fade,
        Paint()..color = Colors.white.withValues(alpha: 0.8 * fade),
      );
    }
  }

  int? _cellAt(Vector2 point) {
    final col = ((point.x - _left) / _cell).floor();
    final row = ((point.y - _top) / _cell).floor();
    if (col < 0 || col >= _cols || row < 0 || row >= _rows) return null;
    return row * _cols + col;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!controller.canInteract) return;
    final cell = _cellAt(event.localPosition);
    if (cell == null) return;
    controller.tapCell(cell);
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (!controller.canInteract) return;
    _dragStart = event.localPosition;
    _dragLast = _dragStart;
    _dragStartCell = _cellAt(event.localPosition);
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
    if (delta.length < _cell * 0.26) return;
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
