import 'dart:collection';
import 'dart:math';

import '../models/level.dart';
import '../models/tile.dart';
import 'board.dart';
import 'board_step.dart';
import 'match_finder.dart';

export 'board.dart';
export 'match_finder.dart';

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

/// 福珠引爆的目标：待清除的种子格与福珠对应的目标类型。
class RainbowBlast {
  const RainbowBlast({required this.seeds, required this.targets});

  final Set<int> seeds;
  final Map<int, TileType> targets;
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

  late final MatchFinder _finder = MatchFinder(
    board: board,
    cols: cols,
    rows: rows,
  );

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
      if (!_finder.hasMatch && findHint() != null) return;
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

  /// 福珠与另一枚棋子交换后的爆炸范围；两颗福珠相撞时清理整盘。
  RainbowBlast _rainbowBlast(int rainbowIndex, int otherIndex) {
    final seeds = <int>{rainbowIndex, otherIndex};
    final targets = <int, TileType>{};
    final other = board.tiles[otherIndex];
    if (other == null) return RainbowBlast(seeds: seeds, targets: targets);
    if (other.special == SpecialType.rainbow) {
      for (var i = 0; i < board.length; i++) {
        if (board.tiles[i] != null) seeds.add(i);
      }
      return RainbowBlast(seeds: seeds, targets: targets);
    }
    targets[rainbowIndex] = other.type;
    for (var i = 0; i < board.length; i++) {
      if (board.tiles[i]?.type == other.type) seeds.add(i);
    }
    return RainbowBlast(seeds: seeds, targets: targets);
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
      final blast = _rainbowBlast(
        rainbowIndex,
        rainbowIndex == a ? b : a,
      );
      steps.addAll(
        _resolve(seed: blast.seeds, seedTargets: blast.targets),
      );
      return SwapOutcome(valid: true, steps: steps);
    }

    // 两颗特殊棋子互撞：同时引爆。
    if (ta.special.isSpecial && tb.special.isSpecial) {
      steps.addAll(_resolve(seed: {a, b}));
      return SwapOutcome(valid: true, steps: steps);
    }

    if (!_finder.hasMatch) {
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
        final groups = _finder.findGroups();
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
              tile: Tile(id: _nextId++, type: group.type, special: special),
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
        spawns.add(TileSpawn(tile: tile, to: index, fromRow: row - missing));
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
            final matched = _finder.hasMatch;
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
      final blast = _rainbowBlast(
        rainbowAt,
        rainbowAt == hint.a ? hint.b : hint.a,
      );
      cells.addAll(blast.seeds);
      special = true;
    } else {
      final groups = _finder.findGroups();
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
      if (!_finder.hasMatch && findHint() != null) return true;
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
  bool get hasImmediateMatch => _finder.hasMatch;
}
