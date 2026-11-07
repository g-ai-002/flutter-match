import 'dart:math';

import '../models/tile.dart';
import 'board.dart';

/// 一段横排或竖排的同色连线。
class MatchRun {
  const MatchRun({required this.cells, required this.horizontal});

  final List<int> cells;
  final bool horizontal;
}

/// 一组互相交叉的连线：横竖交叉的同色连线合并为同一次消除。
class MatchGroup {
  MatchGroup({required this.type, required this.hRuns, required this.vRuns});

  final TileType type;
  final List<List<int>> hRuns;
  final List<List<int>> vRuns;

  late final Set<int> cells = {
    ...hRuns.expand((run) => run),
    ...vRuns.expand((run) => run),
  };

  List<List<int>> get runs => [...hRuns, ...vRuns];

  SpecialType get special {
    final longest = runs.fold<int>(0, (m, run) => max(m, run.length));
    if (longest >= 5) return SpecialType.rainbow;
    if (hRuns.isNotEmpty && vRuns.isNotEmpty) return SpecialType.bomb;
    if (longest == 4) {
      return hRuns.isNotEmpty ? SpecialType.row : SpecialType.column;
    }
    return SpecialType.none;
  }

  /// 特殊棋子落点：优先玩家落子处，其次拐点，最后最长连线的中点。
  int spawnIndex(int? preferred) {
    if (preferred != null && cells.contains(preferred)) return preferred;
    if (special == SpecialType.bomb) {
      final hCells = hRuns.expand((run) => run).toSet();
      final vCells = vRuns.expand((run) => run).toSet();
      final crossing = hCells.intersection(vCells);
      if (crossing.isNotEmpty) return crossing.first;
    }
    final longest = runs.reduce((a, b) => a.length >= b.length ? a : b);
    return longest[longest.length ~/ 2];
  }
}

/// 连线扫描：从棋盘数据中找出所有三连及以上的同色连线并合并分组。
class MatchFinder {
  MatchFinder({required this.board, required this.cols, required this.rows});

  final GameBoard board;
  final int cols;
  final int rows;

  /// 可参与同色匹配的棋子类型；空位与福珠会打断连线。
  TileType? typeAt(int index) {
    final tile = board.tiles[index];
    if (tile == null || tile.special == SpecialType.rainbow) return null;
    return tile.type;
  }

  /// 逐行逐列扫描，收集所有长度不小于 3 的连线。
  List<MatchRun> findRuns() {
    final runs = <MatchRun>[];
    for (var row = 0; row < rows; row++) {
      var col = 0;
      while (col < cols) {
        final type = typeAt(row * cols + col);
        if (type == null) {
          col++;
          continue;
        }
        var end = col + 1;
        while (end < cols && typeAt(row * cols + end) == type) {
          end++;
        }
        if (end - col >= 3) {
          runs.add(
            MatchRun(
              cells: [for (var c = col; c < end; c++) row * cols + c],
              horizontal: true,
            ),
          );
        }
        col = end;
      }
    }
    for (var col = 0; col < cols; col++) {
      var row = 0;
      while (row < rows) {
        final type = typeAt(row * cols + col);
        if (type == null) {
          row++;
          continue;
        }
        var end = row + 1;
        while (end < rows && typeAt(end * cols + col) == type) {
          end++;
        }
        if (end - row >= 3) {
          runs.add(
            MatchRun(
              cells: [for (var r = row; r < end; r++) r * cols + col],
              horizontal: false,
            ),
          );
        }
        row = end;
      }
    }
    return runs;
  }

  /// 找出所有匹配组，相交的横竖连线合并为同一组。
  List<MatchGroup> findGroups() {
    final runs = findRuns();
    if (runs.isEmpty) return const [];
    final parent = List<int>.generate(runs.length, (index) => index);

    int find(int index) {
      var root = index;
      while (parent[root] != root) {
        parent[root] = parent[parent[root]];
        root = parent[root];
      }
      return root;
    }

    void union(int a, int b) {
      final ra = find(a);
      final rb = find(b);
      if (ra != rb) parent[rb] = ra;
    }

    for (var i = 0; i < runs.length; i++) {
      final set = runs[i].cells.toSet();
      for (var j = i + 1; j < runs.length; j++) {
        if (runs[j].cells.any(set.contains)) union(i, j);
      }
    }

    final grouped = <int, List<MatchRun>>{};
    for (var i = 0; i < runs.length; i++) {
      grouped.putIfAbsent(find(i), () => []).add(runs[i]);
    }

    return [
      for (final groupRuns in grouped.values)
        MatchGroup(
          type: board.tiles[groupRuns.first.cells.first]!.type,
          hRuns: [
            for (final run in groupRuns)
              if (run.horizontal) run.cells,
          ],
          vRuns: [
            for (final run in groupRuns)
              if (!run.horizontal) run.cells,
          ],
        ),
    ];
  }

  bool get hasMatch => findGroups().isNotEmpty;

  /// 单点连线检测：只扫描 [index] 所在的横排与竖排。
  ///
  /// 交换只会影响落子的两格，用它替代整盘重建匹配组，提示扫描与死局
  /// 检查的分配与耗时都随连线长度而不是棋盘规模增长。
  bool hasRunAt(int index) {
    if (index < 0 || index >= board.length) return false;
    final type = typeAt(index);
    if (type == null) return false;
    final col = index % cols;
    final row = index ~/ cols;

    var left = col;
    while (left > 0 && typeAt(row * cols + left - 1) == type) {
      left--;
    }
    var right = col;
    while (right + 1 < cols && typeAt(row * cols + right + 1) == type) {
      right++;
    }
    if (right - left + 1 >= 3) return true;

    var top = row;
    while (top > 0 && typeAt((top - 1) * cols + col) == type) {
      top--;
    }
    var bottom = row;
    while (bottom + 1 < rows && typeAt((bottom + 1) * cols + col) == type) {
      bottom++;
    }
    return bottom - top + 1 >= 3;
  }
}
