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
}
