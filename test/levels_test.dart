import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/chapters.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/progress.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/models/tile.dart';

void main() {
  test('关卡编号连续、目标与星级配置合法', () {
    expect(kLevels, hasLength(50));
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
      for (final goal in level.goals.where(
        (goal) => goal.kind == GoalKind.ice,
      )) {
        expect(
          goal.target,
          lessThanOrEqualTo(level.ice.length),
          reason: '第 ${level.id} 关的破冰目标不能超过冰层格数',
        );
      }
    }
  });

  test('关卡名称不重复，下一关查找正确', () {
    final names = kLevels.map((level) => level.name).toSet();
    expect(names, hasLength(kLevels.length));
    expect(nextLevelOf(1)?.id, 2);
    expect(nextLevelOf(24)?.id, 25);
    expect(nextLevelOf(25)?.id, 26);
    expect(nextLevelOf(50), isNull);
    expect(levelById(999).id, 1);
  });

  test('章节区间连续覆盖全部关卡', () {
    expect(kChapters, hasLength(2));
    expect(kChapters.first.fromLevel, 1);
    expect(kChapters.last.toLevel, kLevels.length);
    for (var index = 0; index < kChapters.length; index++) {
      final chapter = kChapters[index];
      expect(levelsOfChapter(chapter), hasLength(chapter.levelCount));
      if (index > 0) {
        expect(chapter.fromLevel, kChapters[index - 1].toLevel + 1);
      }
      for (final level in levelsOfChapter(chapter)) {
        expect(chapterOfLevel(level.id), same(chapter));
      }
    }
    expect(chapterOfLevel(1).id, 1);
    expect(chapterOfLevel(26).id, 2);
    expect(chapterOfLevel(50).id, 2);
  });

  test('第二章为 9×9 满棋子池的进阶关卡', () {
    final chapter = kChapters.last;
    for (final level in levelsOfChapter(chapter)) {
      expect(level.cols, 9);
      expect(level.rows, 9);
      expect(level.palette, TileType.values.length);
      expect(level.goals.length, greaterThanOrEqualTo(2));
    }
  });

  test('章节视图按区间汇总福星，关卡与章节一一对应', () {
    final stars = {1: 3, 2: 2, 25: 1, 26: 3};
    final progress = LevelProgress.scan([
      for (var id = 1; id <= kLevels.length; id++) stars[id] ?? 0,
    ], unlocked: 3);
    final views = chapterViews(progress);

    expect(views, hasLength(kChapters.length));
    expect(views.first.chapter, same(kChapters.first));
    expect(views.first.stars, 6);
    expect(views.first.maxStars, 75);
    expect(views.first.levels, hasLength(25));
    expect(views.first.levels.first.id, 1);
    expect(views.first.levels.last.id, 25);
    expect(views.last.stars, 3);
    expect(views.last.levels.first.id, 26);
    expect(views.fold<int>(0, (sum, view) => sum + view.maxStars), 150);
  });
}
