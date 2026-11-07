import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/board_component.dart';
import 'package:fortune_match/flame/match_game.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/services/sound_service.dart';

void _paint(BoardComponent board) {
  final recorder = ui.PictureRecorder();
  board.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

Future<void> _settle(BoardComponent board, {int frames = 60}) async {
  for (var frame = 0; frame < frames; frame++) {
    board.update(1 / 60);
    _paint(board);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('空闲时停止逐帧推进，点选与提示会重新唤醒', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 12);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      final activity = <bool>[];
      board.onActivityChanged = activity.add;
      await board.onLoad();
      board.size = Vector2(480, 480);

      await _settle(board);
      expect(board.needsFrames, isFalse, reason: '贴图预热完成后应进入空闲');
      expect(activity, isNotEmpty);
      expect(activity.last, isFalse);

      // 点选只是一次性变化：唤醒画一帧后重新空闲。
      controller.tapCell(0);
      expect(board.needsFrames, isTrue);
      expect(activity.last, isTrue);
      board.update(1 / 60);
      _paint(board);
      expect(board.needsFrames, isFalse);
      expect(activity.last, isFalse);

      // 提示需要逐帧脉冲，期间不复用静止画面。
      controller.requestHint();
      expect(board.needsFrames, isTrue);
      final builds = board.painter.staticFrameBuilds;
      board.update(1 / 60);
      _paint(board);
      board.update(1 / 60);
      _paint(board);
      expect(board.painter.staticFrameBuilds, builds);

      // 重开清掉提示后重新回到空闲。
      controller.restart();
      await _settle(board);
      expect(board.needsFrames, isFalse);

      board.onRemove();
      controller.dispose();
    });
  });

  testWidgets('棋盘空闲时暂停 Flame 引擎循环，操作后恢复', (tester) async {
    final controller = MatchController(level: kLevels.first, seed: 3);
    final game = MatchGame(
      controller: controller,
      darkMode: ValueNotifier(false),
    );

    game.handleActivity(false);
    expect(game.idlePaused, isTrue);
    expect(game.paused, isTrue);

    game.handleActivity(true);
    expect(game.idlePaused, isFalse);
    expect(game.paused, isFalse, reason: '操作后应立即恢复循环');

    // 重复通知不重复切换。
    game.handleActivity(true);
    expect(game.paused, isFalse);
    controller.dispose();
  });
}
