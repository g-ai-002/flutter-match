import '../models/level.dart';

/// 单条目标的实时进度。
class GoalProgress {
  const GoalProgress({required this.goal, required this.current});

  final LevelGoal goal;
  final int current;

  int get target => goal.target;

  bool get done => current >= target;

  double get ratio =>
      target <= 0 ? 1 : (current / target).clamp(0.0, 1.0).toDouble();

  String get display => '$current/$target';
}
