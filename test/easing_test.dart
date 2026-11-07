import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/easing.dart';

void main() {
  test('缓动查表与曲线误差足够小，端点精确', () {
    final curves = <EaseTable, Curve>{
      EaseTable.easeOutCubic: Curves.easeOutCubic,
      EaseTable.easeOutQuad: Curves.easeOutQuad,
      EaseTable.easeOutBack: Curves.easeOutBack,
    };
    curves.forEach((table, curve) {
      expect(table.transform(0), curve.transform(0));
      expect(table.transform(1), curve.transform(1));
      var maxError = 0.0;
      for (var i = 0; i <= 1000; i++) {
        final t = i / 1000;
        final error = (table.transform(t) - curve.transform(t)).abs();
        if (error > maxError) maxError = error;
      }
      // 曲线自身的二分求解容差约 0.1% 横坐标，起步段的纵坐标误差略大；
      // 采样表与之相差 1% 以内，对应一格的位移不到半个像素。
      expect(maxError, lessThan(0.01), reason: '采样表误差应在百分之一以内');
    });
  });

  test('超出 0~1 的输入按端点取值', () {
    expect(EaseTable.easeOutCubic.transform(-0.5), 0);
    expect(EaseTable.easeOutCubic.transform(1.5), 1);
  });
}
