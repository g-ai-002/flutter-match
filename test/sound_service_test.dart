import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/services/music_service.dart';
import 'package:fortune_match/services/sound_service.dart';

double _peak(Uint8List wav) {
  final view = ByteData.sublistView(wav);
  var peak = 0;
  for (var offset = 44; offset + 1 < wav.length; offset += 2) {
    final value = view.getInt16(offset, Endian.little).abs();
    if (value > peak) peak = value;
  }
  return peak / 32767;
}

void main() {
  tearDown(() {
    SoundService.reset();
    MusicService.reset();
  });

  test('音效开关与触感开关独立生效', () {
    final played = <FeedbackKind>[];
    SoundService.sink = played.add;

    SoundService.configure(sound: true, haptics: false);
    SoundService.play(FeedbackKind.swap);
    SoundService.play(FeedbackKind.clearBig);
    expect(played, [FeedbackKind.swap, FeedbackKind.clearBig]);

    SoundService.configure(sound: false, haptics: false);
    SoundService.play(FeedbackKind.win);
    expect(played, hasLength(2));
  });

  test('背景音乐开关通过注入出口反馈', () async {
    final states = <bool>[];
    MusicService.sink = states.add;
    MusicService.enabled = true;
    await MusicService.start();
    expect(states, [true]);

    await MusicService.setEnabled(false);
    expect(states, [true, false]);
    expect(MusicService.enabled, isFalse);
  });

  test('音效峰值归一化到统一档位，短音效也听得清', () {
    for (final kind in [
      FeedbackKind.swap,
      FeedbackKind.clear,
      FeedbackKind.clearBig,
      FeedbackKind.win,
    ]) {
      expect(
        _peak(SoundService.clipOf(kind)),
        closeTo(0.92, 0.02),
        reason: '${kind.name} 应归一化到固定峰值',
      );
    }
  });
}
