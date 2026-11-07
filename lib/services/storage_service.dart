import 'package:shared_preferences/shared_preferences.dart';

import '../game/daily_challenge.dart';
import '../game/logic_rate.dart';
import '../game/progress.dart';
import '../game/props.dart';
import '../theme/skins.dart';
import '../utils/constants.dart';
import 'log_service.dart';

/// 轻量本地存储：偏好设置与关卡进度，写入失败时记录日志并忽略。
class StorageService {
  static StorageService? _instance;
  SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> get instance async {
    if (_instance != null) return _instance!;
    final service = StorageService._();
    service._prefs = await SharedPreferences.getInstance();
    _instance = service;
    return service;
  }

  /// 仅供测试：清空单例，配合 SharedPreferences 的 mock 数据使用。
  static void resetForTests() => _instance = null;

  SharedPreferences get _p {
    final prefs = _prefs;
    if (prefs == null) throw StateError('StorageService 尚未初始化');
    return prefs;
  }

  Future<void> _write(
    Future<bool> Function(SharedPreferences prefs) action,
  ) async {
    try {
      await action(_p);
    } catch (error) {
      LogService.warning('本地存储写入失败: $error');
    }
  }

  bool get darkMode => _p.getBool(AppConstants.prefKeyDarkMode) ?? false;
  Future<void> setDarkMode(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyDarkMode, value));

  bool get soundEnabled => _p.getBool(AppConstants.prefKeySound) ?? true;
  Future<void> setSoundEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeySound, value));

  bool get musicEnabled => _p.getBool(AppConstants.prefKeyMusic) ?? true;
  Future<void> setMusicEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyMusic, value));

  bool get hapticsEnabled => _p.getBool(AppConstants.prefKeyHaptics) ?? true;
  Future<void> setHapticsEnabled(bool value) =>
      _write((p) => p.setBool(AppConstants.prefKeyHaptics, value));

  /// 逻辑更新速率，未设置或未知值回退到 60Hz。
  LogicRate get logicRate =>
      LogicRate.byName(_p.getString(AppConstants.prefKeyLogicRate));
  Future<void> setLogicRate(LogicRate value) =>
      _write((p) => p.setString(AppConstants.prefKeyLogicRate, value.name));

  AppSkin get skin => AppSkin.byName(_p.getString(AppConstants.prefKeySkin));
  Future<void> setSkin(AppSkin value) =>
      _write((p) => p.setString(AppConstants.prefKeySkin, value.name));

  /// 成就统计，只增不减。
  int get maxCombo => _p.getInt(AppConstants.statMaxCombo) ?? 0;
  int get iceBroken => _p.getInt(AppConstants.statIceBroken) ?? 0;
  int get propsUsed => _p.getInt(AppConstants.statPropsUsed) ?? 0;
  int get dailyClears => _p.getInt(AppConstants.statDailyClears) ?? 0;

  /// 累计一局的成就统计：连锁取最大值，其余累加。
  Future<void> recordStats({
    int maxCombo = 0,
    int iceBroken = 0,
    int propsUsed = 0,
  }) => _write((p) async {
    if (maxCombo > this.maxCombo) {
      await p.setInt(AppConstants.statMaxCombo, maxCombo);
    }
    if (iceBroken > 0) {
      await p.setInt(AppConstants.statIceBroken, this.iceBroken + iceBroken);
    }
    if (propsUsed > 0) {
      await p.setInt(AppConstants.statPropsUsed, this.propsUsed + propsUsed);
    }
    return true;
  });

  int starsFor(int levelId) => _p.getInt(AppConstants.starsKey(levelId)) ?? 0;

  int bestScoreFor(int levelId) =>
      _p.getInt(AppConstants.bestScoreKey(levelId)) ?? 0;

  /// 福币余额。
  int get coins => _p.getInt(AppConstants.prefKeyCoins) ?? 0;

  /// 增减福币，余额不会变成负数。
  Future<void> addCoins(int delta) => _write((p) async {
    final next = coins + delta;
    await p.setInt(AppConstants.prefKeyCoins, next < 0 ? 0 : next);
    return true;
  });

  /// 道具库存；从未写入过时返回首次赠送的数量。
  int propCount(PropKind kind) =>
      _p.getInt(kind.storageKey) ?? kind.initialStock;

  Future<void> setPropCount(PropKind kind, int value) =>
      _write((p) => p.setInt(kind.storageKey, value < 0 ? 0 : value));

  int dailyStars(String dateKey) =>
      _p.getInt(AppConstants.dailyStarsKey(dateKey)) ?? 0;

  int dailyBestScore(String dateKey) =>
      _p.getInt(AppConstants.dailyScoreKey(dateKey)) ?? 0;

  bool dailyRewarded(String dateKey) =>
      _p.getBool(AppConstants.dailyRewardKey(dateKey)) ?? false;

  /// 记录每日挑战成绩；当天首次通关时补发福币并返回奖励数量。
  Future<int> recordDailyResult({
    required String dateKey,
    required int stars,
    required int score,
  }) async {
    if (stars > dailyStars(dateKey)) {
      await _write((p) => p.setInt(AppConstants.dailyStarsKey(dateKey), stars));
    }
    if (score > dailyBestScore(dateKey)) {
      await _write((p) => p.setInt(AppConstants.dailyScoreKey(dateKey), score));
    }
    if (stars <= 0 || dailyRewarded(dateKey)) return 0;
    const reward = DailyChallenge.rewardCoins;
    await _write((p) async {
      await p.setBool(AppConstants.dailyRewardKey(dateKey), true);
      await p.setInt(AppConstants.prefKeyCoins, coins + reward);
      await p.setInt(AppConstants.statDailyClears, dailyClears + 1);
      return true;
    });
    return reward;
  }

  /// 已解锁的最大关卡（从 1 开始）。
  int get unlockedLevel => _p.getInt(AppConstants.prefKeyUnlocked) ?? 1;

  /// 一次遍历汇总关卡进度，福星、通关与三星数量共用这一份结果。
  LevelProgress scanProgress(int levelCount) => LevelProgress.scan([
    for (var id = 1; id <= levelCount; id++) starsFor(id),
  ], unlocked: unlockedLevel);

  /// 记录通关结果：星级与最高分只增不减，并解锁下一关。
  Future<void> recordLevelResult({
    required int levelId,
    required int stars,
    required int score,
    required int levelCount,
  }) => _write((p) async {
    final bestStars = starsFor(levelId);
    if (stars > bestStars) {
      await p.setInt(AppConstants.starsKey(levelId), stars);
    }
    if (score > bestScoreFor(levelId)) {
      await p.setInt(AppConstants.bestScoreKey(levelId), score);
    }
    final next = levelId + 1;
    if (stars > 0 && next <= levelCount && next > unlockedLevel) {
      await p.setInt(AppConstants.prefKeyUnlocked, next);
    }
    return true;
  });

  Future<void> resetProgress() => _write((p) async {
    await p.remove(AppConstants.prefKeyUnlocked);
    for (final key in p.getKeys().toList()) {
      if (key.startsWith('stars_') ||
          key.startsWith('best_') ||
          key.startsWith('stat_')) {
        await p.remove(key);
      }
    }
    return true;
  });
}
