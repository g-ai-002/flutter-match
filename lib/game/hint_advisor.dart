import 'dart:math' as math;

import '../models/level.dart';
import 'engine.dart';
import 'goal_progress.dart';

/// 目标导向的提示挑选：把得分最高的几组交换作为候选，再随机取一个，
/// 避免连续提示总指向同一处。
class HintAdvisor {
  HintAdvisor({math.Random? random}) : _random = random ?? math.Random();

  final math.Random _random;

  /// 参与随机挑选的候选数量。
  static const int candidateCount = 3;

  /// 挑一组推荐的交换；棋盘上没有可消除交换时返回 null。
  SwapHint? pick({
    required MatchEngine engine,
    required Iterable<GoalProgress> goals,
  }) {
    final hints = engine.findHints();
    if (hints.isEmpty) return null;
    final ranked = [for (final hint in hints) engine.evaluateHint(hint)]
      ..sort((a, b) => score(b, goals).compareTo(score(a, goals)));
    final candidates = ranked.take(candidateCount).toList(growable: false);
    return candidates[_random.nextInt(candidates.length)].hint;
  }

  /// 提示权重：冰面与未完成的收集目标优先，其次多消与特殊棋子。
  double score(HintEvaluation evaluation, Iterable<GoalProgress> goals) {
    var score = evaluation.tileCount.toDouble();
    if (evaluation.createsSpecial) score += 1.5;
    for (final progress in goals) {
      if (progress.done) continue;
      switch (progress.goal.kind) {
        case GoalKind.ice:
          score += evaluation.iceCount * 25;
        case GoalKind.collect:
          score += (evaluation.typeCounts[progress.goal.type] ?? 0) * 6;
        case GoalKind.score:
          score += evaluation.tileCount * 0.4;
      }
    }
    return score;
  }
}
