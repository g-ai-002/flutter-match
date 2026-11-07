import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/board_layout.dart';

void main() {
  test('按较长边留白并居中排布棋盘', () {
    final layout = BoardLayout(cols: 5, rows: 5);
    layout.fit(Vector2(500, 300));
    // padding = 300 * 0.02 + 4 = 10，格子边长取宽高可用空间的较小值。
    expect(layout.cell, 56);
    expect(layout.left, 110);
    expect(layout.top, 10);
    expect(layout.boardRect, const Rect.fromLTWH(110, 10, 280, 280));
  });

  test('格子矩形与中心点一致，坐标越界返回 null', () {
    final layout = BoardLayout(cols: 5, rows: 5)..fit(Vector2(500, 300));
    expect(layout.cellRect(7), const Rect.fromLTWH(110 + 56 * 2, 10 + 56, 56, 56));
    expect(
      layout.cellCenter(7),
      const Offset(110 + 56 * 2.5, 10 + 56 * 1.5),
    );
    expect(layout.cellAt(Vector2(120, 20)), 0);
    expect(layout.cellAt(Vector2(109, 20)), isNull);
    expect(layout.cellAt(Vector2(390, 20)), isNull);
    expect(layout.cellAt(Vector2(120, 290)), isNull);
  });

  test('尺寸未变化时不重复计算，变化后重新排版', () {
    final layout = BoardLayout(cols: 4, rows: 4)..fit(Vector2(400, 400));
    expect(layout.cell, 94);
    expect(layout.left, 12);
    layout.fit(Vector2(400, 400));
    expect(layout.cell, 94);
    layout.fit(Vector2(800, 400));
    // 高度仍是瓶颈，格子保持不变，宽屏下棋盘水平居中。
    expect(layout.cell, 94);
    expect(layout.left, 212);
    expect(layout.top, 12);
  });
}
