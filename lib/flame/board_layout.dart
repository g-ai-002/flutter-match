import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// 棋盘排版：把组件尺寸均分成格子，负责格子与坐标互转。
///
/// 每个格子的矩形与中心点在尺寸变化时一次性算好，绘制热路径直接查表，
/// 不再为每枚棋子新建 [Rect] / [Offset]。
class BoardLayout {
  BoardLayout({required this.cols, required this.rows}) {
    _rebuildCells();
  }

  final int cols;
  final int rows;

  double cell = 1;
  double left = 0;
  double top = 0;
  double _width = -1;
  double _height = -1;

  final List<Rect> _rects = [];
  final List<Offset> _centers = [];
  Rect _boardRect = Rect.zero;

  /// 按组件尺寸重新排版；尺寸未变化时直接返回，避免每帧重复计算。
  void fit(Vector2 size) {
    if (size.x <= 0 || size.y <= 0) return;
    if (size.x == _width && size.y == _height) return;
    _width = size.x;
    _height = size.y;
    final padding = math.min(size.x, size.y) * 0.02 + 4;
    final availableWidth = math.max(1.0, size.x - padding * 2);
    final availableHeight = math.max(1.0, size.y - padding * 2);
    cell = math.min(availableWidth / cols, availableHeight / rows);
    left = (size.x - cell * cols) / 2;
    top = (size.y - cell * rows) / 2;
    _rebuildCells();
  }

  void _rebuildCells() {
    _rects.clear();
    _centers.clear();
    for (var index = 0; index < cols * rows; index++) {
      final x = left + (index % cols) * cell;
      final y = top + (index ~/ cols) * cell;
      _rects.add(Rect.fromLTWH(x, y, cell, cell));
      _centers.add(Offset(x + cell / 2, y + cell / 2));
    }
    _boardRect = Rect.fromLTWH(left, top, cell * cols, cell * rows);
  }

  Rect get boardRect => _boardRect;

  Rect cellRect(int index) => _rects[index];

  Offset cellCenter(int index) => _centers[index];

  /// 屏幕坐标落在哪一格；超出棋盘返回 null。
  int? cellAt(Vector2 point) {
    final col = ((point.x - left) / cell).floor();
    final row = ((point.y - top) / cell).floor();
    if (col < 0 || col >= cols || row < 0 || row >= rows) return null;
    return row * cols + col;
  }
}
