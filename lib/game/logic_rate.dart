/// 逻辑更新速率：以固定步长推进消除、下落与特效动画，渲染仍按屏幕刷新逐帧绘制。
enum LogicRate {
  hz30('30 Hz 省电', 30),
  hz60('60 Hz 均衡', 60),
  hz120('120 Hz 顺滑', 120);

  const LogicRate(this.label, this.hz);
  final String label;
  final int hz;

  double get step => 1 / hz;

  /// 未设置或未知值时回退到默认 60Hz。
  static LogicRate byName(String? name) => values.firstWhere(
    (item) => item.name == name,
    orElse: () => LogicRate.hz60,
  );
}

/// 固定步长累加器：把不稳定的渲染帧间隔折算成固定数量的逻辑步。
class FixedStepClock {
  FixedStepClock(this.step, {this.maxSteps = 4});

  final double step;
  final int maxSteps;
  double _remainder = 0;

  /// 消费 [dt] 并回调一次合并后的逻辑步长，返回本帧推进的步数。
  /// 切后台或严重卡顿后积压的大量时间合并成一次大步推进，避免动画被拖慢。
  int advance(double dt, void Function(double span) onStep) {
    if (dt <= 0) return 0;
    _remainder += dt;
    var steps = 0;
    while (_remainder + 1e-9 >= step && steps < maxSteps) {
      _remainder -= step;
      steps++;
    }
    if (steps == 0) return 0;
    final overflow = _remainder >= step ? _remainder : 0.0;
    _remainder = overflow > 0 ? 0 : _remainder;
    onStep(steps * step + overflow);
    return steps;
  }
}
