import 'dart:typed_data';

import 'package:flutter/animation.dart';

/// 缓动曲线采样表：把 [Curve.transform] 的二分查找换成查表 + 线性插值。
///
/// 动画每个逻辑步都要为每枚棋子求缓动值，120Hz 高刷下是热路径；
/// [Curves.easeOutCubic] 这类三次贝塞尔曲线的 transform 需要反复迭代求解，
/// 采样表只在首次使用时构建，误差在万分之一以内，肉眼看不出差别。
class EaseTable {
  EaseTable(this._curve, {this.samples = 256})
    : _values = Float64List(samples + 1) {
    for (var i = 0; i <= samples; i++) {
      _values[i] = _curve.transform(i / samples);
    }
  }

  final Curve _curve;
  final int samples;
  final Float64List _values;

  static final EaseTable easeOutCubic = EaseTable(Curves.easeOutCubic);
  static final EaseTable easeOutQuad = EaseTable(Curves.easeOutQuad);
  static final EaseTable easeOutBack = EaseTable(Curves.easeOutBack);

  /// 与 [Curve.transform] 等价的分段线性近似，端点精确。
  double transform(double t) {
    if (t <= 0) return _values.first;
    if (t >= 1) return _values.last;
    final position = t * samples;
    final index = position.floor();
    final fraction = position - index;
    final from = _values[index];
    return from + (_values[index + 1] - from) * fraction;
  }
}
