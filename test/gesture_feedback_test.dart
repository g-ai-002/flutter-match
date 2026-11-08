import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/board_component.dart';
import 'package:fortune_match/flame/board_painter.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/services/sound_service.dart';

void _paint(BoardComponent board, {SwipePreview? swipe, int revision = 3}) {
  board.painter.layout.fit(Vector2(480, 480));
  final recorder = ui.PictureRecorder();
  board.painter.paint(
    ui.Canvas(recorder),
    visuals: board.visuals,
    sparks: const [],
    time: 0,
    animated: false,
    revision: revision,
    swipe: swipe,
  );
  recorder.endRecording().dispose();
}

Future<Uint8List> _snapshot(
  BoardComponent board, {
  SwipePreview? swipe,
  int revision = 3,
}) async {
  board.painter.layout.fit(Vector2(480, 480));
  final recorder = ui.PictureRecorder();
  board.painter.paint(
    ui.Canvas(recorder),
    visuals: board.visuals,
    sparks: const [],
    time: 0,
    animated: false,
    revision: revision,
    swipe: swipe,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(480, 480);
  final data = (await image.toByteData())!;
  picture.dispose();
  return data.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SoundService.sink = (_) {};
  });

  tearDown(SoundService.reset);

  testWidgets('滑动方向按主导轴判定，幅度不足与越界不产生目标', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 3);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(480, 480);
      _paint(board);
      final cell = board.painter.layout.cell;
      expect(cell, greaterThan(50));

      // 第 1 关是 7×7，格子下标 24 位于棋盘正中。
      expect(board.swipeTarget(24, Vector2(cell, 0)), 25);
      expect(board.swipeTarget(24, Vector2(-cell, 0)), 23);
      expect(board.swipeTarget(24, Vector2(0, cell)), 31);
      expect(board.swipeTarget(24, Vector2(0, -cell)), 17);
      // 斜向拖动取位移更大的轴。
      expect(board.swipeTarget(24, Vector2(cell * 0.8, cell * 0.3)), 25);
      expect(board.swipeTarget(24, Vector2(cell * 0.2, cell * 0.9)), 31);
      // 幅度不足、贴边外推都返回 -1。
      expect(board.swipeTarget(24, Vector2(cell * 0.1, 0)), -1);
      expect(board.swipeTarget(0, Vector2(-cell, 0)), -1);
      expect(board.swipeTarget(0, Vector2(0, -cell)), -1);

      board.onRemove();
      controller.dispose();
    });
  });

  testWidgets('滑动预览只叠加覆盖层，静止棋盘帧仍然复用', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 5);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(480, 480);

      _paint(board);
      final builds = board.painter.staticFrameBuilds;
      const swipe = (from: 24, to: 25, progress: 0.7);
      final plain = await _snapshot(board);
      final preview = await _snapshot(board, swipe: swipe);
      expect(board.painter.staticFrameBuilds, builds, reason: '预览不重建棋盘层');
      var changed = 0;
      for (var i = 0; i < preview.length; i++) {
        if (preview[i] != plain[i]) changed++;
      }
      expect(changed, greaterThan(2000), reason: '预览必须画出方向提示');

      board.onRemove();
      controller.dispose();
    });
  });

  testWidgets('交换双方闪现金色光圈并按时收束', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 9);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(480, 480);

      controller.requestHint();
      final hint = controller.hint!;
      controller.swap(hint.a, hint.b);
      final glowing = board.visuals.where((visual) => visual.glowing).toList();
      expect(glowing, hasLength(2));
      expect(glowing.map((visual) => visual.cell).toSet(), {hint.a, hint.b});

      // 光圈只亮一次，动画结束后全部收束，不再持续占用逐帧刷新。
      for (var frame = 0; frame < 60; frame++) {
        board.update(1 / 60);
      }
      expect(board.visuals.any((visual) => visual.glowing), isFalse);

      board.onRemove();
      controller.dispose();
    });
  });
}
