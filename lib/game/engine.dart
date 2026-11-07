import 'dart:collection';
import 'dart:math';

import '../models/level.dart';
import '../models/tile.dart';
import 'board_step.dart';

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

/// 一次交换的结果：动画步骤与是否有效。
class SwapOutcome {
  const SwapOutcome({required this.valid, required this.steps});

  final bool valid;
  final List<BoardStep> steps;
}

/// 提示：一组可消除的相邻交换。
class SwapHint {
  const SwapHint(this.a, this.b);

  final int a;
  final int b;
}

/// 一次交换的浅层评估：只看立即连线，不模拟连锁与特殊棋子。
class HintEvaluation {
  const HintEvaluation({
    required this.hint,
    required this.tileCount,
    required this.iceCount,
    required this.typeCounts,
    required this.createsSpecial,
  });

  final SwapHint hint;
  final int tileCount;
  final int iceCount;
  final Map<TileType, int> typeCounts;
  final bool createsSpecial;
}

class _RawRun {
  _RawRun(this.cells, this.horizontal);

  final List<int> cells;
  final bool horizontal;
}

class _MatchGroup {
  _MatchGroup({
    required this.type,
    required this.hRuns,
    required this.vRuns,
  });

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
    final longest = runs.reduce(
      (a, b) => a.length >= b.length ? a : b,
    );
    return longest[longest.length ~/ 2];
  }
}

/// 三消核心：棋盘生成、消除判定、特殊棋子、下落补充、提示与重排。
///
/// 纯 Dart 实现，不依赖 Flutter，便于单元测试与性能调优。
class MatchEngine {
  MatchEngine({required this.level, Random? random, int? seed})
    : random = random ?? Random(seed),
      cols = level.cols,
      rows = level.rows,
      palette = level.palette,
      board = GameBoard(cols: level.cols, rows: level.rows) {
    resetBoard();
  }

  final Level level;
  final Random random;
  final int cols;
  final int rows;
  final int palette;
  final GameBoard board;

  int _nextId = 1;

  TileType _randomType() => TileType.values[random.nextInt(palette)];

  /// 重开：按关卡重置冰层并重新铺满棋盘。
  void resetBoard() {
    for (var index = 0; index < board.length; index++) {
      board.tiles[index] = null;
      board.ice[index] = level.ice[index] ?? 0;
    }
    _fillInitial();
  }

  void _fillInitial() {
    for (var attempt = 0; attempt < 30; attempt++) {
      for (var index = 0; index < board.length; index++) {
        if (board.tiles[index] != null) continue;
        var type = _randomType();
        var guard = 0;
        while (_wouldMatch(index, type) && guard++ < 30) {
          type = _randomType();
        }
        board.tiles[index] = Tile(id: _nextId++, type: type);
      }
      if (_findGroups().isEmpty && findHint() != null) return;
      for (var index = 0; index < board.length; index++) {
        board.tiles[index] = null;
      }
    }
    for (var index = 0; index < board.length; index++) {
      board.tiles[index] ??= Tile(id: _nextId++, type: _randomType());
    }
  }

  bool _wouldMatch(int index, TileType type) {
    final col = index % cols;
    final row = index ~/ cols;
    if (col >= 2) {
      final left1 = board.tiles[index - 1];
      final left2 = board.tiles[index - 2];
      if (left1?.type == type && left2?.type == type) return true;
    }
    if (row >= 2) {
      final up1 = board.tiles[index - cols];
      final up2 = board.tiles[index - 2 * cols];
      if (up1?.type == type && up2?.type == type) return true;
    }
    return false;
  }

  /// 可参与同色匹配的棋子类型；空位与福珠会打断连线。
  TileType? _matchType(int index) {
    final tile = board.tiles[index];
    if (tile == null || tile.special == SpecialType.rainbow) return null;
    return tile.type;
  }

  List<_RawRun> _findRuns() {
    final runs = <_RawRun>[];
    for (var row = 0; row < rows; row++) {
      var col = 0;
      while (col < cols) {
        final type = _matchType(row * cols + col);
        if (type == null) {
          col++;
          continue;
        }
        var end = col + 1;
        while (end < cols && _matchType(row * cols + end) == type) {
          end++;
        }
        if (end - col >= 3) {
          runs.add(
            _RawRun([for (var c = col; c < end; c++) row * cols + c], true),
          );
        }
        col = end;
      }
    }
    for (var col = 0; col < cols; col++) {
      var row = 0;
      while (row < rows) {
        final type = _matchType(row * cols + col);
        if (type == null) {
          row++;
          continue;
        }
        var end = row + 1;
        while (end < rows && _matchType(end * cols + col) == type) {
          end++;
        }
        if (end - row >= 3) {
          runs.add(
            _RawRun([for (var r = row; r < end; r++) r * cols + col], false),
          );
        }
        row = end;
      }
    }
    return runs;
  }

  /// 找出所有匹配组（相交的横竖连线合并为同一组）。
  List<_MatchGroup> _findGroups() {
    final runs = _findRuns();
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

    final grouped = <int, List<_RawRun>>{};
    for (var i = 0; i < runs.length; i++) {
      grouped.putIfAbsent(find(i), () => []).add(runs[i]);
    }

    final groups = <_MatchGroup>[];
    for (final groupRuns in grouped.values) {
      final anchor = groupRuns.first.cells.first;
      final type = board.tiles[anchor]!.type;
      groups.add(
        _MatchGroup(
          type: type,
          hRuns: [
            for (final run in groupRuns)
              if (run.horizontal) run.cells,
          ],
          vRuns: [
            for (final run in groupRuns)
              if (!run.horizontal) run.cells,
          ],
        ),
      );
    }
    return groups;
  }

  /// 展开特殊棋子的爆炸范围，[reserved] 里的落点不会触发。
  Set<int> _expandClears(
    Iterable<int> seeds, {
    Set<int> reserved = const {},
    Map<int, TileType> rainbowTargets = const {},
  }) {
    final cleared = <int>{};
    final queue = ListQueue<int>()..addAll(seeds);
    while (queue.isNotEmpty) {
      final index = queue.removeFirst();
      if (reserved.contains(index)) continue;
      if (!cleared.add(index)) continue;
      final tile = board.tiles[index];
      if (tile == null) continue;
      switch (tile.special) {
        case SpecialType.none:
          break;
        case SpecialType.row:
          final base = index - index % cols;
          for (var col = 0; col < cols; col++) {
            queue.add(base + col);
          }
        case SpecialType.column:
          final col = index % cols;
          for (var row = 0; row < rows; row++) {
            queue.add(row * cols + col);
          }
        case SpecialType.bomb:
          final col = index % cols;
          final row = index ~/ cols;
          for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
              final c = col + dc;
              final r = row + dr;
              if (c >= 0 && c < cols && r >= 0 && r < rows) {
                queue.add(r * cols + c);
              }
            }
          }
        case SpecialType.rainbow:
          final target = rainbowTargets[index] ?? _mostCommonType();
          if (target == null) break;
          for (var i = 0; i < board.length; i++) {
            final other = board.tiles[i];
            if (other != null &&
                other.type == target &&
                other.special != SpecialType.rainbow) {
              queue.add(i);
            }
          }
      }
    }
    return cleared;
  }

  TileType? _mostCommonType() {
    final counts = <TileType, int>{};
    for (final tile in board.tiles) {
      if (tile == null || tile.special == SpecialType.rainbow) continue;
      counts[tile.type] = (counts[tile.type] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// 交换两枚相邻棋子；无效交换会带回退动画并标记 [SwapOutcome.valid] 为 false。
  SwapOutcome trySwap(int a, int b) {
    if (!board.isAdjacent(a, b)) {
      return const SwapOutcome(valid: false, steps: []);
    }
    final ta = board.tiles[a];
    final tb = board.tiles[b];
    if (ta == null || tb == null) {
      return const SwapOutcome(valid: false, steps: []);
    }

    board.swap(a, b);
    final steps = <BoardStep>[SwapStep(a: a, b: b)];

    // 福珠与任意棋子交换：消除该棋子的全部同类。
    if (ta.special == SpecialType.rainbow || tb.special == SpecialType.rainbow) {
      final rainbowIndex = ta.special == SpecialType.rainbow ? b : a;
      final otherIndex = rainbowIndex == a ? b : a;
      final other = board.tiles[otherIndex];
      final seeds = <int>{rainbowIndex, otherIndex};
      final targets = <int, TileType>{};
      if (other != null && other.special == SpecialType.rainbow) {
        for (var i = 0; i < board.length; i++) {
          if (board.tiles[i] != null) seeds.add(i);
        }
      } else if (other != null) {
        targets[rainbowIndex] = other.type;
        for (var i = 0; i < board.length; i++) {
          final tile = board.tiles[i];
          if (tile != null && tile.type == other.type) seeds.add(i);
        }
      }
      steps.addAll(_resolve(seed: seeds, seedTargets: targets));
      return SwapOutcome(valid: true, steps: steps);
    }

    // 两颗特殊棋子互撞：同时引爆。
    if (ta.special.isSpecial && tb.special.isSpecial) {
      steps.addAll(_resolve(seed: {a, b}));
      return SwapOutcome(valid: true, steps: steps);
    }

    final groups = _findGroups();
    if (groups.isEmpty) {
      board.swap(a, b);
      steps.add(SwapStep(a: a, b: b));
      return SwapOutcome(valid: false, steps: steps);
    }
    steps.addAll(_resolve(preferred: b));
    return SwapOutcome(valid: true, steps: steps);
  }

  /// 依次处理首轮消除、连锁、下落与补充，直到棋盘稳定。
  List<BoardStep> _resolve({
    int? preferred,
    Set<int>? seed,
    Map<int, TileType> seedTargets = const {},
  }) {
    final steps = <BoardStep>[];
    var combo = 0;
    var first = true;
    Set<int>? pendingSeed = seed;

    while (true) {
      final reserved = <int>{};
      final created = <PlacedSpecial>[];
      late Set<int> seeds;
      var targets = const <int, TileType>{};

      if (pendingSeed != null && first) {
        seeds = pendingSeed;
        targets = seedTargets;
        pendingSeed = null;
      } else {
        final groups = _findGroups();
        if (groups.isEmpty) break;
        seeds = <int>{};
        for (final group in groups) {
          seeds.addAll(group.cells);
          final special = group.special;
          if (special == SpecialType.none) continue;
          final spawn = group.spawnIndex(first ? preferred : null);
          reserved.add(spawn);
          created.add(
            PlacedSpecial(
              index: spawn,
              tile: Tile(
                id: _nextId++,
                type: group.type,
                special: special,
              ),
            ),
          );
        }
      }
      first = false;
      combo++;

      final affected = _expandClears(
        seeds,
        reserved: reserved,
        rainbowTargets: targets,
      );
      final cleared = <ClearedTile>[];
      final iceChanges = <IceChange>[];
      for (final index in affected) {
        final tile = board.tiles[index];
        if (tile == null) continue;
        cleared.add(
          ClearedTile(index: index, type: tile.type, special: tile.special),
        );
        if (board.ice[index] > 0) {
          board.ice[index]--;
          iceChanges.add(IceChange(index: index, layers: board.ice[index]));
        }
        board.tiles[index] = null;
      }
      if (cleared.isEmpty && created.isEmpty) break;
      cleared.sort((a, b) => a.index.compareTo(b.index));
      iceChanges.sort((a, b) => a.index.compareTo(b.index));
      for (final placed in created) {
        board.tiles[placed.index] = placed.tile;
      }

      steps.add(
        ClearStep(
          tiles: cleared,
          specials: created,
          iceChanges: iceChanges,
          combo: combo,
        ),
      );
      final fall = _applyGravity();
      if (!fall.isEmpty) steps.add(fall);
    }
    return steps;
  }

  /// 按列下落并把新棋子补到顶部，返回完整的下落动画数据。
  FallStep _applyGravity() {
    final moves = <TileMove>[];
    final spawns = <TileSpawn>[];
    for (var col = 0; col < cols; col++) {
      var writeRow = rows - 1;
      for (var row = rows - 1; row >= 0; row--) {
        final index = row * cols + col;
        final tile = board.tiles[index];
        if (tile == null) continue;
        if (writeRow != row) {
          final target = writeRow * cols + col;
          board.tiles[target] = tile;
          board.tiles[index] = null;
          moves.add(TileMove(tileId: tile.id, from: index, to: target));
        }
        writeRow--;
      }
      final missing = writeRow + 1;
      for (var row = writeRow; row >= 0; row--) {
        final index = row * cols + col;
        final tile = Tile(id: _nextId++, type: _randomType());
        board.tiles[index] = tile;
        spawns.add(
          TileSpawn(tile: tile, to: index, fromRow: row - missing),
        );
      }
    }
    return FallStep(moves: moves, spawns: spawns);
  }

  /// 是否存在可消除的相邻交换；福珠的任意交换都算有效。
  SwapHint? findHint() {
    final hints = findHints();
    return hints.isEmpty ? null : hints.first;
  }

  /// 收集所有可消除的相邻交换，供提示按目标优先级挑选。
  List<SwapHint> findHints({int limit = 64}) {
    final hints = <SwapHint>[];
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final a = row * cols + col;
        final ta = board.tiles[a];
        if (ta == null) continue;
        final neighbors = <int>[
          if (col + 1 < cols) a + 1,
          if (row + 1 < rows) a + cols,
        ];
        for (final b in neighbors) {
          final tb = board.tiles[b];
          if (tb == null) continue;
          if (ta.special == SpecialType.rainbow ||
              tb.special == SpecialType.rainbow) {
            hints.add(SwapHint(a, b));
          } else {
            board.swap(a, b);
            final matched = _findGroups().isNotEmpty;
            board.swap(a, b);
            if (matched) hints.add(SwapHint(a, b));
          }
          if (hints.length >= limit) return hints;
        }
      }
    }
    return hints;
  }

  /// 浅层评估一组交换：消除数量、冰面覆盖与棋子类型分布。
  HintEvaluation evaluateHint(SwapHint hint) {
    final ta = board.tiles[hint.a];
    final tb = board.tiles[hint.b];
    final rainbowInvolved =
        ta != null &&
        tb != null &&
        (ta.special == SpecialType.rainbow ||
            tb.special == SpecialType.rainbow);
    board.swap(hint.a, hint.b);
    final cells = <int>{};
    var special = false;
    if (rainbowInvolved) {
      final rainbowAt = ta.special == SpecialType.rainbow ? hint.b : hint.a;
      final other = board.tiles[rainbowAt];
      cells.add(rainbowAt);
      if (other != null && other.special == SpecialType.rainbow) {
        for (var i = 0; i < board.length; i++) {
          if (board.tiles[i] != null) cells.add(i);
        }
      } else if (other != null) {
        for (var i = 0; i < board.length; i++) {
          final tile = board.tiles[i];
          if (tile != null && tile.type == other.type) cells.add(i);
        }
      }
      special = true;
    } else {
      final groups = _findGroups();
      for (final group in groups) {
        cells.addAll(group.cells);
        if (group.special != SpecialType.none) special = true;
      }
    }
    final counts = <TileType, int>{};
    var iceCount = 0;
    for (final index in cells) {
      final tile = board.tiles[index];
      if (tile == null) continue;
      counts[tile.type] = (counts[tile.type] ?? 0) + 1;
      if (board.ice[index] > 0) iceCount++;
    }
    board.swap(hint.a, hint.b);
    return HintEvaluation(
      hint: hint,
      tileCount: cells.length,
      iceCount: iceCount,
      typeCounts: counts,
      createsSpecial: special,
    );
  }

  /// 洗牌：保留现有棋子与特殊棋子，直到既无直接匹配又有可走一步。
  bool shuffle() {
    _fillHoles();
    final tiles = board.tiles.whereType<Tile>().toList();
    for (var attempt = 0; attempt < 120; attempt++) {
      tiles.shuffle(random);
      for (var index = 0; index < board.length; index++) {
        board.tiles[index] = tiles[index];
      }
      if (_findGroups().isEmpty && findHint() != null) return true;
    }
    for (var index = 0; index < board.length; index++) {
      board.tiles[index] = null;
    }
    _fillInitial();
    return true;
  }

  void _fillHoles() {
    for (var index = 0; index < board.length; index++) {
      board.tiles[index] ??= Tile(id: _nextId++, type: _randomType());
    }
  }

  /// 是否存在立即可以消除的连线（用于测试与初始化自检）。
  bool get hasImmediateMatch => _findGroups().isNotEmpty;
}
