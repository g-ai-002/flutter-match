import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/endless.dart';
import 'package:fortune_match/game/engine.dart';
import 'package:fortune_match/models/level.dart';

void main() {
  test('无尽模式逐层放大棋盘并加重目标', () {
    final stage1 = endlessLevel(1);
    final stage3 = endlessLevel(3);
    final stage7 = endlessLevel(7);

    expect(stage1.isEndless, isTrue);
    expect(stage1.heading, '无尽模式 · 7 × 7');
    expect(stage1.name, '第 1 层');
    expect(stage1.id, kEndlessLevelId);
    expect(stage3.cols, 8);
    expect(stage7.cols, 9);
    expect(stage7.moves, greaterThan(stage1.moves));
    expect(stage1.palette, 5);
    expect(stage7.palette, 6);
    expect(stage7.goals.first.target, greaterThan(stage1.goals.first.target));
  });

  test('无尽模式每层目标可控且冰层目标不超过冰格数', () {
    for (var stage = 1; stage <= 40; stage++) {
      final level = endlessLevel(stage);
      expect(level.goals.length, lessThanOrEqualTo(2));
      expect(level.goals.any((goal) => goal.kind == GoalKind.score), isTrue);
      for (final goal in level.goals) {
        expect(goal.target, greaterThan(0));
        if (goal.kind == GoalKind.ice) {
          expect(goal.target, lessThanOrEqualTo(level.ice.length));
        }
      }
      expect(level.moves, greaterThan(0));
      expect(level.isEndless, isTrue);
    }
  });

  test('同层参数稳定，越界层数按第 1 层处理', () {
    final a = endlessLevel(5);
    final b = endlessLevel(5);
    expect(a.ice, b.ice);
    expect(a.goals.length, b.goals.length);

    final clamped = endlessLevel(0);
    expect(clamped.endlessStage, 1);
    expect(clamped.cols, 7);
  });

  test('无尽模式关卡可以直接生成棋盘', () {
    final engine = MatchEngine(level: endlessLevel(3), seed: 42);
    expect(engine.hasImmediateMatch, isFalse);
    expect(engine.findHint(), isNotNull);
    expect(engine.board.length, 64);
  });

  test('连续闯关累计分数并推进层数', () {
    const run = EndlessRun();
    expect(run.stage, 1);
    expect(run.totalScore, 0);

    final next = run.afterWin(2400);
    expect(next.stage, 2);
    expect(next.totalScore, 2400);
    expect(next.level.endlessStage, 2);

    final third = next.afterWin(1800);
    expect(third.totalScore, 4200);
    expect(third.stage, 3);
    expect(third.level.heading, '无尽模式 · 8 × 8');
  });
}
