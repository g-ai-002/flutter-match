import 'dart:ui';

import 'board_timings.dart';

/// 消除时从棋子中心扩散的光圈与亮点。
class Spark {
  Spark({required this.center, required this.color, required this.seed});

  final Offset center;
  final Color color;
  final double seed;
  double elapsed = 0;

  double get progress => (elapsed / BoardTimings.spark).clamp(0.0, 1.0);

  bool get finished => elapsed >= BoardTimings.spark;
}
