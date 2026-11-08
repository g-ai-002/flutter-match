import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'log_service.dart';
import 'music_service.dart';
import 'synth_worker.dart';
import 'tone_synth.dart';

/// 反馈类型，决定提示音与震动的强弱。
enum FeedbackKind {
  swap,
  invalid,
  clear,
  clearBig,
  special,
  ice,
  prop,
  win,
  lose,
}

/// 操作反馈音效与触感。
///
/// 音效由 [synthesizeWav] 在运行时合成，不随包携带音频文件；合成好的
/// WAV 交给 flutter_soloud 的内存音源播放，Android、Windows 与 Web 共用
/// 同一套实现，Web 的自动播放限制会在用户首次操作页面后解除。
class SoundService {
  SoundService._();

  static bool soundEnabled = true;
  static bool hapticsEnabled = true;

  /// 测试注入的音频出口，非空时不再触碰平台播放器。
  @visibleForTesting
  static void Function(FeedbackKind kind)? sink;

  static final Map<FeedbackKind, AudioSource> _sources = {};
  static final Map<FeedbackKind, Uint8List> _clips = {};
  static Future<void>? _loading;
  static bool _loadFailed = false;

  /// 各反馈的乐音配方：三消轻快，连锁上行，破冰带噪声。
  static const Map<FeedbackKind, List<SynthNote>> _presets = {
    FeedbackKind.swap: [
      SynthNote(frequency: 620, start: 0, duration: 0.05, gain: 0.34),
      SynthNote(frequency: 880, start: 0.028, duration: 0.07, gain: 0.3),
    ],
    FeedbackKind.invalid: [
      SynthNote(
        frequency: 240,
        start: 0,
        duration: 0.1,
        noise: 0.2,
        damp: 5,
      ),
      SynthNote(
        frequency: 170,
        start: 0.02,
        duration: 0.12,
        gain: 0.4,
        noise: 0.16,
        damp: 5,
      ),
    ],
    FeedbackKind.clear: [
      SynthNote(frequency: 783.99, start: 0, duration: 0.1, gain: 0.4),
      SynthNote(frequency: 1046.5, start: 0.05, duration: 0.14, gain: 0.36),
      SynthNote(
        frequency: 1318.5,
        start: 0.1,
        duration: 0.16,
        gain: 0.24,
        noise: 0.05,
      ),
    ],
    FeedbackKind.clearBig: [
      SynthNote(frequency: 659.25, start: 0, duration: 0.1, gain: 0.34),
      SynthNote(frequency: 783.99, start: 0.06, duration: 0.1, gain: 0.36),
      SynthNote(frequency: 987.77, start: 0.12, duration: 0.12, gain: 0.38),
      SynthNote(frequency: 1174.66, start: 0.18, duration: 0.14, gain: 0.4),
      SynthNote(
        frequency: 1567.98,
        start: 0.26,
        duration: 0.24,
        gain: 0.3,
        noise: 0.1,
      ),
    ],
    FeedbackKind.special: [
      SynthNote(frequency: 880, start: 0, duration: 0.09, gain: 0.36),
      SynthNote(frequency: 1174.66, start: 0.05, duration: 0.12, gain: 0.34),
      SynthNote(
        frequency: 1760,
        start: 0.1,
        duration: 0.26,
        gain: 0.28,
        noise: 0.22,
      ),
    ],
    FeedbackKind.ice: [
      SynthNote(
        frequency: 1480,
        start: 0,
        duration: 0.08,
        gain: 0.4,
        noise: 0.9,
        damp: 7,
      ),
      SynthNote(
        frequency: 760,
        start: 0.01,
        duration: 0.12,
        gain: 0.34,
        noise: 0.7,
        damp: 6,
      ),
      SynthNote(
        frequency: 320,
        start: 0.02,
        duration: 0.16,
        gain: 0.36,
        noise: 0.4,
        damp: 5,
      ),
    ],
    FeedbackKind.prop: [
      SynthNote(
        frequency: 520,
        start: 0,
        duration: 0.09,
        gain: 0.36,
        noise: 0.35,
        damp: 6,
      ),
      SynthNote(frequency: 1040, start: 0.06, duration: 0.14, gain: 0.32),
      SynthNote(
        frequency: 1560,
        start: 0.1,
        duration: 0.2,
        gain: 0.24,
        noise: 0.12,
      ),
    ],
    FeedbackKind.win: [
      SynthNote(frequency: 523.25, start: 0, duration: 0.14, gain: 0.4),
      SynthNote(frequency: 659.25, start: 0.12, duration: 0.14, gain: 0.4),
      SynthNote(frequency: 783.99, start: 0.24, duration: 0.16, gain: 0.42),
      SynthNote(frequency: 1046.5, start: 0.38, duration: 0.42, gain: 0.44),
    ],
    FeedbackKind.lose: [
      SynthNote(frequency: 440, start: 0, duration: 0.16, gain: 0.36),
      SynthNote(frequency: 349.23, start: 0.14, duration: 0.18, gain: 0.34),
      SynthNote(frequency: 261.63, start: 0.3, duration: 0.4, gain: 0.32),
    ],
  };

  static void configure({required bool sound, required bool haptics}) {
    soundEnabled = sound;
    hapticsEnabled = haptics;
  }

  /// 预合成音效并载入 SoLoud 音源；失败时保持静默，不影响游戏。
  static Future<void> init() => _ensureLoaded();

  static Future<void> _ensureLoaded() {
    if (_loadFailed || _sources.isNotEmpty) return Future.value();
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      final soloud = SoLoud.instance;
      if (!soloud.isInitialized) await soloud.init();
      final clips = await runSynthTask(_synthesizeAll);
      for (final entry in clips.entries) {
        _sources[entry.key] = await soloud.loadMem(
          'fortune-${entry.key.name}.wav',
          entry.value,
        );
      }
    } catch (error) {
      _loadFailed = true;
      _disposeAll();
      debugPrint('[SoundService] 音效初始化失败，已静音: $error');
      LogService.warning('音效初始化失败，已静音: $error');
    }
  }

  /// 一次合成全部反馈音效，交给后台 isolate 统一执行。
  static Map<FeedbackKind, Uint8List> _synthesizeAll() => {
    for (final kind in FeedbackKind.values)
      kind: synthesizeWav(_presets[kind]!),
  };

  /// 某个反馈对应的合成音频，供测试校验音效配方。
  @visibleForTesting
  static Uint8List clipOf(FeedbackKind kind) =>
      _clips.putIfAbsent(kind, () => synthesizeWav(_presets[kind]!));

  /// 选中棋子的轻触感：只走触感，不播放提示音。
  static void tap() {
    if (hapticsEnabled) HapticFeedback.selectionClick();
  }

  static void play(FeedbackKind kind) {
    if (soundEnabled) {
      final target = sink;
      if (target != null) {
        target(kind);
      } else {
        unawaited(_play(kind));
      }
    }
    if (!hapticsEnabled) return;
    final haptic = switch (kind) {
      FeedbackKind.swap => HapticFeedback.selectionClick,
      FeedbackKind.invalid => HapticFeedback.lightImpact,
      FeedbackKind.clear => HapticFeedback.lightImpact,
      FeedbackKind.clearBig => HapticFeedback.mediumImpact,
      FeedbackKind.special => HapticFeedback.mediumImpact,
      FeedbackKind.ice => HapticFeedback.mediumImpact,
      FeedbackKind.prop => HapticFeedback.mediumImpact,
      FeedbackKind.win => HapticFeedback.heavyImpact,
      FeedbackKind.lose => HapticFeedback.vibrate,
    };
    haptic();
  }

  static Future<void> _play(FeedbackKind kind) async {
    try {
      await _ensureLoaded();
      final source = _sources[kind];
      if (source == null) return;
      final soloud = SoLoud.instance;
      soloud.stopAudioSource(source);
      // 合成时已做峰值归一化，按满档播放才能听清；播放期间压低背景音乐。
      soloud.play(source);
      MusicService.duck();
    } catch (error) {
      debugPrint('[SoundService] 播放失败: $error');
    }
  }

  static void _disposeAll() {
    final sources = _sources.values.toList();
    _sources.clear();
    for (final source in sources) {
      unawaited(_dispose(source));
    }
  }

  static Future<void> _dispose(AudioSource source) async {
    try {
      await SoLoud.instance.disposeSource(source);
    } catch (_) {
      // 音源已失效时无需再处理。
    }
  }

  @visibleForTesting
  static void reset() {
    sink = null;
    _disposeAll();
    _clips.clear();
    _loading = null;
    _loadFailed = false;
    soundEnabled = true;
    hapticsEnabled = true;
  }
}
