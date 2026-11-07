import 'dart:math';

import '../models/level.dart';
import '../models/tile.dart';
import '../utils/formatters.dart';

/// 每日挑战：同一天生成同一关卡与同一副初始棋盘。
///
/// 关卡参数与棋盘种子都由日期推导，客户端无需联网也能得到一致的目标，
/// 方便玩家之间比较成绩。
class DailyChallenge {
  const DailyChallenge({
    required this.level,
    required this.seed,
    required this.dateKey,
  });

  /// 每日挑战不占用闯关关卡编号。
  static const int levelId = 900;

  /// 当天首次通关的额外福币奖励。
  static const int rewardCoins = 30;

  final Level level;
  final int seed;

  /// 存储键片段，格式为 `yyyyMMdd`。
  final String dateKey;

  static DailyChallenge of(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final dateKey = formatDateKey(day);
    final dayIndex = day.difference(DateTime(2024)).inDays;
    final seed = dayIndex * 7919 + 17;
    final random = Random(seed);

    const cols = 8;
    const rows = 8;
    final moves = 20 + random.nextInt(4);
    final ice = random.nextInt(3) == 0
        ? const <int, int>{}
        : _ice(random, cols, rows);
    final goals = _goals(random, hasIce: ice.isNotEmpty);
    final level = Level(
      id: levelId,
      name: '${day.month} 月 ${day.day} 日',
      cols: cols,
      rows: rows,
      moves: moves,
      goals: goals,
      ice: ice,
      dailyKey: dateKey,
      dailySeed: seed,
    );
    return DailyChallenge(level: level, seed: seed, dateKey: dateKey);
  }

  /// 今日目标的一句话摘要，用于首页卡片。
  String get goalSummary =>
      level.goals.map((goal) => goal.shortLabel).join(' · ');

  static List<LevelGoal> _goals(Random random, {required bool hasIce}) {
    final type = TileType.values[random.nextInt(5)];
    final other = TileType.values[(type.index + 2) % TileType.values.length];
    final score = 2800 + random.nextInt(5) * 300;
    final ice = 6 + random.nextInt(3);
    final collect = 12 + random.nextInt(5);
    if (!hasIce) {
      return random.nextBool()
          ? [LevelGoal.score(score)]
          : [LevelGoal.collect(type, collect + 4)];
    }
    return switch (random.nextInt(3)) {
      0 => [LevelGoal.score(score), LevelGoal.ice(ice)],
      1 => [LevelGoal.collect(type, collect), LevelGoal.ice(ice)],
      _ => [
        LevelGoal.score(score),
        LevelGoal.collect(other, collect),
        LevelGoal.ice(ice),
      ],
    };
  }

  /// 8–11 块单层浮冰，位置与数量都由当天的种子决定。
  static Map<int, int> _ice(Random random, int cols, int rows) {
    final cells = <int, int>{};
    final target = 8 + random.nextInt(4);
    var guard = 0;
    while (cells.length < target && guard++ < 240) {
      cells[random.nextInt(cols * rows)] = 1;
    }
    return cells;
  }
}
