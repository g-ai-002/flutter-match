import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/achievements.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('成就定义唯一且目标值合法', () {
    final ids = kAchievements.map((item) => item.id).toSet();
    expect(ids, hasLength(kAchievements.length));
    for (final achievement in kAchievements) {
      expect(achievement.title.isNotEmpty, isTrue);
      expect(achievement.description.isNotEmpty, isTrue);
      expect(achievement.target, greaterThan(0));
    }
  });

  test('按统计口径计算解锁与进度', () {
    const empty = PlayerStats();
    final statuses = evaluateAchievements(empty);
    expect(statuses, hasLength(kAchievements.length));
    expect(statuses.every((status) => !status.unlocked), isTrue);
    expect(statuses.every((status) => status.progress == 0), isTrue);
    expect(unlockedAchievementCount(empty), 0);

    const some = PlayerStats(
      cleared: 10,
      perfect: 1,
      stars: 32,
      dailyClears: 1,
      maxCombo: 5,
      iceBroken: 99,
      propsUsed: 3,
    );
    final someStatuses = {
      for (final status in evaluateAchievements(some))
        status.achievement.id: status,
    };
    expect(someStatuses['first_clear']!.unlocked, isTrue);
    expect(someStatuses['clear_10']!.unlocked, isTrue);
    expect(someStatuses['clear_25']!.unlocked, isFalse);
    expect(someStatuses['perfect_1']!.unlocked, isTrue);
    expect(someStatuses['stars_60']!.unlocked, isFalse);
    expect(someStatuses['daily_1']!.unlocked, isTrue);
    expect(someStatuses['combo_5']!.unlocked, isTrue);
    expect(someStatuses['ice_100']!.unlocked, isFalse);
    expect(someStatuses['ice_100']!.remaining, 1);
    expect(unlockedAchievementCount(some), 5);
  });

  test('通关、三星与累计统计进入成就进度', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    await storage.recordLevelResult(
      levelId: 1,
      stars: 3,
      score: 5000,
      levelCount: kLevels.length,
    );
    await storage.recordLevelResult(
      levelId: 2,
      stars: 2,
      score: 3000,
      levelCount: kLevels.length,
    );
    await settings.recordStats(maxCombo: 4, iceBroken: 12, propsUsed: 2);

    final stats = settings.playerStats;
    expect(stats.cleared, 2);
    expect(stats.perfect, 1);
    expect(stats.stars, 5);
    expect(stats.maxCombo, 4);
    expect(stats.iceBroken, 12);
    expect(stats.propsUsed, 2);
  });
}
