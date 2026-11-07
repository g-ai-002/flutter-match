import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/board_component.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/services/sound_service.dart';

void _paint(BoardComponent board) {
  final recorder = ui.PictureRecorder();
  board.render(ui.Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('无动画时复用静态棋盘帧，状态变化或动画期间重新绘制', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 5);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(480, 480);

      _paint(board);
      expect(board.painter.staticFrameBuilds, 1);

      // 没有任何变化时直接复用上一帧的 Picture。
      _paint(board);
      expect(board.painter.staticFrameBuilds, 1);

      // 选中棋子属于视觉变化，必须失效缓存。
      controller.tapCell(0);
      _paint(board);
      expect(board.painter.staticFrameBuilds, 2);

      // 动画期间逐帧绘制，不再写静态缓存。
      controller.requestHint();
      final hint = controller.hint!;
      controller.swap(hint.a, hint.b);
      final duringAnimation = board.painter.staticFrameBuilds;
      for (var frame = 0; frame < 20; frame++) {
        board.update(1 / 60);
        _paint(board);
      }
      expect(board.painter.staticFrameBuilds, duringAnimation);

      // 动画结束后回到静止状态，重建一次并继续复用。
      for (var frame = 0; frame < 240; frame++) {
        board.update(1 / 60);
      }
      _paint(board);
      final idleBuilds = board.painter.staticFrameBuilds;
      expect(idleBuilds, greaterThan(duringAnimation));
      _paint(board);
      expect(board.painter.staticFrameBuilds, idleBuilds);

      board.removeFromParent();
      controller.dispose();
    });
  });
}
