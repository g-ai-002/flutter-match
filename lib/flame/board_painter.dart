import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/match_controller.dart';
import 'board_layout.dart';
import 'spark.dart';
import 'tile_sprite_cache.dart';
import 'tile_visual.dart';

/// 棋盘绘制：面板底纹、棋子、冰层、选中与提示高亮、消除粒子。
///
/// 只负责画，不持有动画状态；视觉列表与计时由 [BoardComponent] 维护。
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

  void paint(
    Canvas canvas, {
    required List<TileVisual> visuals,
    required List<Spark> sparks,
    required double time,
  }) {
    _paintPanel(canvas);
    final sorted = [...visuals]
      ..sort((a, b) {
        final rowCompare = a.row.compareTo(b.row);
        if (rowCompare != 0) return rowCompare;
        return a.col.compareTo(b.col);
      });
    for (final visual in sorted) {
      _paintTile(canvas, visual);
    }
    _paintIce(canvas);
    _paintSelection(canvas);
    _paintHint(canvas, time);
    _paintSparks(canvas, sparks);
  }

  double get _cell => layout.cell;

  void _paintPanel(Canvas canvas) {
    final rect = layout.boardRect;
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
    for (var row = 0; row < layout.rows; row++) {
      for (var col = 0; col < layout.cols; col++) {
        if ((row + col).isOdd) continue;
        final cellRect = Rect.fromLTWH(
          layout.left + col * _cell,
          layout.top + row * _cell,
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

  void _paintTile(Canvas canvas, TileVisual visual) {
    final cell = layout.cell;
    final center = Offset(
      layout.left + (visual.col + 0.5) * cell,
      layout.top + (visual.row + 0.5) * cell,
    );
    final rect = Rect.fromCenter(center: center, width: cell, height: cell);
    final selected = controller.selected == visual.cell;
    final scale = visual.scale * (selected ? 1.08 : 1.0);
    final opacity = visual.opacity;
    final sprite = sprites.tile(visual.type, visual.special, cell);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);
    if (opacity < 0.999) {
      canvas.saveLayer(
        rect.inflate(cell * 0.2),
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(cell * 0.06),
          Radius.circular(cell * 0.26),
        ),
        Paint()
          ..color = const Color(0xFFFFD27A).withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.1),
      );
    }
    canvas.drawPicture(sprite);
    if (opacity < 0.999) canvas.restore();
    canvas.restore();
  }

  void _paintIce(Canvas canvas) {
    final board = controller.board;
    for (var index = 0; index < board.length; index++) {
      final ice = board.ice[index];
      if (ice <= 0) continue;
      final rect = layout.cellRect(index);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.drawPicture(sprites.ice(ice, layout.cell));
      canvas.restore();
    }
  }

  void _paintSelection(Canvas canvas) {
    final selected = controller.selected;
    if (selected < 0) return;
    _paintRing(
      canvas,
      layout.cellRect(selected),
      const Color(0xFFFFD27A),
      width: _cell * 0.055,
      inset: _cell * 0.02,
    );
  }

  void _paintHint(Canvas canvas, double time) {
    final hint = controller.hint;
    if (hint == null) return;
    final pulse = 0.5 + 0.5 * math.sin(time * 7);
    final color = Color.lerp(
      const Color(0xFF8C2F24),
      const Color(0xFFE9B44C),
      pulse,
    )!;
    for (final cell in [hint.a, hint.b]) {
      _paintRing(
        canvas,
        layout.cellRect(cell),
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

  void _paintSparks(Canvas canvas, List<Spark> sparks) {
    final cell = layout.cell;
    for (final spark in sparks) {
      final t = spark.progress;
      final fade = (1 - t).clamp(0.0, 1.0);
      final radius = cell * (0.08 + 0.42 * Curves.easeOutQuad.transform(t));
      canvas.drawCircle(
        spark.center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * 0.05 * fade
          ..color = spark.color.withValues(alpha: 0.7 * fade),
      );
      final angle = spark.seed * math.pi * 2;
      final dotCenter =
          spark.center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.8;
      canvas.drawCircle(
        dotCenter,
        cell * 0.035 * fade,
        Paint()..color = Colors.white.withValues(alpha: 0.8 * fade),
      );
    }
  }
}
