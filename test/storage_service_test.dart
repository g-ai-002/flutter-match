import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/daily_challenge.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/logic_rate.dart';
import 'package:fortune_match/game/props.dart';
import 'package:fortune_match/game/scoring.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StorageService.resetForTests();
  });

  test('通关后记录星级、最高分并解锁下一关', () async {
    final storage = await StorageService.instance;
    expect(storage.unlockedLevel, 1);
    expect(storage.starsFor(1), 0);

    await storage.recordLevelResult(
      levelId: 1,
      stars: 2,
      score: 3200,
      levelCount: kLevels.length,
    );
    expect(storage.starsFor(1), 2);
    expect(storage.bestScoreFor(1), 3200);
    expect(storage.unlockedLevel, 2);
    expect(storage.totalStars(kLevels.length), 2);
    expect(storage.clearedCount(kLevels.length), 1);

    // 更差的成绩不会覆盖旧记录。
    await storage.recordLevelResult(
      levelId: 1,
      stars: 1,
      score: 2000,
      levelCount: kLevels.length,
    );
    expect(storage.starsFor(1), 2);
    expect(storage.bestScoreFor(1), 3200);
  });

  test('最后一关通关不会解锁越界关卡', () async {
    final storage = await StorageService.instance;
    await storage.recordLevelResult(
      levelId: kLevels.length,
      stars: 3,
      score: 12000,
      levelCount: kLevels.length,
    );
    expect(storage.unlockedLevel, 1);
    expect(storage.starsFor(kLevels.length), 3);
  });

  test('重置进度只清理关卡数据', () async {
    final storage = await StorageService.instance;
    await storage.setDarkMode(true);
    await storage.setLogicRate(LogicRate.hz30);
    await storage.recordLevelResult(
      levelId: 2,
      stars: 3,
      score: 5000,
      levelCount: kLevels.length,
    );
    expect(storage.unlockedLevel, 3);

    await storage.resetProgress();
    expect(storage.unlockedLevel, 1);
    expect(storage.starsFor(1), 0);
    expect(storage.bestScoreFor(2), 0);
    expect(storage.darkMode, isTrue);
    expect(storage.logicRate, LogicRate.hz30);
  });

  test('逻辑速率未设置时回退到 60Hz', () async {
    final storage = await StorageService.instance;
    expect(storage.logicRate, LogicRate.hz60);
    await storage.setLogicRate(LogicRate.hz120);
    expect(storage.logicRate, LogicRate.hz120);
  });

  test('福币与道具库存持久化，余额不会变成负数', () async {
    final storage = await StorageService.instance;
    expect(storage.coins, 0);
    expect(storage.propCount(PropKind.hammer), PropKind.hammer.initialStock);

    await storage.addCoins(100);
    expect(storage.coins, 100);
    await storage.setPropCount(PropKind.hammer, 5);
    expect(storage.propCount(PropKind.hammer), 5);
    await storage.addCoins(-150);
    expect(storage.coins, 0);
    await storage.setPropCount(PropKind.hammer, -3);
    expect(storage.propCount(PropKind.hammer), 0);
  });

  test('福币足够时购买道具，不足时保持不变', () async {
    final storage = await StorageService.instance;
    await storage.addCoins(PropKind.shuffle.price + 5);
    final settings = SettingsProvider(storage);
    final stock = PropStock({
      PropKind.shuffle: 0,
      PropKind.swap: 0,
    }, (kind, count) => storage.setPropCount(kind, count));

    expect(await settings.buyProp(PropKind.shuffle, stock), isTrue);
    expect(stock.count(PropKind.shuffle), 1);
    expect(settings.coins, 5);

    expect(await settings.buyProp(PropKind.swap, stock), isFalse);
    expect(stock.count(PropKind.swap), 0);
    expect(settings.coins, 5);
  });

  test('通关结算按星级发放福币并记录闯关进度', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);

    final reward = await settings.recordWin(
      level: kLevels.first,
      stars: 2,
      score: 3200,
      levelCount: kLevels.length,
    );

    expect(reward, 0, reason: '闯关关卡没有每日挑战奖励');
    expect(settings.coins, ScoreRules.rewardCoins(2));
    expect(storage.starsFor(kLevels.first.id), 2);
    expect(storage.bestScoreFor(kLevels.first.id), 3200);
    expect(storage.unlockedLevel, 2);
  });

  test('每日挑战结算同时发放星级奖励与首次通关福币', () async {
    final storage = await StorageService.instance;
    final settings = SettingsProvider(storage);
    final daily = DailyChallenge.of(DateTime(2026, 11, 8));

    final first = await settings.recordWin(
      level: daily.level,
      stars: 2,
      score: 3000,
      levelCount: kLevels.length,
    );
    expect(first, DailyChallenge.rewardCoins);
    expect(
      settings.coins,
      ScoreRules.rewardCoins(2) + DailyChallenge.rewardCoins,
    );
    expect(storage.dailyStars(daily.dateKey), 2);
    expect(storage.dailyBestScore(daily.dateKey), 3000);
    expect(storage.unlockedLevel, 1, reason: '每日挑战不影响闯关解锁');
    expect(storage.starsFor(daily.level.id), 0);

    final again = await settings.recordWin(
      level: daily.level,
      stars: 3,
      score: 4200,
      levelCount: kLevels.length,
    );
    expect(again, 0);
    expect(
      settings.coins,
      ScoreRules.rewardCoins(2) +
          DailyChallenge.rewardCoins +
          ScoreRules.rewardCoins(3),
    );
    expect(storage.dailyStars(daily.dateKey), 3);
    expect(storage.dailyBestScore(daily.dateKey), 4200);
  });

  test('每日挑战首次通关发放福币，重复通关不再发放', () async {
    final storage = await StorageService.instance;
    const key = '20261108';

    final reward = await storage.recordDailyResult(
      dateKey: key,
      stars: 2,
      score: 3000,
    );
    expect(reward, DailyChallenge.rewardCoins);
    expect(storage.coins, DailyChallenge.rewardCoins);
    expect(storage.dailyStars(key), 2);
    expect(storage.dailyBestScore(key), 3000);

    final again = await storage.recordDailyResult(
      dateKey: key,
      stars: 3,
      score: 4200,
    );
    expect(again, 0);
    expect(storage.coins, DailyChallenge.rewardCoins);
    expect(storage.dailyStars(key), 3);
    expect(storage.dailyBestScore(key), 4200);

    final failed = await storage.recordDailyResult(
      dateKey: '20261109',
      stars: 0,
      score: 900,
    );
    expect(failed, 0);
    expect(storage.dailyStars('20261109'), 0);
  });
}
