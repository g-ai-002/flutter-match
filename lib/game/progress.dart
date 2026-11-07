/// 关卡进度汇总：一次遍历得到福星、通关、三星与解锁状态。
///
/// 界面与成就都读这一份快照，避免多次重复扫描关卡星级。
class LevelProgress {
  const LevelProgress._({
    required this.levelStars,
    required this.unlocked,
    required this.totalStars,
    required this.cleared,
    required this.perfect,
  });

  factory LevelProgress.scan(
    Iterable<int> levelStars, {
    required int unlocked,
  }) {
    final stars = List<int>.unmodifiable(levelStars);
    var totalStars = 0;
    var cleared = 0;
    var perfect = 0;
    for (final value in stars) {
      totalStars += value;
      if (value > 0) cleared++;
      if (value >= 3) perfect++;
    }
    return LevelProgress._(
      levelStars: stars,
      unlocked: unlocked,
      totalStars: totalStars,
      cleared: cleared,
      perfect: perfect,
    );
  }

  static const LevelProgress empty = LevelProgress._(
    levelStars: [],
    unlocked: 1,
    totalStars: 0,
    cleared: 0,
    perfect: 0,
  );

  /// 按关卡编号升序排列的星级，下标 `levelId - 1`。
  final List<int> levelStars;

  /// 已解锁的最大关卡编号（从 1 开始）。
  final int unlocked;

  final int totalStars;
  final int cleared;
  final int perfect;

  int get levelCount => levelStars.length;
  int get maxStars => levelCount * 3;
  bool get isCleared => levelCount > 0 && cleared == levelCount;

  /// [levelId] 从 1 开始，越界返回 0。
  int starsOf(int levelId) =>
      levelId >= 1 && levelId <= levelCount ? levelStars[levelId - 1] : 0;

  /// 编号区间 [fromLevel, toLevel] 内的福星总数，越界自动裁剪。
  int starsIn(int fromLevel, int toLevel) {
    final from = fromLevel < 1 ? 1 : fromLevel;
    final to = toLevel > levelCount ? levelCount : toLevel;
    var total = 0;
    for (var id = from; id <= to; id++) {
      total += levelStars[id - 1];
    }
    return total;
  }
}
