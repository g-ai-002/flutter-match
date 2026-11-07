import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/achievements.dart';
import '../game/levels.dart';
import '../game/logic_rate.dart';
import '../game/progress.dart';
import '../game/props.dart';
import '../game/scoring.dart';
import '../models/level.dart';
import '../services/music_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';
import '../theme/skins.dart';

/// 用户偏好：主题、逻辑速率与音效反馈。
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _syncFeedback();
  }

  final StorageService _storage;

  bool get darkMode => _storage.darkMode;
  Future<void> setDarkMode(bool value) =>
      _update(() => _storage.setDarkMode(value));

  bool get soundEnabled => _storage.soundEnabled;
  Future<void> setSoundEnabled(bool value) => _update(() async {
    await _storage.setSoundEnabled(value);
    _syncFeedback();
  });

  bool get musicEnabled => _storage.musicEnabled;
  Future<void> setMusicEnabled(bool value) => _update(() async {
    await _storage.setMusicEnabled(value);
    // 音频启停不阻塞开关反馈，加载失败时 MusicService 自行记录日志。
    unawaited(MusicService.setEnabled(value));
  });

  bool get hapticsEnabled => _storage.hapticsEnabled;
  Future<void> setHapticsEnabled(bool value) => _update(() async {
    await _storage.setHapticsEnabled(value);
    _syncFeedback();
  });

  LogicRate get logicRate => _storage.logicRate;
  Future<void> setLogicRate(LogicRate value) =>
      _update(() => _storage.setLogicRate(value));

  AppSkin get skin => _storage.skin;
  Future<void> setSkin(AppSkin value) => _update(() => _storage.setSkin(value));

  LevelProgress? _progress;
  PlayerStats? _stats;
  List<AchievementStatus>? _achievements;

  /// 关卡进度汇总（福星、通关、三星与解锁），写入后按需重建。
  LevelProgress get progress =>
      _progress ??= _storage.scanProgress(kLevels.length);

  /// 成就统计：关卡进度取自 [progress]，累计计数器来自本地存储。
  PlayerStats get playerStats {
    final cached = _stats;
    if (cached != null) return cached;
    return _stats = PlayerStats.fromProgress(
      progress,
      dailyClears: _storage.dailyClears,
      maxCombo: _storage.maxCombo,
      iceBroken: _storage.iceBroken,
      propsUsed: _storage.propsUsed,
    );
  }

  List<AchievementStatus> get achievements =>
      _achievements ??= evaluateAchievements(playerStats);

  int get totalStars => progress.totalStars;
  int get clearedCount => progress.cleared;

  /// 对局结束时累计成就统计。
  Future<void> recordStats({
    int maxCombo = 0,
    int iceBroken = 0,
    int propsUsed = 0,
  }) async {
    await _storage.recordStats(
      maxCombo: maxCombo,
      iceBroken: iceBroken,
      propsUsed: propsUsed,
    );
    _invalidateStats();
    notifyListeners();
  }

  int starsFor(int levelId) => progress.starsOf(levelId);
  int bestScoreFor(int levelId) => _storage.bestScoreFor(levelId);
  int get unlockedLevel => _storage.unlockedLevel;

  /// 福币余额与道具库存。
  int get coins => _storage.coins;
  int propCount(PropKind kind) => _storage.propCount(kind);

  /// 购买一枚道具：扣除福币后直接补充到局内库存。
  ///
  /// 库存变化由 [PropStock.onChanged] 负责落盘，避免同一数量写两次。
  Future<bool> buyProp(PropKind kind, PropStock stock) async {
    if (coins < kind.price) return false;
    await _storage.addCoins(-kind.price);
    stock.add(kind);
    notifyListeners();
    return true;
  }

  Future<void> setPropCount(PropKind kind, int value) async {
    await _storage.setPropCount(kind, value);
    notifyListeners();
  }

  int dailyStars(String dateKey) => _storage.dailyStars(dateKey);
  int dailyBestScore(String dateKey) => _storage.dailyBestScore(dateKey);

  /// 通关结算：发放福币并记录闯关或每日挑战成绩。
  ///
  /// 返回值是每日挑战当天首次通关的额外福币奖励，闯关关卡返回 0。
  Future<int> recordWin({
    required Level level,
    required int stars,
    required int score,
    required int levelCount,
  }) async {
    await _storage.addCoins(ScoreRules.rewardCoins(stars));
    final dailyReward = level.isDaily
        ? await _storage.recordDailyResult(
            dateKey: level.dailyKey!,
            stars: stars,
            score: score,
          )
        : 0;
    if (!level.isDaily) {
      await _storage.recordLevelResult(
        levelId: level.id,
        stars: stars,
        score: score,
        levelCount: levelCount,
      );
    }
    _invalidateProgress();
    notifyListeners();
    return dailyReward;
  }

  Future<void> resetProgress() async {
    await _storage.resetProgress();
    _invalidateProgress();
    notifyListeners();
  }

  void _syncFeedback() =>
      SoundService.configure(sound: soundEnabled, haptics: hapticsEnabled);

  /// 关卡星级变化后同时失效进度、成就统计与成就列表。
  void _invalidateProgress() {
    _progress = null;
    _invalidateStats();
  }

  /// 只失效成就相关缓存，关卡进度保持不变。
  void _invalidateStats() {
    _stats = null;
    _achievements = null;
  }

  /// 写入偏好后统一通知界面，避免每个 setter 重复一遍。
  Future<void> _update(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }
}
