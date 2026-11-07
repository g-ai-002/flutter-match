import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/achievements.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/progress.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('一次遍历统计福星、通关与三星', () {
    final progress = LevelProgress.scan(const [3, 2, 0, 1, 3], unlocked: 4);
    expect(progress.levelCount, 5);
    expect(progress.maxStars, 15);
    expect(progress.totalStars, 9);
    expect(progress.cleared, 4);
    expect(progress.perfect, 2);
    expect(progress.unlocked, 4);
    expect(progress.isCleared, isFalse);
    expect(LevelProgress.empty.isCleared, isFalse);
  });

  test('按关卡取星与区间汇总都做边界裁剪', () {
    final progress = LevelProgress.scan(const [3, 1, 2], unlocked: 1);
    expect(progress.starsOf(1), 3);
    expect(progress.starsOf(3), 2);
    expect(progress.starsOf(0), 0);
    expect(progress.starsOf(4), 0);
    expect(progress.starsIn(1, 3), 6);
    expect(progress.starsIn(2, 99), 3);
    expect(progress.starsIn(-5, 1), 3);
    expect(progress.starsIn(3, 2), 0);
  });

  test('成就统计直接复用关卡进度', () {
    final progress = LevelProgress.scan(const [3, 1, 0], unlocked: 3);
    final stats = PlayerStats.fromProgress(
      progress,
      dailyClears: 2,
      maxCombo: 6,
      iceBroken: 30,
      propsUsed: 4,
    );
    expect(stats.cleared, 2);
    expect(stats.perfect, 1);
    expect(stats.stars, 4);
    expect(stats.dailyClears, 2);
    expect(stats.valueOf(AchievementMetric.maxCombo), 6);
    expect(stats.valueOf(AchievementMetric.stars), 4);
  });

  test('通关后进度与成就缓存自动失效', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    expect(settings.progress.totalStars, 0);
    expect(settings.starsFor(2), 0);

    await settings.recordWin(
      level: levelById(2),
      stars: 3,
      score: 4200,
      levelCount: kLevels.length,
    );

    expect(settings.progress.totalStars, 3);
    expect(settings.progress.cleared, 1);
    expect(settings.progress.perfect, 1);
    expect(settings.starsFor(2), 3);
    expect(settings.unlockedLevel, 3);
    expect(settings.achievements.first.unlocked, isTrue);
  });

  test('累计统计后成就列表刷新', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    expect(settings.achievements.every((status) => !status.unlocked), isTrue);

    await settings.recordStats(maxCombo: 5, iceBroken: 3);

    final statuses = {
      for (final status in settings.achievements)
        status.achievement.id: status.unlocked,
    };
    expect(statuses['combo_5'], isTrue);
    expect(statuses['ice_100'], isFalse);
  });

  test('重置进度后缓存回到初始值', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await settings.recordWin(
      level: levelById(1),
      stars: 3,
      score: 3000,
      levelCount: kLevels.length,
    );
    expect(settings.progress.totalStars, 3);

    await settings.resetProgress();

    expect(settings.progress.totalStars, 0);
    expect(settings.progress.cleared, 0);
    expect(settings.unlockedLevel, 1);
    expect(settings.achievements.every((status) => !status.unlocked), isTrue);
  });
}
