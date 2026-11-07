import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/daily_challenge.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/models/tile.dart';
import 'package:fortune_match/services/sound_service.dart';

void main() {
  setUp(() {
    SoundService.sink = (_) {};
    SoundService.configure(sound: false, haptics: false);
  });

  tearDown(SoundService.reset);

  test('同一天生成的关卡与种子完全一致', () {
    final morning = DailyChallenge.of(DateTime(2026, 11, 8, 8, 30));
    final night = DailyChallenge.of(DateTime(2026, 11, 8, 23, 50));

    expect(morning.dateKey, '20261108');
    expect(night.dateKey, morning.dateKey);
    expect(night.seed, morning.seed);
    expect(night.level.moves, morning.level.moves);
    expect(night.level.ice, morning.level.ice);
    expect(night.level.name, '11 月 8 日');
    expect(night.level.heading, '每日挑战 · 8 × 8');
    expect(night.level.isDaily, isTrue);
    expect(night.goalSummary, isNotEmpty);

    final a = morning.level.goals;
    final b = night.level.goals;
    expect(b.length, a.length);
    for (var i = 0; i < a.length; i++) {
      expect(b[i].kind, a[i].kind);
      expect(b[i].target, a[i].target);
      expect(b[i].type, a[i].type);
    }
  });

  test('不同日期生成不同棋盘种子', () {
    final seeds = {
      for (var day = 1; day <= 10; day++)
        DailyChallenge.of(DateTime(2026, 11, day)).seed,
    };
    expect(seeds, hasLength(10));
  });

  test('连续 90 天的每日挑战配置合法', () {
    var date = DateTime(2025, 12, 31);
    for (var offset = 0; offset < 90; offset++) {
      final daily = DailyChallenge.of(date);
      final level = daily.level;
      expect(level.dailyKey, daily.dateKey);
      expect(level.dailySeed, daily.seed);
      expect(level.moves, inInclusiveRange(20, 23));
      expect(level.goals, isNotEmpty);
      for (final goal in level.goals) {
        expect(goal.target, greaterThan(0));
        if (goal.kind == GoalKind.collect) {
          expect(
            TileType.values.indexOf(goal.type!),
            lessThan(level.palette),
            reason: '${daily.dateKey} 的收集目标必须出现在棋子池中',
          );
        }
        if (goal.kind == GoalKind.ice) {
          expect(
            goal.target,
            lessThanOrEqualTo(level.ice.length),
            reason: '${daily.dateKey} 的破冰目标不能超过冰层数量',
          );
        }
      }
      for (final entry in level.ice.entries) {
        expect(entry.key, inInclusiveRange(0, level.cellCount - 1));
        expect(entry.value, 1);
      }
      date = date.add(const Duration(days: 1));
    }
  });

  test('同一种子复现出同一副初始棋盘', () {
    final daily = DailyChallenge.of(DateTime(2026, 11, 8));
    final first = MatchController(level: daily.level, seed: daily.seed);
    final second = MatchController(level: daily.level, seed: daily.seed);
    final types = [
      for (final tile in first.board.tiles) tile?.type,
    ];
    final other = [
      for (final tile in second.board.tiles) tile?.type,
    ];
    expect(other, types);
    expect(first.board.tiles.every((tile) => tile != null), isTrue);
  });
}
