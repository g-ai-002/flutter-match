import 'dart:math' as math;
import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/match_controller.dart';
import '../theme/palette.dart';
import 'board_layout.dart';
import 'easing.dart';
import 'spark.dart';
import 'tile_sprite_cache.dart';
import 'tile_visual.dart';

/// 棋盘绘制：面板底纹、棋子、冰层、选中与提示高亮、消除粒子。
///
/// 只负责画，不持有动画状态；视觉列表与计时由 [BoardComponent] 维护。
/// 静止画面（无补间、无粒子、无提示闪烁）整块缓存为 Picture，空闲帧只画一次；
/// 底板与棋盘格同样单独缓存，避免每帧重建渐变与底纹。
///
/// 热路径上的取舍：
/// - 静止棋子只做一次 translate 就贴图，跳过缩放与图层；
/// - 格子矩形、冰面坐标在排版或冰层变化时预计算，逐帧不再扫描整盘；
/// - 贴图按定长数组下标取用，每帧只同步一次格子尺寸。
class BoardPainter {
  BoardPainter({
    required this.controller,
    required this.layout,
    required this.sprites,
    required this.darkMode,
  });

  final MatchController controller;
  final BoardLayout layout;
  final TileSpriteCache sprites;
  final ValueListenable<bool> darkMode;

  final List<TileVisual> _order = [];
  final Paint _ringPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _selectionPaint = Paint();
  final Paint _fadePaint = Paint();
  final Paint _sparkRingPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _sparkDotPaint = Paint();

  Picture? _panel;
  int _panelCellKey = -1;
  bool _panelDark = false;

  Picture? _staticFrame;
  int _staticRevision = -1;
  int _staticCellKey = -1;
  bool _staticDark = false;

  /// 冰面格子按 `index * 4 + layers` 打包，仅在冰层变化时重建。
  List<int> _iceCells = const [];
  int _iceRevision = -1;

  /// 静态画面重建次数，供性能测试断言缓存生效。
  @visibleForTesting
  int staticFrameBuilds = 0;

  /// 冰面坐标表重建次数，供性能测试断言没有逐帧扫描。
  @visibleForTesting
  int iceListBuilds = 0;

  /// 格子尺寸按 1/4 像素量化，和贴图缓存保持一致。
  int get _cellKey => (layout.cell * 4).round();

  void paint(
    Canvas canvas, {
    required List<TileVisual> visuals,
    required List<Spark> sparks,
    required double time,
    bool animated = true,
    int revision = 0,
  }) {
    final dark = darkMode.value;
    if (!animated) {
      final cached = _staticFrame;
      if (cached != null &&
          revision == _staticRevision &&
          _cellKey == _staticCellKey &&
          dark == _staticDark) {
        canvas.drawPicture(cached);
        return;
      }
      final recorder = PictureRecorder();
      _paintScene(
        Canvas(recorder),
        visuals: visuals,
        sparks: sparks,
        time: time,
        dark: dark,
      );
      final picture = recorder.endRecording();
      _staticFrame?.dispose();
      _staticFrame = picture;
      _staticRevision = revision;
      _staticCellKey = _cellKey;
      _staticDark = dark;
      staticFrameBuilds++;
      canvas.drawPicture(picture);
      return;
    }
    _paintScene(
      canvas,
      visuals: visuals,
      sparks: sparks,
      time: time,
      dark: dark,
    );
  }

  void dispose() {
    _staticFrame?.dispose();
    _staticFrame = null;
    _staticRevision = -1;
    _panel?.dispose();
    _panel = null;
    _panelCellKey = -1;
    _iceCells = const [];
    _iceRevision = -1;
  }

  /// 丢弃缓存的静止画面：字体晚到或贴图重建后需要重新录制。
  void invalidateStatic() {
    _staticFrame?.dispose();
    _staticFrame = null;
    _staticRevision = -1;
  }

  void _paintScene(
    Canvas canvas, {
    required List<TileVisual> visuals,
    required List<Spark> sparks,
    required double time,
    required bool dark,
  }) {
    sprites.beginFrame(layout.cell);
    _paintPanel(canvas, dark);
    _paintTiles(canvas, visuals);
    _paintIce(canvas);
    _paintSelection(canvas);
    _paintHint(canvas, time);
    _paintSparks(canvas, sparks);
  }

  /// 底板与棋盘格是静态图案，按格子尺寸和主题缓存为一张 Picture。
  void _paintPanel(Canvas canvas, bool dark) {
    final key = _cellKey;
    if (_panel == null || key != _panelCellKey || dark != _panelDark) {
      _panel?.dispose();
      _panel = _recordPanel(dark);
      _panelCellKey = key;
      _panelDark = dark;
    }
    final pad = layout.cell * 0.6;
    canvas
      ..save()
      ..translate(layout.left - pad, layout.top - pad)
      ..drawPicture(_panel!)
      ..restore();
  }

  Picture _recordPanel(bool dark) {
    final cell = layout.cell;
    final pad = cell * 0.6;
    final rect = Rect.fromLTWH(
      pad,
      pad,
      cell * layout.cols,
      cell * layout.rows,
    );
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final radius = Radius.circular(cell * 0.35);
    final outer = RRect.fromRectAndRadius(rect.inflate(cell * 0.16), radius);
    canvas.drawRRect(
      outer.shift(Offset(0, cell * 0.07)),
      Paint()
        ..color = const Color(0x33000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.14),
    );
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
      Paint()..color = dark ? const Color(0xFF221B14) : const Color(0xFFF1DFBB),
    );
    final cellPaint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.035);
    for (var row = 0; row < layout.rows; row++) {
      for (var col = 0; col < layout.cols; col++) {
        if ((row + col).isOdd) continue;
        final cellRect = Rect.fromLTWH(
          pad + col * cell,
          pad + row * cell,
          cell,
          cell,
        ).deflate(cell * 0.08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(cellRect, Radius.circular(cell * 0.2)),
          cellPaint,
        );
      }
    }
    return recorder.endRecording();
  }

  /// 棋子按行、列顺序绘制，列表复用 + 近有序插入排序，避免每帧拷贝与全量排序。
  void _paintTiles(Canvas canvas, List<TileVisual> visuals) {
    final order = _order
      ..clear()
      ..addAll(visuals);
    for (var i = 1; i < order.length; i++) {
      final item = order[i];
      var j = i - 1;
      while (j >= 0 && _isAfter(order[j], item)) {
        order[j + 1] = order[j];
        j--;
      }
      order[j + 1] = item;
    }
    for (final visual in order) {
      _paintTile(canvas, visual);
    }
    order.clear();
  }

  static bool _isAfter(TileVisual a, TileVisual b) {
    if (a.row != b.row) return a.row > b.row;
    return a.col > b.col;
  }

  void _paintTile(Canvas canvas, TileVisual visual) {
    final cell = layout.cell;
    final sprite = sprites.tile(visual.type, visual.special, cell);
    final selected = controller.selected == visual.cell;
    final scale = visual.scale * (selected ? 1.08 : 1.0);
    final opacity = visual.opacity;

    // 最常见的情况：静止、未选中、不透明，只需一次平移就能贴图。
    if (!selected && scale == 1 && opacity >= 0.999) {
      canvas
        ..save()
        ..translate(
          layout.left + visual.col * cell,
          layout.top + visual.row * cell,
        )
        ..drawPicture(sprite)
        ..restore();
      return;
    }

    final centerX = layout.left + (visual.col + 0.5) * cell;
    final centerY = layout.top + (visual.row + 0.5) * cell;
    canvas
      ..save()
      ..translate(centerX, centerY);
    if (scale != 1) canvas.scale(scale);
    if (opacity < 0.999) {
      _fadePaint.color = Colors.white.withValues(alpha: opacity);
      canvas.saveLayer(
        Rect.fromCenter(
          center: Offset.zero,
          width: cell,
          height: cell,
        ).inflate(cell * 0.2),
        _fadePaint,
      );
    }
    if (selected) {
      _selectionPaint
        ..color = appGoldLight.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: cell,
            height: cell,
          ).deflate(cell * 0.06),
          Radius.circular(cell * 0.26),
        ),
        _selectionPaint,
      );
    }
    canvas
      ..translate(-cell * 0.5, -cell * 0.5)
      ..drawPicture(sprite);
    if (opacity < 0.999) canvas.restore();
    canvas.restore();
  }

  void _paintIce(Canvas canvas) {
    final revision = controller.board.iceRevision;
    if (revision != _iceRevision) {
      _iceRevision = revision;
      final ice = controller.board.ice;
      final cells = <int>[];
      for (var index = 0; index < ice.length; index++) {
        final layers = ice[index];
        if (layers > 0) cells.add(index * 4 + layers);
      }
      _iceCells = cells;
      iceListBuilds++;
    }
    if (_iceCells.isEmpty) return;

    final cell = layout.cell;
    final left = layout.left;
    final top = layout.top;
    final cols = layout.cols;
    for (final packed in _iceCells) {
      final index = packed >> 2;
      final layers = packed & 3;
      canvas
        ..save()
        ..translate(left + (index % cols) * cell, top + (index ~/ cols) * cell)
        ..drawPicture(sprites.ice(layers, cell))
        ..restore();
    }
  }

  void _paintSelection(Canvas canvas) {
    final selected = controller.selected;
    if (selected < 0) return;
    _paintRing(
      canvas,
      layout.cellRect(selected),
      appGoldLight,
      width: layout.cell * 0.055,
      inset: layout.cell * 0.02,
    );
  }

  void _paintHint(Canvas canvas, double time) {
    final hint = controller.hint;
    if (hint == null) return;
    final pulse = 0.5 + 0.5 * math.sin(time * 7);
    final color = Color.lerp(appRedDeep, appGoldBright, pulse)!;
    final width = layout.cell * (0.035 + 0.02 * pulse);
    _paintRing(
      canvas,
      layout.cellRect(hint.a),
      color,
      width: width,
      inset: layout.cell * 0.03,
    );
    _paintRing(
      canvas,
      layout.cellRect(hint.b),
      color,
      width: width,
      inset: layout.cell * 0.03,
    );
  }

  void _paintRing(
    Canvas canvas,
    Rect cellRect,
    Color color, {
    required double width,
    required double inset,
  }) {
    final rect = cellRect.deflate(inset + width / 2);
    _ringPaint
      ..strokeWidth = width
      ..color = color.withValues(alpha: 0.9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(layout.cell * 0.26)),
      _ringPaint,
    );
  }

  void _paintSparks(Canvas canvas, List<Spark> sparks) {
    final cell = layout.cell;
    for (final spark in sparks) {
      final t = spark.progress;
      final fade = (1 - t).clamp(0.0, 1.0);
      final radius = cell * (0.08 + 0.42 * EaseTable.easeOutQuad.transform(t));
      _sparkRingPaint
        ..strokeWidth = cell * 0.05 * fade
        ..color = spark.color.withValues(alpha: 0.7 * fade);
      canvas.drawCircle(spark.center, radius, _sparkRingPaint);
      final angle = spark.seed * math.pi * 2;
      final dotCenter =
          spark.center +
          Offset(math.cos(angle), math.sin(angle)) * radius * 0.8;
      _sparkDotPaint.color = Colors.white.withValues(alpha: 0.8 * fade);
      canvas.drawCircle(dotCenter, cell * 0.035 * fade, _sparkDotPaint);
    }
  }
}
