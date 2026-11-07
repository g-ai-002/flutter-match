import 'dart:ui' show Color;

import '../models/tile.dart';

/// 单种棋子的配色：高光、主色、暗部与纹样颜色。
class TilePalette {
  const TilePalette({
    required this.light,
    required this.base,
    required this.deep,
    required this.glyph,
  });

  final Color light;
  final Color base;
  final Color deep;
  final Color glyph;
}

/// 主题皮肤：棋子配色与场景底色成套切换，按累计福星解锁。
enum AppSkin {
  cinnabar('朱砂福韵', '中国红与暖金', 0, _cinnabar),
  celadon('青瓷月白', '青绿釉色，清润如水', 30, _celadon),
  inkstone('墨玉灯影', '墨底朱砂，夜色灯影', 60, _inkstone);

  const AppSkin(this.label, this.subtitle, this.requiredStars, this.spec);

  final String label;
  final String subtitle;

  /// 解锁所需累计福星，0 表示默认可用。
  final int requiredStars;

  /// 该皮肤的完整视觉配置。
  final SkinSpec spec;

  static AppSkin byName(String? name) => values.firstWhere(
    (skin) => skin.name == name,
    orElse: () => AppSkin.cinnabar,
  );
}

/// 一套皮肤的完整视觉配置。
class SkinSpec {
  const SkinSpec({
    required this.tiles,
    required this.sceneLight,
    required this.sceneDark,
  });

  final Map<TileType, TilePalette> tiles;
  final List<Color> sceneLight;
  final List<Color> sceneDark;

  List<Color> scene(bool dark) => dark ? sceneDark : sceneLight;
}

const SkinSpec _cinnabar = SkinSpec(
  tiles: {
    TileType.coin: TilePalette(
      light: Color(0xFFF8DF9C),
      base: Color(0xFFE7B24B),
      deep: Color(0xFF9A6413),
      glyph: Color(0xFF6B3A06),
    ),
    TileType.ingot: TilePalette(
      light: Color(0xFFF6B08C),
      base: Color(0xFFDC6B45),
      deep: Color(0xFF8C3418),
      glyph: Color(0xFF5C1E08),
    ),
    TileType.lantern: TilePalette(
      light: Color(0xFFF3A29E),
      base: Color(0xFFD6534B),
      deep: Color(0xFF8A221C),
      glyph: Color(0xFF5A0F0B),
    ),
    TileType.jade: TilePalette(
      light: Color(0xFFA8D6B8),
      base: Color(0xFF5FA377),
      deep: Color(0xFF2C6347),
      glyph: Color(0xFF14402C),
    ),
    TileType.porcelain: TilePalette(
      light: Color(0xFFA9CDEA),
      base: Color(0xFF4F86B5),
      deep: Color(0xFF24537C),
      glyph: Color(0xFF103651),
    ),
    TileType.lotus: TilePalette(
      light: Color(0xFFCBADE3),
      base: Color(0xFF9B6BB5),
      deep: Color(0xFF5F3A80),
      glyph: Color(0xFF3A1F58),
    ),
  },
  sceneLight: [Color(0xFFFDF7EA), Color(0xFFF0DFC0)],
  sceneDark: [Color(0xFF241C15), Color(0xFF120F0A)],
);

const SkinSpec _celadon = SkinSpec(
  tiles: {
    TileType.coin: TilePalette(
      light: Color(0xFFF1F6E4),
      base: Color(0xFFC2D5A8),
      deep: Color(0xFF748C5C),
      glyph: Color(0xFF3D5230),
    ),
    TileType.ingot: TilePalette(
      light: Color(0xFFE4F2EC),
      base: Color(0xFFA8CDBE),
      deep: Color(0xFF5E8F7B),
      glyph: Color(0xFF2E5546),
    ),
    TileType.lantern: TilePalette(
      light: Color(0xFFF6E7D9),
      base: Color(0xFFDCBB9C),
      deep: Color(0xFF9A744F),
      glyph: Color(0xFF5B3B23),
    ),
    TileType.jade: TilePalette(
      light: Color(0xFFD5EDE3),
      base: Color(0xFF8EC2AF),
      deep: Color(0xFF4B816F),
      glyph: Color(0xFF22493B),
    ),
    TileType.porcelain: TilePalette(
      light: Color(0xFFDCEBF5),
      base: Color(0xFF9EC2DC),
      deep: Color(0xFF55829E),
      glyph: Color(0xFF2A4B60),
    ),
    TileType.lotus: TilePalette(
      light: Color(0xFFE6E1EF),
      base: Color(0xFFB3A8CD),
      deep: Color(0xFF766795),
      glyph: Color(0xFF453A65),
    ),
  },
  sceneLight: [Color(0xFFF7FAF2), Color(0xFFDCE8DB)],
  sceneDark: [Color(0xFF1A211C), Color(0xFF0D120E)],
);

const SkinSpec _inkstone = SkinSpec(
  tiles: {
    TileType.coin: TilePalette(
      light: Color(0xFFEBDCC0),
      base: Color(0xFFC9A46B),
      deep: Color(0xFF806038),
      glyph: Color(0xFF4A3416),
    ),
    TileType.ingot: TilePalette(
      light: Color(0xFFE4C9BF),
      base: Color(0xFFB98A7A),
      deep: Color(0xFF7A4A3C),
      glyph: Color(0xFF47241A),
    ),
    TileType.lantern: TilePalette(
      light: Color(0xFFE7C3C0),
      base: Color(0xFFBD7A74),
      deep: Color(0xFF7C3F39),
      glyph: Color(0xFF4B1C18),
    ),
    TileType.jade: TilePalette(
      light: Color(0xFFCFD8CE),
      base: Color(0xFF8DA08C),
      deep: Color(0xFF556355),
      glyph: Color(0xFF2A352B),
    ),
    TileType.porcelain: TilePalette(
      light: Color(0xFFC9D3D6),
      base: Color(0xFF85959A),
      deep: Color(0xFF4D5F64),
      glyph: Color(0xFF25363A),
    ),
    TileType.lotus: TilePalette(
      light: Color(0xFFD6CBD8),
      base: Color(0xFF9E8AA3),
      deep: Color(0xFF635068),
      glyph: Color(0xFF372B3B),
    ),
  },
  sceneLight: [Color(0xFFF5F2EB), Color(0xFFDFD6C7)],
  sceneDark: [Color(0xFF1C1916), Color(0xFF0B0A08)],
);

/// 当前皮肤状态：界面、棋盘与绘制缓存共用这一份配色来源。
class SkinState {
  SkinState([this._skin = AppSkin.cinnabar]);

  /// 应用全局激活的皮肤；由 App 按用户偏好同步。
  static final SkinState active = SkinState();

  AppSkin _skin;

  AppSkin get skin => _skin;
  SkinSpec get spec => _skin.spec;
  Map<TileType, TilePalette> get tilePalettes => spec.tiles;

  void select(AppSkin value) => _skin = value;

  List<Color> scene(bool dark) => spec.scene(dark);
}
