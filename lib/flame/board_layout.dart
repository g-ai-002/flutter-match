import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// 棋盘排版：把组件尺寸均分成格子，负责格子与坐标互转。
class BoardLayout {
  BoardLayout({required this.cols, required this.rows});

  final int cols;
  final int rows;

  double cell = 1;
  double left = 0;
  double top = 0;
  double _width = -1;
  double _height = -1;

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
  }

  Rect get boardRect => Rect.fromLTWH(left, top, cell * cols, cell * rows);

  Rect cellRect(int cell) => Rect.fromLTWH(
    left + (cell % cols) * this.cell,
    top + (cell ~/ cols) * this.cell,
    this.cell,
    this.cell,
  );

  Offset cellCenter(int cell) => Offset(
    left + (cell % cols + 0.5) * this.cell,
    top + (cell ~/ cols + 0.5) * this.cell,
  );

  /// 屏幕坐标落在哪一格；超出棋盘返回 null。
  int? cellAt(Vector2 point) {
    final col = ((point.x - left) / cell).floor();
    final row = ((point.y - top) / cell).floor();
    if (col < 0 || col >= cols || row < 0 || row >= rows) return null;
    return row * cols + col;
  }
}
