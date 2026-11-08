import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/utils/immersive_landscape.dart';

void main() {
  const phone = Size(360, 800);

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('正方形与竖向棋盘在窄屏手机上保持竖屏', () {
    expect(
      shouldImmersiveLandscape(phone, cols: 9, rows: 9),
      isFalse,
      reason: '正方形棋盘横屏后高度受限，格子反而更小',
    );
    expect(shouldImmersiveLandscape(phone, cols: 7, rows: 9), isFalse);
  });

  test('只有横向棋盘在横屏明显更宽敞时才自动横屏', () {
    expect(shouldImmersiveLandscape(phone, cols: 21, rows: 9), isTrue);
    expect(
      shouldImmersiveLandscape(phone, cols: 9, rows: 7),
      isFalse,
      reason: '轻微横向的棋盘在留白后横屏仍不划算',
    );
  });

  test('平板、已横屏与桌面端都不改变方向', () {
    expect(
      shouldImmersiveLandscape(const Size(800, 1280), cols: 21, rows: 9),
      isFalse,
    );
    expect(
      shouldImmersiveLandscape(const Size(800, 360), cols: 21, rows: 9),
      isFalse,
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(shouldImmersiveLandscape(phone, cols: 21, rows: 9), isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(shouldImmersiveLandscape(phone, cols: 21, rows: 9), isFalse);
  });

  test('矮屏使用更小的上下留白', () {
    expect(boardGapFor(900), kBoardGap);
    expect(boardGapFor(390), kBoardGapCompact);
    expect(kBoardGap, greaterThan(kBoardGapCompact));
  });
}
