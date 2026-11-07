import '../models/level.dart';
import 'chapters.dart';
import 'level_catalog.dart';

/// 关卡索引：查询、跳关等访问逻辑；关卡数据见 `level_catalog.dart`。
final List<Level> kLevels = buildLevelCatalog();

Level levelById(int id) =>
    kLevels.firstWhere((level) => level.id == id, orElse: () => kLevels.first);

Level? nextLevelOf(int id) {
  final index = kLevels.indexWhere((level) => level.id == id);
  if (index < 0 || index + 1 >= kLevels.length) return null;
  return kLevels[index + 1];
}

/// 关卡所属章节；编号越界时归入首章。
Chapter chapterOfLevel(int id) => kChapters.firstWhere(
  (chapter) => chapter.contains(id),
  orElse: () => kChapters.first,
);

List<Level> levelsOfChapter(Chapter chapter) => [
  for (final level in kLevels)
    if (chapter.contains(level.id)) level,
];

/// 章节内已获福星与满星数。
int starsInChapter(Chapter chapter, int Function(int levelId) starsFor) {
  var total = 0;
  for (var id = chapter.fromLevel; id <= chapter.toLevel; id++) {
    total += starsFor(id);
  }
  return total;
}
