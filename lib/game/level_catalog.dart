import '../models/level.dart';
import '../models/tile.dart';

/// 关卡数据表：20 个手工关卡，棋盘规格、步数、目标与冰层由浅入深。
///
/// 只放数据与排版辅助函数，查询与跳转逻辑放在 `levels.dart`。
List<Level> buildLevelCatalog() => [
  const Level(
    id: 1,
    name: '初尝福味',
    cols: 7,
    rows: 7,
    moves: 20,
    palette: 5,
    goals: [LevelGoal.score(1200)],
  ),
  const Level(
    id: 2,
    name: '灯笼高挂',
    cols: 7,
    rows: 7,
    moves: 20,
    palette: 5,
    goals: [LevelGoal.collect(TileType.lantern, 12)],
  ),
  const Level(
    id: 3,
    name: '双喜临门',
    cols: 8,
    rows: 8,
    moves: 22,
    palette: 5,
    goals: [
      LevelGoal.collect(TileType.coin, 10),
      LevelGoal.collect(TileType.jade, 10),
    ],
  ),
  const Level(
    id: 4,
    name: '金玉满堂',
    cols: 8,
    rows: 8,
    moves: 21,
    goals: [LevelGoal.score(2600)],
  ),
  Level(
    id: 5,
    name: '薄冰初结',
    cols: 8,
    rows: 8,
    moves: 22,
    goals: const [LevelGoal.ice(7)],
    ice: _band(8, 3, 4, colStep: 2),
  ),
  const Level(
    id: 6,
    name: '元宝盈门',
    cols: 8,
    rows: 8,
    moves: 20,
    goals: [LevelGoal.collect(TileType.ingot, 14), LevelGoal.score(2000)],
  ),
  Level(
    id: 7,
    name: '冰封回廊',
    cols: 8,
    rows: 8,
    moves: 20,
    goals: const [LevelGoal.ice(12)],
    ice: {
      ..._band(8, 2, 2),
      ..._band(8, 5, 5),
      ..._spots(8, 2, const [(2, 2), (5, 5), (2, 5), (5, 2)]),
    },
  ),
  const Level(
    id: 8,
    name: '莲开并蒂',
    cols: 8,
    rows: 8,
    moves: 18,
    goals: [
      LevelGoal.collect(TileType.lotus, 12),
      LevelGoal.collect(TileType.porcelain, 12),
    ],
  ),
  const Level(
    id: 9,
    name: '九宫纳福',
    cols: 9,
    rows: 8,
    moves: 22,
    goals: [LevelGoal.score(4000)],
  ),
  Level(
    id: 10,
    name: '踏雪寻梅',
    cols: 9,
    rows: 8,
    moves: 20,
    goals: const [LevelGoal.ice(14), LevelGoal.collect(TileType.coin, 12)],
    ice: {
      ..._band(9, 1, 3, colStep: 2),
      ..._band(9, 5, 6, colStep: 2, offset: 1),
    },
  ),
  const Level(
    id: 11,
    name: '灯影摇红',
    cols: 9,
    rows: 8,
    moves: 22,
    goals: [
      LevelGoal.collect(TileType.lantern, 16),
      LevelGoal.collect(TileType.jade, 16),
    ],
  ),
  Level(
    id: 12,
    name: '冰玉交辉',
    cols: 9,
    rows: 8,
    moves: 24,
    goals: const [LevelGoal.score(5200), LevelGoal.ice(5)],
    ice: _spots(9, 2, const [(1, 1), (4, 1), (7, 1), (2, 4), (6, 4)]),
  ),
  const Level(
    id: 13,
    name: '聚宝成塔',
    cols: 8,
    rows: 8,
    moves: 18,
    goals: [LevelGoal.collect(TileType.ingot, 13)],
  ),
  Level(
    id: 14,
    name: '春冰初解',
    cols: 9,
    rows: 9,
    moves: 22,
    goals: const [LevelGoal.ice(16)],
    ice: {
      ..._band(9, 2, 2, offset: 1),
      ..._band(9, 4, 4),
      ..._band(9, 6, 6, offset: 2),
      ..._band(9, 8, 8, offset: 1),
    },
  ),
  const Level(
    id: 15,
    name: '瓷莲合璧',
    cols: 9,
    rows: 9,
    moves: 22,
    goals: [
      LevelGoal.collect(TileType.porcelain, 18),
      LevelGoal.collect(TileType.lotus, 18),
    ],
  ),
  const Level(
    id: 16,
    name: '福满乾坤',
    cols: 9,
    rows: 9,
    moves: 20,
    goals: [LevelGoal.score(6000)],
  ),
  Level(
    id: 17,
    name: '铜钱串福',
    cols: 9,
    rows: 9,
    moves: 20,
    goals: const [LevelGoal.collect(TileType.coin, 18), LevelGoal.ice(5)],
    ice: _spots(9, 2, const [
      (0, 2),
      (3, 2),
      (6, 2),
      (8, 2),
      (1, 5),
      (4, 5),
      (7, 5),
    ]),
  ),
  const Level(
    id: 18,
    name: '灯火阑珊',
    cols: 9,
    rows: 9,
    moves: 20,
    goals: [
      LevelGoal.collect(TileType.jade, 20),
      LevelGoal.collect(TileType.lantern, 20),
    ],
  ),
  Level(
    id: 19,
    name: '寒冰深锁',
    cols: 9,
    rows: 9,
    moves: 20,
    goals: const [LevelGoal.ice(16), LevelGoal.score(4500)],
    ice: {
      ..._band(9, 1, 1),
      ..._band(9, 7, 7),
      ..._spots(9, 2, const [
        (1, 3),
        (4, 3),
        (7, 3),
        (1, 6),
        (4, 6),
        (7, 6),
      ]),
    },
  ),
  const Level(
    id: 20,
    name: '福运大典',
    cols: 9,
    rows: 9,
    moves: 22,
    goals: [
      LevelGoal.collect(TileType.coin, 16),
      LevelGoal.collect(TileType.porcelain, 16),
      LevelGoal.collect(TileType.lotus, 16),
      LevelGoal.score(5000),
    ],
  ),
];

/// 横向冰带：行 [fromRow] 到 [toRow]，列按 [colStep] 与 [offset] 取点。
Map<int, int> _band(
  int cols,
  int fromRow,
  int toRow, {
  int layers = 1,
  int colStep = 1,
  int offset = 0,
  int rowStep = 1,
}) {
  final cells = <int, int>{};
  for (var row = fromRow; row <= toRow; row += rowStep) {
    for (var col = offset; col < cols; col += colStep) {
      cells[row * cols + col] = layers;
    }
  }
  return cells;
}

/// 按 (列, 行) 坐标点出冰层。
Map<int, int> _spots(int cols, int layers, List<(int, int)> cells) => {
  for (final (col, row) in cells) row * cols + col: layers,
};
