import 'progress.dart';

/// 成就统计口径：全部来自本地进度与累计计数器。
enum AchievementMetric {
  cleared('通关关卡'),
  perfect('三星关卡'),
  stars('累计福星'),
  dailyClears('每日挑战'),
  maxCombo('最高连锁'),
  iceBroken('累计破冰'),
  propsUsed('使用道具');

  const AchievementMetric(this.label);

  final String label;
}

class PlayerStats {
  const PlayerStats({
    this.cleared = 0,
    this.perfect = 0,
    this.stars = 0,
    this.dailyClears = 0,
    this.maxCombo = 0,
    this.iceBroken = 0,
    this.propsUsed = 0,
  });

  /// 关卡进度直接取自 [LevelProgress]，累计计数器单独传入。
  factory PlayerStats.fromProgress(
    LevelProgress progress, {
    int dailyClears = 0,
    int maxCombo = 0,
    int iceBroken = 0,
    int propsUsed = 0,
  }) => PlayerStats(
    cleared: progress.cleared,
    perfect: progress.perfect,
    stars: progress.totalStars,
    dailyClears: dailyClears,
    maxCombo: maxCombo,
    iceBroken: iceBroken,
    propsUsed: propsUsed,
  );

  final int cleared;
  final int perfect;
  final int stars;
  final int dailyClears;
  final int maxCombo;
  final int iceBroken;
  final int propsUsed;

  int valueOf(AchievementMetric metric) => switch (metric) {
    AchievementMetric.cleared => cleared,
    AchievementMetric.perfect => perfect,
    AchievementMetric.stars => stars,
    AchievementMetric.dailyClears => dailyClears,
    AchievementMetric.maxCombo => maxCombo,
    AchievementMetric.iceBroken => iceBroken,
    AchievementMetric.propsUsed => propsUsed,
  };
}

/// 单条成就定义：达到 [target] 即解锁。
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final AchievementMetric metric;
  final int target;
}

const List<Achievement> kAchievements = [
  Achievement(
    id: 'first_clear',
    title: '初入福门',
    description: '通关任意一关',
    metric: AchievementMetric.cleared,
    target: 1,
  ),
  Achievement(
    id: 'clear_10',
    title: '十关通途',
    description: '累计通关 10 关',
    metric: AchievementMetric.cleared,
    target: 10,
  ),
  Achievement(
    id: 'clear_25',
    title: '半壁福星',
    description: '通关第一章全部 25 关',
    metric: AchievementMetric.cleared,
    target: 25,
  ),
  Achievement(
    id: 'clear_50',
    title: '福运满堂',
    description: '通关全部 50 关',
    metric: AchievementMetric.cleared,
    target: 50,
  ),
  Achievement(
    id: 'perfect_1',
    title: '三星初现',
    description: '首次拿到三星评价',
    metric: AchievementMetric.perfect,
    target: 1,
  ),
  Achievement(
    id: 'perfect_10',
    title: '满堂喝彩',
    description: '10 个关卡拿到三星',
    metric: AchievementMetric.perfect,
    target: 10,
  ),
  Achievement(
    id: 'stars_60',
    title: '星海拾贝',
    description: '累计收集 60 颗福星',
    metric: AchievementMetric.stars,
    target: 60,
  ),
  Achievement(
    id: 'stars_120',
    title: '星罗棋布',
    description: '累计收集 120 颗福星',
    metric: AchievementMetric.stars,
    target: 120,
  ),
  Achievement(
    id: 'daily_1',
    title: '每日一福',
    description: '完成一次每日挑战',
    metric: AchievementMetric.dailyClears,
    target: 1,
  ),
  Achievement(
    id: 'daily_7',
    title: '七日有福',
    description: '累计完成 7 天每日挑战',
    metric: AchievementMetric.dailyClears,
    target: 7,
  ),
  Achievement(
    id: 'combo_5',
    title: '连锁高手',
    description: '单局打出 5 连及以上',
    metric: AchievementMetric.maxCombo,
    target: 5,
  ),
  Achievement(
    id: 'ice_100',
    title: '破冰百块',
    description: '累计敲碎 100 层冰',
    metric: AchievementMetric.iceBroken,
    target: 100,
  ),
  Achievement(
    id: 'props_20',
    title: '巧用百物',
    description: '累计使用 20 次道具',
    metric: AchievementMetric.propsUsed,
    target: 20,
  ),
];

class AchievementStatus {
  const AchievementStatus(this.achievement, this.value);

  final Achievement achievement;
  final int value;

  bool get unlocked => value >= achievement.target;

  double get progress =>
      achievement.target == 0 ? 1 : (value / achievement.target).clamp(0, 1);

  int get remaining => (achievement.target - value).clamp(0, 1 << 30);
}

List<AchievementStatus> evaluateAchievements(PlayerStats stats) => [
  for (final achievement in kAchievements)
    AchievementStatus(achievement, stats.valueOf(achievement.metric)),
];

int unlockedAchievementCount(PlayerStats stats) =>
    evaluateAchievements(stats).where((status) => status.unlocked).length;
