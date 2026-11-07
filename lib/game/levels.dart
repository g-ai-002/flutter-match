import '../models/level.dart';
import 'chapters.dart';
import 'level_catalog.dart';
import 'progress.dart';

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

/// 章节关卡表：启动时按章节一次性分好组，界面不再逐项扫描全量关卡。
final Map<int, List<Level>> _levelsByChapter = {
  for (final chapter in kChapters)
    chapter.id: [
      for (final level in kLevels)
        if (chapter.contains(level.id)) level,
    ],
};

List<Level> levelsOfChapter(Chapter chapter) =>
    _levelsByChapter[chapter.id] ?? const [];

/// 章节视图：章节定义、本章关卡与福星进度，供关卡选择页一次构建。
class ChapterView {
  const ChapterView({
    required this.chapter,
    required this.levels,
    required this.stars,
  });

  final Chapter chapter;
  final List<Level> levels;
  final int stars;

  int get maxStars => levels.length * 3;
}

List<ChapterView> chapterViews(LevelProgress progress) => [
  for (final chapter in kChapters)
    ChapterView(
      chapter: chapter,
      levels: levelsOfChapter(chapter),
      stars: progress.starsIn(chapter.fromLevel, chapter.toLevel),
    ),
];
