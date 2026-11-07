import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/services/synth_worker.dart';
import 'package:fortune_match/services/tone_synth.dart';

void main() {
  test('合成任务在后台执行并返回完整 WAV', () async {
    final bytes = await runSynthTask(
      () => synthesizeWav(const [
        SynthNote(frequency: 660, start: 0, duration: 0.05),
      ]),
    );
    expect(bytes.length, greaterThan(44));
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
  });

  test('背景音乐合成任务可跨 isolate 返回样本', () async {
    final bytes = await runSynthTask(() => synthesizeMusicWav());
    const expected = 44 + (kMusicLoopSeconds * kMusicSampleRate) * 2;
    expect(bytes.length, expected);
  });
}
