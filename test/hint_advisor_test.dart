import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/engine.dart';
import 'package:fortune_match/game/goal_progress.dart';
import 'package:fortune_match/game/hint_advisor.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/models/tile.dart';

const _letters = {
  'A': TileType.coin,
  'B': TileType.ingot,
  'C': TileType.lantern,
  'D': TileType.jade,
  'E': TileType.porcelain,
};

Level _level(int cols, int rows) => Level(
  id: 1,
  name: '测试',
  cols: cols,
  rows: rows,
  moves: 20,
  palette: 5,
  goals: const [LevelGoal.score(100)],
);

MatchEngine _engineFrom(List<String> source) {
  final rows = [for (final row in source) row.replaceAll(' ', '')];
  final engine = MatchEngine(level: _level(rows.first.length, rows.length), seed: 1);
  var id = 1000;
  for (var row = 0; row < rows.length; row++) {
    for (var col = 0; col < rows[row].length; col++) {
      engine.board.tiles[row * rows.first.length + col] = Tile(
        id: id++,
        type: _letters[rows[row][col]]!,
      );
    }
  }
  return engine;
}

void main() {
  test('冰面目标优先于普通消除', () {
    final advisor = HintAdvisor(random: math.Random(1));
    const hint = SwapHint(0, 1);
    const plain = HintEvaluation(
      hint: hint,
      tileCount: 3,
      iceCount: 0,
      typeCounts: {TileType.coin: 3},
      createsSpecial: false,
    );
    const icy = HintEvaluation(
      hint: hint,
      tileCount: 3,
      iceCount: 2,
      typeCounts: {TileType.coin: 3},
      createsSpecial: false,
    );
    final goals = [
      const GoalProgress(goal: LevelGoal.ice(5), current: 0),
    ];
    expect(advisor.score(icy, goals), greaterThan(advisor.score(plain, goals)));
  });

  test('未完成的收集目标按对应棋子数量加分，已完成目标不再加权', () {
    final advisor = HintAdvisor(random: math.Random(1));
    const evaluation = HintEvaluation(
      hint: SwapHint(0, 1),
      tileCount: 3,
      iceCount: 0,
      typeCounts: {TileType.coin: 3},
      createsSpecial: false,
    );
    final pending = [
      const GoalProgress(goal: LevelGoal.collect(TileType.coin, 9), current: 0),
    ];
    final done = [
      const GoalProgress(goal: LevelGoal.collect(TileType.coin, 9), current: 9),
    ];
    expect(advisor.score(evaluation, pending), 3 + 18);
    expect(advisor.score(evaluation, done), 3);
  });

  test('提示从可消除交换中挑选，始终保持可执行', () {
    final engine = MatchEngine(level: _level(8, 8), seed: 12);
    final advisor = HintAdvisor(random: math.Random(3));
    final picked = advisor.pick(
      engine: engine,
      goals: [const GoalProgress(goal: LevelGoal.score(100), current: 0)],
    );
    expect(picked, isNotNull);
    expect(
      engine.findHints().any((hint) => hint.a == picked!.a && hint.b == picked.b),
      isTrue,
    );
  });

  test('棋盘没有可消除交换时返回 null', () {
    // 斜向三色循环铺满，任意相邻交换都凑不出三连。
    final engine = _engineFrom([
      'A B C A B',
      'B C A B C',
      'C A B C A',
      'A B C A B',
      'B C A B C',
    ]);
    final advisor = HintAdvisor(random: math.Random(5));
    expect(engine.findHints(), isEmpty);
    expect(advisor.pick(engine: engine, goals: const []), isNull);
  });
}
