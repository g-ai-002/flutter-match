import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/board_component.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/services/sound_service.dart';

Future<ByteData> _render(BoardComponent board, int width, int height) async {
  final recorder = ui.PictureRecorder();
  board.render(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  return (await image.toByteData())!;
}

int _opaquePixels(ByteData data) {
  var count = 0;
  for (var offset = 3; offset < data.lengthInBytes; offset += 4) {
    if (data.getUint8(offset) > 200) count++;
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('棋盘渲染出面板与棋子，并能播放完整段消除动画', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 9);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(560, 560);

      final before = await _render(board, 560, 560);
      expect(_opaquePixels(before), greaterThan(100000));

      controller.requestHint();
      final hint = controller.hint!;
      controller.swap(hint.a, hint.b);
      for (var frame = 0; frame < 200; frame++) {
        board.update(1 / 60);
      }

      expect(controller.score, greaterThan(0));
      expect(
        controller.status,
        anyOf(GameStatus.ready, GameStatus.won, GameStatus.lost),
      );
      expect(
        controller.board.tiles.whereType<Object>().length,
        controller.level.cellCount,
      );

      final after = await _render(board, 560, 560);
      expect(_opaquePixels(after), greaterThan(100000));
      board.removeFromParent();
    });
  });

  testWidgets('重排与重开后棋盘视觉会与引擎同步', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 4);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(480, 480);

      controller.shuffleBoard();
      board.update(1 / 60);
      final shuffled = await _render(board, 480, 480);
      expect(_opaquePixels(shuffled), greaterThan(80000));

      controller.restart();
      board.update(1 / 60);
      final restarted = await _render(board, 480, 480);
      expect(_opaquePixels(restarted), greaterThan(80000));
      expect(controller.movesLeft, kLevels.first.moves);
      board.removeFromParent();
    });
  });
}
