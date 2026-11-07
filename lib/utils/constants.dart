/// Web 端字体：CanvasKit 没有系统中文字体回退，使用 soup_fonts 的思源黑体。
const String kWebFontFamily = 'SourceHanSansCN';

class AppConstants {
  AppConstants._();

  static const String appName = '福运消消乐';
  static const String appSlogan = '三消成趣，福运连连';
  static const String version = '0.1.1';

  static const String prefKeyDarkMode = 'dark_mode';
  static const String prefKeySound = 'sound_enabled';
  static const String prefKeyMusic = 'music_enabled';
  static const String prefKeyHaptics = 'haptics_enabled';
  static const String prefKeyLogicRate = 'logic_rate';
  static const String prefKeyStars = 'level_stars';
  static const String prefKeyBestScore = 'level_best_score';
  static const String prefKeyUnlocked = 'level_unlocked';

  /// 单关星级的存储键：`stars_<levelId>`。
  static String starsKey(int levelId) => 'stars_$levelId';

  /// 单关最高分的存储键：`best_<levelId>`。
  static String bestScoreKey(int levelId) => 'best_$levelId';
}
