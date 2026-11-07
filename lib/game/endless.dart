import 'dart:math';

import '../models/level.dart';
import '../models/tile.dart';

/// 无尽模式关卡编号：不计入闯关关卡表，也不写关卡星级。
const int kEndlessLevelId = 800;

/// 一轮无尽挑战：从第 1 层开始，通关累计分数并进入下一层。
class EndlessRun {
  const EndlessRun({this.stage = 1, this.totalScore = 0});

  final int stage;

  /// 本轮已通关各层的分数之和。
  final int totalScore;

  Level get level => endlessLevel(stage);

  EndlessRun afterWin(int score) =>
      EndlessRun(stage: stage + 1, totalScore: totalScore + score);
}

/// 生成无尽模式的第 [stage] 层：棋盘逐段放大，目标随层数加重。
///
/// 每层只保留两个目标，分数目标在附带收集或破冰时按比例下调，
/// 保证节奏是「越来越紧」而不是一上来就卡死。
Level endlessLevel(int stage) {
  final step = stage < 1 ? 1 : stage;
  final random = Random(step * 7717 + 29);
  final size = step <= 2 ? 7 : (step <= 6 ? 8 : 9);
  final moves = size == 7 ? 20 : (size == 8 ? 21 : 24);
  final palette = step <= 2 ? 5 : 6;
  final hasIce = step % 3 == 0;
  final hasCollect = !hasIce && step.isEven;
  final base = switch (size) {
    7 => 1300 + 250 * (step - 1),
    8 => 2100 + 300 * (step - 3),
    _ => 4000 + 400 * (step - 7),
  };
  final goals = <LevelGoal>[
    LevelGoal.score((base * (hasIce || hasCollect ? 0.8 : 1)).round()),
  ];
  var ice = const <int, int>{};
  if (hasIce) {
    final layers = step >= 15 ? 2 : 1;
    ice = _ice(random, size, layers: layers);
    goals.add(LevelGoal.ice(_iceTarget(ice.length, layers)));
  } else if (hasCollect) {
    goals.add(
      LevelGoal.collect(
        TileType.values[random.nextInt(palette)],
        10 + step ~/ 2,
      ),
    );
  }
  return Level(
    id: kEndlessLevelId,
    name: '第 $step 层',
    cols: size,
    rows: size,
    moves: moves,
    palette: palette,
    goals: goals,
    ice: ice,
    endlessStage: step,
  );
}

/// 冰层集中在棋盘中部相邻两行、隔列取点，连锁与特殊棋子容易一次破多块。
///
/// 边角散冰很难被消除波及，会让破冰目标变成死局，因此只取内圈。
Map<int, int> _ice(Random random, int size, {required int layers}) {
  final cells = <int, int>{};
  final start = (size - 2) ~/ 2;
  final offset = random.nextInt(2);
  for (var row = start; row <= start + 1; row++) {
    for (var col = 1 + offset; col < size - 1; col += 2) {
      cells[row * size + col] = layers;
    }
  }
  return cells;
}

/// 破冰目标：单层取总格数的三分之二，双层取一半，留出容错空间。
int _iceTarget(int cells, int layers) =>
    (cells * (layers >= 2 ? 0.5 : 2 / 3)).round().clamp(2, cells);
