import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/board_layout.dart';
import 'package:fortune_match/flame/board_painter.dart';
import 'package:fortune_match/flame/tile_sprite_cache.dart';
import 'package:fortune_match/flame/tile_visual.dart';
import 'package:fortune_match/game/levels.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/models/tile.dart';

const int _size = 560;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('棋子画在自己的格子里，不会跑到画布原点', (tester) async {
    await tester.runAsync(() async {
      final controller = MatchController(level: kLevels.first, seed: 5);
      final layout = BoardLayout(
        cols: controller.level.cols,
        rows: controller.level.rows,
      )..fit(Vector2(_size.toDouble(), _size.toDouble()));
      for (var i = 0; i < controller.board.length; i++) {
        controller.board.tiles[i] = null;
      }
      const cell = 24;
      controller.board.tiles[cell] = const Tile(id: 99, type: TileType.coin);
      final visuals = [
        TileVisual(
          id: 99,
          type: TileType.coin,
          special: SpecialType.none,
          cell: cell,
          col: (cell % controller.level.cols).toDouble(),
          row: (cell ~/ controller.level.cols).toDouble(),
        ),
      ];

      final painter = BoardPainter(
        controller: controller,
        layout: layout,
        sprites: TileSpriteCache(),
        darkMode: ValueNotifier(false),
      );
      final recorder = ui.PictureRecorder();
      painter.paint(
        ui.Canvas(recorder),
        visuals: visuals,
        sparks: const [],
        time: 0,
      );
      final image = await recorder.endRecording().toImage(_size, _size);
      final data = (await image.toByteData())!;

      int goldPixels(int x0, int y0, int x1, int y1) {
        var count = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            final offset = (y * _size + x) * 4;
            final r = data.getUint8(offset);
            final g = data.getUint8(offset + 1);
            final b = data.getUint8(offset + 2);
            // 铜钱棋子的主色与暗部，容差覆盖渐变与水印。
            if (r > 140 && r < 250 && g > 90 && g < 210 && b < 110) count++;
          }
        }
        return count;
      }

      final rect = layout.cellRect(cell);
      final inCell = goldPixels(
        rect.left.round(),
        rect.top.round(),
        rect.right.round(),
        rect.bottom.round(),
      );
      // 原点附近只有底板，不应出现棋子颜色。
      final atOrigin = goldPixels(
        0,
        0,
        rect.width.round(),
        rect.height.round(),
      );

      expect(inCell, greaterThan(800), reason: '棋子应画在目标格子里');
      expect(atOrigin, 0, reason: '棋子不应堆在画布原点');

      painter.dispose();
      controller.dispose();
    });
  });
}
