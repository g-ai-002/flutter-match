import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/daily_challenge.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/logic_rate.dart';
import 'package:fortune_match/game/props.dart';
import 'package:fortune_match/game/scoring.dart';
import 'package:fortune_match/providers/settings_provider.dart';
import 'package:fortune_match/services/storage_service.dart';
import 'package:fortune_match/theme/skins.dart';
import 'package:fortune_match/utils/formatters.dart';
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
    final progress = storage.scanProgress(kLevels.length);
    expect(progress.totalStars, 2);
    expect(progress.cleared, 1);
    expect(progress.starsOf(1), 2);

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

  test('成就统计只增不减，重置进度一并清理', () async {
    final storage = await StorageService.instance;
    expect(storage.maxCombo, 0);
    expect(storage.iceBroken, 0);
    expect(storage.propsUsed, 0);

    await storage.recordStats(maxCombo: 4, iceBroken: 12, propsUsed: 2);
    expect(storage.maxCombo, 4);
    expect(storage.iceBroken, 12);
    expect(storage.propsUsed, 2);

    await storage.recordStats(maxCombo: 2, iceBroken: 3, propsUsed: 1);
    expect(storage.maxCombo, 4, reason: '最高连锁取历史最大值');
    expect(storage.iceBroken, 15);
    expect(storage.propsUsed, 3);

    await storage.recordDailyResult(dateKey: '20261108', stars: 3, score: 5000);
    expect(storage.dailyClears, 1);
    await storage.recordDailyResult(dateKey: '20261108', stars: 3, score: 5200);
    expect(storage.dailyClears, 1, reason: '同一天重复通关不重复计数');

    await storage.resetProgress();
    expect(storage.maxCombo, 0);
    expect(storage.iceBroken, 0);
    expect(storage.propsUsed, 0);
    expect(storage.dailyClears, 0);
  });

  test('主题皮肤选择持久化，未知值回退默认', () async {
    final storage = await StorageService.instance;
    expect(storage.skin, AppSkin.cinnabar);
    await storage.setSkin(AppSkin.celadon);
    expect(storage.skin, AppSkin.celadon);
    await storage.resetProgress();
    expect(storage.skin, AppSkin.celadon, reason: '重置进度不改外观偏好');
  });

  test('无尽模式成绩只增不减并随重置清理', () async {
    final storage = await StorageService.instance;
    expect(storage.endlessBestStage, 0);
    expect(storage.endlessBestScore, 0);

    await storage.recordEndlessResult(stage: 3, score: 5200);
    expect(storage.endlessBestStage, 3);
    expect(storage.endlessBestScore, 5200);

    await storage.recordEndlessResult(stage: 2, score: 9000);
    expect(storage.endlessBestStage, 3, reason: '层数取历史最高');
    expect(storage.endlessBestScore, 9000, reason: '累计分取历史最高');

    final settings = SettingsProvider(storage);
    await settings.recordEndless(stage: 5, totalScore: 12000);
    expect(settings.endlessBestStage, 5);
    expect(settings.endlessBestScore, 12000);

    await storage.resetProgress();
    expect(storage.endlessBestStage, 0);
    expect(storage.endlessBestScore, 0);
  });

  test('每日挑战连胜只在连续日期累加，断签重新计数', () async {
    final storage = await StorageService.instance;
    expect(storage.dailyStreak, 0);

    await storage.recordDailyResult(dateKey: '20261106', stars: 2, score: 3000);
    expect(storage.dailyStreak, 1);

    await storage.recordDailyResult(dateKey: '20261107', stars: 3, score: 3300);
    expect(storage.dailyStreak, 2);

    await storage.recordDailyResult(dateKey: '20261107', stars: 3, score: 3400);
    expect(storage.dailyStreak, 2, reason: '同一天重复通关不增加连胜');

    await storage.recordDailyResult(dateKey: '20261109', stars: 1, score: 2000);
    expect(storage.dailyStreak, 1, reason: '跳过一天后重新计数');

    await storage.resetProgress();
    expect(storage.dailyStreak, 0);
  });

  test('每日连胜断签一天以上不再展示', () async {
    final today = formatDateKey(DateTime.now());

    SharedPreferences.setMockInitialValues({
      'stat_daily_streak': 5,
      'daily_last_date': shiftDateKey(today, -2),
    });
    StorageService.resetForTests();
    final storage = await StorageService.instance;
    expect(storage.dailyStreak, 5);
    expect(SettingsProvider(storage).dailyStreak, 0, reason: '隔天未完成，旧连胜作废');

    SharedPreferences.setMockInitialValues({
      'stat_daily_streak': 5,
      'daily_last_date': shiftDateKey(today, -1),
    });
    StorageService.resetForTests();
    final yesterday = SettingsProvider(await StorageService.instance);
    expect(yesterday.dailyStreak, 5, reason: '昨天完成，今天仍可延续');
  });
}
