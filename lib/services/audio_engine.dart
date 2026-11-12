import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// SoLoud 引擎的初始化闸门。
///
/// 音效与背景音乐共用同一个原生引擎，但两者启动时机不同。若各自调用
/// [SoLoud.init]，后一次调用会把已初始化的引擎销毁重建，先加载好的音源
/// 随之失效，表现为只有背景音乐、听不到音效。这里做单飞初始化：并发调用
/// 共享同一个 Future，进程内只会初始化一次。
class AudioEngine {
  AudioEngine._();

  static Future<void>? _starting;
  static bool _ready = false;

  /// 测试注入的初始化动作，非空时不再触碰平台播放器。
  @visibleForTesting
  static Future<void> Function()? initOverride;

  static bool get isReady => _ready;

  /// 确保引擎可用；初始化失败时抛出异常，调用方可稍后重试。
  static Future<void> ensureReady() {
    if (_ready) return Future.value();
    final starting = _starting;
    if (starting != null) return starting;
    final future = _start();
    _starting = future;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  static Future<void> _start() async {
    final init = initOverride;
    if (init != null) {
      await init();
    } else {
      final soloud = SoLoud.instance;
      // 原生引擎已在运行时不再调用 init，避免重建引擎让已加载的音源失效。
      if (!soloud.isInitialized) await soloud.init();
    }
    _ready = true;
  }

  /// 播放失败时标记引擎状态待复核，下次 [ensureReady] 会重新校验。
  static void markLost() {
    _ready = false;
  }

  @visibleForTesting
  static void reset() {
    initOverride = null;
    _starting = null;
    _ready = false;
  }
}
