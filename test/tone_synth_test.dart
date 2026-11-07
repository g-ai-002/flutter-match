import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/services/sound_service.dart';
import 'package:fortune_match/services/tone_synth.dart';

String _ascii(Uint8List data, int offset, int length) =>
    String.fromCharCodes(data.sublist(offset, offset + length));

int _uint32(Uint8List data, int offset) =>
    ByteData.sublistView(data).getUint32(offset, Endian.little);

void main() {
  test('音效合成为合法 16 位单声道 WAV', () {
    final clip = SoundService.clipOf(FeedbackKind.clear);
    expect(_ascii(clip, 0, 4), 'RIFF');
    expect(_ascii(clip, 8, 4), 'WAVE');
    expect(_ascii(clip, 12, 4), 'fmt ');
    final view = ByteData.sublistView(clip);
    expect(view.getUint16(20, Endian.little), 1);
    expect(view.getUint16(22, Endian.little), 1);
    expect(view.getUint16(34, Endian.little), 16);
    expect(_uint32(clip, 24), kSynthSampleRate);
    expect(clip.length, greaterThan(1000));
  });

  test('不同反馈的音效互不相同且包含真实采样', () {
    final clear = SoundService.clipOf(FeedbackKind.clear);
    final ice = SoundService.clipOf(FeedbackKind.ice);
    final win = SoundService.clipOf(FeedbackKind.win);
    expect(clear.sublist(44, 200), isNot(equals(ice.sublist(44, 200))));
    expect(clear.length == win.length, isFalse);
    expect(
      clear.sublist(44).any((byte) => byte != 0),
      isTrue,
      reason: '合成音频不应全为静音',
    );
  });

  test('背景音乐循环时长约 16 秒', () {
    final music = synthesizeMusicWav();
    final samples = (music.length - 44) ~/ 2;
    expect(samples / kMusicSampleRate, closeTo(kMusicLoopSeconds, 0.05));
    expect(_ascii(music, 0, 4), 'RIFF');
  });

  test('合成结果稳定：同一配方两次输出一致', () {
    final first = synthesizeWav(const [
      SynthNote(frequency: 440, start: 0, duration: 0.1),
    ]);
    final second = synthesizeWav(const [
      SynthNote(frequency: 440, start: 0, duration: 0.1),
    ]);
    expect(first, second);
  });
}
