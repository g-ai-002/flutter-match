import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/models/tile.dart';
import 'package:fortune_match/theme/app_theme.dart';

void main() {
  tearDown(() => activateSkin(AppSkin.cinnabar));

  test('每套皮肤覆盖全部棋子且配色互不相同', () {
    expect(kSkinSpecs, hasLength(AppSkin.values.length));
    for (final skin in AppSkin.values) {
      final spec = kSkinSpecs[skin]!;
      expect(spec.tiles.keys.toSet(), TileType.values.toSet());
      expect(spec.sceneLight, hasLength(2));
      expect(spec.sceneDark, hasLength(2));
      for (final palette in spec.tiles.values) {
        expect(palette.base, isNot(palette.light));
        expect(palette.base, isNot(palette.deep));
      }
    }
    final cinnabar = kSkinSpecs[AppSkin.cinnabar]!.tiles[TileType.coin]!.base;
    final celadon = kSkinSpecs[AppSkin.celadon]!.tiles[TileType.coin]!.base;
    expect(cinnabar, isNot(celadon));
  });

  test('切换皮肤会替换棋子与场景配色', () {
    activateSkin(AppSkin.cinnabar);
    final before = kTilePalettes[TileType.coin]!.base;
    final light = sceneGradient(false).colors.first;
    expect(light, kSkinSpecs[AppSkin.cinnabar]!.sceneLight.first);

    activateSkin(AppSkin.celadon);
    expect(kTilePalettes[TileType.coin]!.base, isNot(before));
    expect(
      sceneGradient(false).colors.first,
      kSkinSpecs[AppSkin.celadon]!.sceneLight.first,
    );
    expect(activeSkin, AppSkin.celadon);
  });

  test('皮肤按累计福星解锁，未知名称回退默认', () {
    expect(AppSkin.cinnabar.requiredStars, 0);
    expect(AppSkin.celadon.requiredStars, greaterThan(0));
    expect(
      AppSkin.inkstone.requiredStars,
      greaterThan(AppSkin.celadon.requiredStars),
    );
    expect(AppSkin.byName('celadon'), AppSkin.celadon);
    expect(AppSkin.byName('unknown'), AppSkin.cinnabar);
    expect(AppSkin.byName(null), AppSkin.cinnabar);
  });
}
