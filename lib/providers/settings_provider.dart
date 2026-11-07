import 'dart:async';

import 'package:flutter/foundation.dart';

import '../game/logic_rate.dart';
import '../services/music_service.dart';
import '../services/sound_service.dart';
import '../services/storage_service.dart';

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

  int starsFor(int levelId) => _storage.starsFor(levelId);
  int bestScoreFor(int levelId) => _storage.bestScoreFor(levelId);
  int get unlockedLevel => _storage.unlockedLevel;
  int totalStars(int levelCount) => _storage.totalStars(levelCount);

  Future<void> recordLevelResult({
    required int levelId,
    required int stars,
    required int score,
    required int levelCount,
  }) => _update(
    () => _storage.recordLevelResult(
      levelId: levelId,
      stars: stars,
      score: score,
      levelCount: levelCount,
    ),
  );

  Future<void> resetProgress() => _update(_storage.resetProgress);

  void _syncFeedback() =>
      SoundService.configure(sound: soundEnabled, haptics: hapticsEnabled);

  /// 写入偏好后统一通知界面，避免每个 setter 重复一遍。
  Future<void> _update(Future<void> Function() write) async {
    await write();
    notifyListeners();
  }
}
