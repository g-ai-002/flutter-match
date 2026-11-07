/// Web 端字体：CanvasKit 没有系统中文字体回退，使用 soup_fonts 的思源黑体。
const String kWebFontFamily = 'SourceHanSansCN';

class AppConstants {
  AppConstants._();

  static const String appName = '福运消消乐';
  static const String version = '0.3.0';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeySound = 'sound_enabled';
  static const String prefKeyMusic = 'music_enabled';
  static const String prefKeyHaptics = 'haptics_enabled';
  static const String prefKeyLogicRate = 'logic_rate';
  static const String prefKeyUnlocked = 'level_unlocked';
  static const String prefKeyCoins = 'fortune_coins';
  static const String prefKeySkin = 'theme_skin';

  /// 成就统计：单局最高连锁、累计破冰、累计使用道具、每日挑战完成天数。
  static const String statMaxCombo = 'stat_max_combo';
  static const String statIceBroken = 'stat_ice_broken';
  static const String statPropsUsed = 'stat_props_used';
  static const String statDailyClears = 'stat_daily_clears';

  /// 单关星级的存储键：`stars_<levelId>`。
  static String starsKey(int levelId) => 'stars_$levelId';

  /// 单关最高分的存储键：`best_<levelId>`。
  static String bestScoreKey(int levelId) => 'best_$levelId';

  /// 每日挑战成绩与奖励的存储键，日期键形如 `20261108`。
  static String dailyStarsKey(String dateKey) => 'daily_stars_$dateKey';
  static String dailyScoreKey(String dateKey) => 'daily_score_$dateKey';
  static String dailyRewardKey(String dateKey) => 'daily_reward_$dateKey';
}
