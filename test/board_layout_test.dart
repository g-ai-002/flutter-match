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

  test('格子矩形与中心点预计算并随尺寸重建', () {
    final layout = BoardLayout(cols: 5, rows: 5)..fit(Vector2(500, 300));
    final rect = layout.cellRect(7);
    final center = layout.cellCenter(7);
    // 热路径直接复用同一对象，不逐帧新建 Rect / Offset。
    expect(identical(layout.cellRect(7), rect), isTrue);
    expect(identical(layout.cellCenter(7), center), isTrue);

    layout.fit(Vector2(500, 500));
    expect(identical(layout.cellRect(7), rect), isFalse);
    expect(layout.cellRect(7).left, layout.left + layout.cell * 2);
    expect(layout.cellCenter(7).dx, layout.left + layout.cell * 2.5);
    expect(layout.boardRect.width, layout.cell * 5);
  });
}
