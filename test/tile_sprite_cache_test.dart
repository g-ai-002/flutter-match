import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/flame/tile_sprite_cache.dart';
import 'package:fortune_match/models/tile.dart';

void main() {
  test('同尺寸同类型复用贴图，类型或尺寸变化才重建', () {
    final cache = TileSpriteCache();
    addTearDown(cache.dispose);

    final coin = cache.tile(TileType.coin, SpecialType.none, 40);
    expect(
      identical(cache.tile(TileType.coin, SpecialType.none, 40), coin),
      isTrue,
    );

    final jade = cache.tile(TileType.jade, SpecialType.none, 40);
    expect(identical(jade, coin), isFalse);

    final striped = cache.tile(TileType.coin, SpecialType.row, 40);
    expect(identical(striped, coin), isFalse);

    final ice = cache.ice(2, 40);
    expect(identical(cache.ice(2, 40), ice), isTrue);

    // 1/4 像素内视为同一尺寸，超过后重建。
    expect(
      identical(cache.tile(TileType.coin, SpecialType.none, 40.1), coin),
      isTrue,
    );
    expect(
      identical(cache.tile(TileType.coin, SpecialType.none, 40.6), coin),
      isFalse,
    );
  });

  test('释放后重新生成贴图且不抛异常', () {
    final cache = TileSpriteCache();
    final first = cache.tile(TileType.lotus, SpecialType.bomb, 32);
    cache.dispose();
    final second = cache.tile(TileType.lotus, SpecialType.bomb, 32);
    expect(identical(first, second), isFalse);
    expect(second.approximateBytesUsed, greaterThan(0));
    cache.dispose();
  });

  test('空闲预热分批录满全部棋子贴图，取图直接复用', () {
    final cache = TileSpriteCache();
    addTearDown(cache.dispose);

    expect(cache.warmupPending, isTrue);
    var rounds = 0;
    while (!cache.warmupStep(40)) {
      rounds++;
      expect(rounds, lessThan(30), reason: '预热应在有限帧内完成');
    }
    rounds++;
    expect(cache.warmupPending, isFalse);

    // 全部类型 × 特殊棋子都已缓存，开始消除时不再临时录制。
    for (final type in TileType.values) {
      for (final special in SpecialType.values) {
        final picture = cache.tile(type, special, 40);
        expect(picture.approximateBytesUsed, greaterThan(0));
      }
    }

    // 尺寸变化后需要按新尺寸重新预热。
    cache.tile(TileType.coin, SpecialType.none, 56);
    expect(cache.warmupPending, isTrue);
  });

  test('预热在尺寸变化与失效后重新开始', () {
    final cache = TileSpriteCache();
    addTearDown(cache.dispose);

    while (!cache.warmupStep(32, budget: 8)) {}
    expect(cache.warmupPending, isFalse);

    cache.invalidate();
    expect(cache.warmupPending, isTrue);
    expect(cache.warmupStep(32, budget: 1), isFalse);

    while (!cache.warmupStep(48, budget: 8)) {}
    expect(cache.warmupPending, isFalse);
  });
}
