import '../models/tile.dart';

/// 棋盘数据：棋子与冰层，下标为 `row * cols + col`。
class GameBoard {
  GameBoard({required this.cols, required this.rows})
    : tiles = List<Tile?>.filled(cols * rows, null),
      ice = List<int>.filled(cols * rows, 0);

  final int cols;
  final int rows;
  final List<Tile?> tiles;
  final List<int> ice;

  int get length => tiles.length;

  int indexOf(int col, int row) => row * cols + col;

  bool contains(int index) => index >= 0 && index < tiles.length;

  Tile? tileAt(int index) => contains(index) ? tiles[index] : null;

  void swap(int a, int b) {
    final tile = tiles[a];
    tiles[a] = tiles[b];
    tiles[b] = tile;
  }

  bool isAdjacent(int a, int b) {
    if (!contains(a) || !contains(b) || a == b) return false;
    final ca = a % cols, ra = a ~/ cols;
    final cb = b % cols, rb = b ~/ cols;
    return (ca - cb).abs() + (ra - rb).abs() == 1;
  }
}
