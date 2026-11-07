import '../models/tile.dart';

/// 一枚棋子的位移动画：从 [from] 滑到 [to]（棋盘下标）。
class TileMove {
  const TileMove({required this.tileId, required this.from, required this.to});

  final int tileId;
  final int from;
  final int to;
}

/// 新棋子从棋盘上方落入 [to]，[fromRow] 可能为负数。
class TileSpawn {
  const TileSpawn({
    required this.tile,
    required this.to,
    required this.fromRow,
  });

  final Tile tile;
  final int to;
  final int fromRow;
}

/// 被消除的棋子：保留类型信息用于收集类目标统计。
class ClearedTile {
  const ClearedTile({
    required this.index,
    required this.type,
    required this.special,
  });

  final int index;
  final TileType type;
  final SpecialType special;
}

/// 新生成的特殊棋子。
class PlacedSpecial {
  const PlacedSpecial({required this.index, required this.tile});

  final int index;
  final Tile tile;
}

/// 冰层变化：[layers] 为剩余层数，0 表示冰层破碎。
class IceChange {
  const IceChange({required this.index, required this.layers});

  final int index;
  final int layers;

  bool get broken => layers == 0;
}

/// 棋盘动画步骤：Flame 组件按顺序播放，控制器在播放后推进计分。
sealed class BoardStep {
  const BoardStep();
}

/// 交换两枚棋子（无效交换会有一次回退的 [SwapStep]）。
class SwapStep extends BoardStep {
  const SwapStep({required this.a, required this.b});

  final int a;
  final int b;
}

/// 消除一组棋子，可同时生成特殊棋子、敲碎冰层。
class ClearStep extends BoardStep {
  const ClearStep({
    required this.tiles,
    required this.specials,
    required this.iceChanges,
    required this.combo,
  });

  final List<ClearedTile> tiles;
  final List<PlacedSpecial> specials;
  final List<IceChange> iceChanges;

  /// 连锁序号，从 1 开始。
  final int combo;

  List<int> get cells => [for (final tile in tiles) tile.index];
}

/// 重力下落与补充新棋子。
class FallStep extends BoardStep {
  const FallStep({required this.moves, required this.spawns});

  final List<TileMove> moves;
  final List<TileSpawn> spawns;

  bool get isEmpty => moves.isEmpty && spawns.isEmpty;
}
