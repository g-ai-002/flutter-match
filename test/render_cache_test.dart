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

  testWidgets('启动预热到点后重录贴图与静止画面（Web 字体晚到兜底）', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 8);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(480, 480);

      _paint(board);
      expect(board.painter.staticFrameBuilds, 1);

      // 1.5 秒预热点之前只重放缓存。
      for (var frame = 0; frame < 60; frame++) {
        board.update(1 / 60);
        _paint(board);
      }
      expect(board.painter.staticFrameBuilds, 1);

      // 越过预热点后贴图与静止画面重录一次，字体就绪的纹样随之生效。
      for (var frame = 0; frame < 40; frame++) {
        board.update(1 / 60);
      }
      _paint(board);
      expect(board.painter.staticFrameBuilds, 2);
      _paint(board);
      expect(board.painter.staticFrameBuilds, 2);

      board.removeFromParent();
      controller.dispose();
    });
  });

  testWidgets('冰面坐标只在版本变化时重建，逐帧不再扫描整盘', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels[4], seed: 11);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(560, 560);

      _paint(board);
      expect(board.painter.iceListBuilds, 1);

      // 冰面静止期间每帧都画，但不重建坐标表。
      for (var frame = 0; frame < 60; frame++) {
        board.update(1 / 60);
        _paint(board);
      }
      expect(board.painter.iceListBuilds, 1);

      // 一次落子最多让冰层版本变一次，动画期间只重建一次。
      controller.requestHint();
      final hint = controller.hint!;
      controller.swap(hint.a, hint.b);
      for (var frame = 0; frame < 150; frame++) {
        board.update(1 / 60);
        _paint(board);
      }
      expect(board.painter.iceListBuilds, lessThanOrEqualTo(2));

      board.onRemove();
      controller.dispose();
    });
  });

  testWidgets('静态缓存帧与逐帧绘制像素一致，棋子没有被裁掉', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 21);
      final board = BoardComponent(
        controller: controller,
        darkMode: ValueNotifier(false),
      );
      await board.onLoad();
      board.size = Vector2(560, 560);

      final cached = ui.PictureRecorder();
      board.render(ui.Canvas(cached));
      final cachedPicture = cached.endRecording();
      final cachedImage = await cachedPicture.toImage(560, 560);
      final cachedData = (await cachedImage.toByteData())!;

      final direct = ui.PictureRecorder();
      board.painter.paint(
        ui.Canvas(direct),
        visuals: board.visuals,
        sparks: const [],
        time: 0,
      );
      final directPicture = direct.endRecording();
      final directImage = await directPicture.toImage(560, 560);
      final directData = (await directImage.toByteData())!;

      var different = 0;
      var colored = 0;
      for (var offset = 0; offset < cachedData.lengthInBytes; offset += 4) {
        final r = cachedData.getUint8(offset);
        final g = cachedData.getUint8(offset + 1);
        final b = cachedData.getUint8(offset + 2);
        if (r != directData.getUint8(offset) ||
            g != directData.getUint8(offset + 1) ||
            b != directData.getUint8(offset + 2)) {
          different++;
        }
        if ((r - g).abs() > 30 || (g - b).abs() > 30 || (b - r).abs() > 30) {
          colored++;
        }
      }
      expect(different, 0, reason: '缓存帧必须与逐帧绘制完全一致');
      // 底板是低饱和的米色，彩色像素主要来自棋子，数量不足说明棋子没画出来。
      expect(colored, greaterThan(50000));

      cachedPicture.dispose();
      directPicture.dispose();
      cachedImage.dispose();
      directImage.dispose();
      board.removeFromParent();
      controller.dispose();
    });
  });
}
