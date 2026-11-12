import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/services/audio_engine.dart';
import 'package:fortune_match/services/music_service.dart';
import 'package:fortune_match/services/sound_service.dart';

void main() {
  tearDown(() {
    SoundService.reset();
    MusicService.reset();
    AudioEngine.reset();
  });

  test('音效与音乐并发启动只初始化一次引擎', () async {
    var inits = 0;
    final gate = Completer<void>();
    AudioEngine.initOverride = () async {
      inits++;
      await gate.future;
    };

    final first = AudioEngine.ensureReady();
    final second = AudioEngine.ensureReady();
    expect(inits, 1);

    gate.complete();
    await Future.wait([first, second]);
    expect(inits, 1);
    expect(AudioEngine.isReady, isTrue);

    await AudioEngine.ensureReady();
    expect(inits, 1);
  });

  test('初始化失败后允许重试，成功后不再重复初始化', () async {
    var inits = 0;
    AudioEngine.initOverride = () async {
      inits++;
      if (inits == 1) throw StateError('音频设备暂不可用');
    };

    await expectLater(AudioEngine.ensureReady(), throwsStateError);
    expect(AudioEngine.isReady, isFalse);

    await AudioEngine.ensureReady();
    expect(inits, 2);
    expect(AudioEngine.isReady, isTrue);

    await AudioEngine.ensureReady();
    expect(inits, 2);
  });
}
