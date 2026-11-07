import 'package:flutter/animation.dart';

import '../models/tile.dart';
import 'board_timings.dart';

/// 一枚棋子的渲染状态：格子位置、补间、消失与弹入动画。
class TileVisual {
  TileVisual({
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
      final t = (popElapsed / BoardTimings.pop).clamp(0.0, 1.0);
      return 0.55 + 0.45 * Curves.easeOutBack.transform(t);
    }
    return 1;
  }

  double get opacity {
    if (dying) {
      return (1 - dieElapsed / BoardTimings.clear).clamp(0.0, 1.0);
    }
    if (popIn) return (popElapsed / BoardTimings.pop).clamp(0.0, 1.0);
    return 1;
  }
}
