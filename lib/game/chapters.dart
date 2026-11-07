/// 章节定义：关卡包按编号区间归档，界面据此分组展示。
class Chapter {
  const Chapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fromLevel,
    required this.toLevel,
  });

  final int id;
  final String title;
  final String subtitle;
  final int fromLevel;
  final int toLevel;

  bool contains(int levelId) => levelId >= fromLevel && levelId <= toLevel;

  int get levelCount => toLevel - fromLevel + 1;
}

const List<Chapter> kChapters = [
  Chapter(
    id: 1,
    title: '第一章 · 福运初启',
    subtitle: '初识三消，点亮灯笼',
    fromLevel: 1,
    toLevel: 25,
  ),
  Chapter(
    id: 2,
    title: '第二章 · 灯月长明',
    subtitle: '冰玉交错，福星高照',
    fromLevel: 26,
    toLevel: 50,
  ),
];
