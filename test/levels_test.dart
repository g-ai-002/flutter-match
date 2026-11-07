import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/models/tile.dart';

void main() {
  test('关卡编号连续、目标与星级配置合法', () {
    expect(kLevels, hasLength(20));
    for (var index = 0; index < kLevels.length; index++) {
      final level = kLevels[index];
      expect(level.id, index + 1);
      expect(level.name.isNotEmpty, isTrue);
      expect(level.goals.isNotEmpty, isTrue);
      expect(level.moves, greaterThan(10));
      expect(level.palette, lessThanOrEqualTo(TileType.values.length));
      for (final goal in level.goals) {
        expect(goal.target, greaterThan(0));
        if (goal.kind == GoalKind.collect) {
          expect(goal.type, isNotNull);
          expect(
            TileType.values.indexOf(goal.type!),
            lessThan(level.palette),
            reason: '第 ${level.id} 关的收集目标必须出现在本关棋子池中',
          );
        }
      }
      for (final cell in level.ice.keys) {
        expect(cell, inInclusiveRange(0, level.cellCount - 1));
      }
      for (final layers in level.ice.values) {
        expect(layers, inInclusiveRange(1, 2));
      }
    }
  });

  test('关卡名称不重复，下一关查找正确', () {
    final names = kLevels.map((level) => level.name).toSet();
    expect(names, hasLength(kLevels.length));
    expect(nextLevelOf(1)?.id, 2);
    expect(nextLevelOf(20), isNull);
    expect(levelById(999).id, 1);
  });
}
