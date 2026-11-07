/// 六种国风棋子，颜色在界面层按主题渲染。
enum TileType {
  coin('铜钱', '钱'),
  ingot('元宝', '宝'),
  lantern('灯笼', '灯'),
  jade('玉佩', '玉'),
  porcelain('青花', '瓷'),
  lotus('莲花', '莲');

  const TileType(this.label, this.glyph);

  final String label;

  /// 棋子上的单字纹样。
  final String glyph;
}

/// 特殊棋子：直线、炸弹与福珠。
enum SpecialType {
  none('普通', '普通棋子'),
  row('横扫', '横扫整行'),
  column('竖贯', '竖贯整列'),
  bomb('爆珠', '炸开九宫'),
  rainbow('福珠', '消除同类');

  const SpecialType(this.label, this.description);

  final String label;
  final String description;

  bool get isSpecial => this != SpecialType.none;
}

/// 棋盘上的一枚棋子，[id] 在单局内唯一，用于驱动动画。
class Tile {
  const Tile({required this.id, required this.type, this.special = SpecialType.none});

  final int id;
  final TileType type;
  final SpecialType special;

  Tile withSpecial(SpecialType value) =>
      Tile(id: id, type: type, special: value);
}
