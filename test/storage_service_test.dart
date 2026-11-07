import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/logic_rate.dart';
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
}
