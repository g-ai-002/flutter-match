import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/models/tile.dart';
import 'package:fortune_match/theme/app_theme.dart';

void main() {
  tearDown(() => SkinState.active.select(AppSkin.cinnabar));

  test('每套皮肤覆盖全部棋子且配色互不相同', () {
    for (final skin in AppSkin.values) {
      final spec = skin.spec;
      expect(spec.tiles.keys.toSet(), TileType.values.toSet());
      expect(spec.sceneLight, hasLength(2));
      expect(spec.sceneDark, hasLength(2));
      for (final palette in spec.tiles.values) {
        expect(palette.base, isNot(palette.light));
        expect(palette.base, isNot(palette.deep));
      }
    }
    final cinnabar = AppSkin.cinnabar.spec.tiles[TileType.coin]!.base;
    final celadon = AppSkin.celadon.spec.tiles[TileType.coin]!.base;
    expect(cinnabar, isNot(celadon));
  });

  test('切换皮肤会替换棋子与场景配色', () {
    SkinState.active.select(AppSkin.cinnabar);
    final before = kTilePalettes[TileType.coin]!.base;
    final light = sceneGradient(false).colors.first;
    expect(light, AppSkin.cinnabar.spec.sceneLight.first);

    SkinState.active.select(AppSkin.celadon);
    expect(kTilePalettes[TileType.coin]!.base, isNot(before));
    expect(
      sceneGradient(false).colors.first,
      AppSkin.celadon.spec.sceneLight.first,
    );
    expect(SkinState.active.skin, AppSkin.celadon);
  });

  test('皮肤状态实例独立，配色随选择同步', () {
    final state = SkinState(AppSkin.inkstone);
    expect(state.spec, AppSkin.inkstone.spec);
    state.select(AppSkin.celadon);
    expect(state.skin, AppSkin.celadon);
    expect(state.tilePalettes, AppSkin.celadon.spec.tiles);
    expect(state.scene(true), AppSkin.celadon.spec.sceneDark);
    expect(SkinState.active.skin, AppSkin.cinnabar);
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
