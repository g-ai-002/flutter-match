import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/services/music_service.dart';
import 'package:fortune_match/services/sound_service.dart';

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
}
