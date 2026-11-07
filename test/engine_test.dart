import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/board_step.dart';
import 'package:fortune_match/game/engine.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/models/tile.dart';

const _letters = {
  'A': TileType.coin,
  'B': TileType.ingot,
  'C': TileType.lantern,
  'D': TileType.jade,
  'E': TileType.porcelain,
};

Level _level(int cols, int rows, {int moves = 20}) => Level(
  id: 1,
  name: '测试',
  cols: cols,
  rows: rows,
  moves: moves,
  palette: 5,
  goals: const [LevelGoal.score(10)],
);

/// 用字母网格覆盖棋盘，便于构造确定的三连形状。
MatchEngine _engineFrom(List<String> source) {
  final rows = [for (final row in source) row.replaceAll(' ', '')];
  final engine = MatchEngine(
    level: _level(rows.first.length, rows.length),
    seed: 1,
  );
  var id = 1000;
  for (var row = 0; row < rows.length; row++) {
    for (var col = 0; col < rows[row].length; col++) {
      final letter = rows[row][col];
      engine.board.tiles[row * rows.first.length + col] = Tile(
        id: id++,
        type: _letters[letter]!,
      );
    }
  }
  return engine;
}

ClearStep _firstClear(SwapOutcome outcome) =>
    outcome.steps.whereType<ClearStep>().first;

void main() {
  test('初始棋盘没有现成三连且至少存在一步可消除', () {
    final engine = MatchEngine(level: _level(8, 8), seed: 42);
    expect(engine.hasImmediateMatch, isFalse);
    expect(engine.findHint(), isNotNull);
    expect(engine.board.tiles.whereType<Tile>().length, 64);
  });

  test('四连生成横扫，优先落在玩家落子处', () {
    final engine = _engineFrom([
      'A B A A C',
      'B A C C B',
      'C D C D C',
      'D E D E D',
      'E C E C E',
    ]);
    final outcome = engine.trySwap(1, 6);
    expect(outcome.valid, isTrue);
    expect(outcome.steps.first, isA<SwapStep>());
    final clear = _firstClear(outcome);
    expect(clear.tiles.length, 3);
    expect(clear.specials, hasLength(1));
    expect(clear.specials.single.tile.special, SpecialType.row);
    expect(clear.specials.single.index, 2);
    expect(engine.hasImmediateMatch, isFalse);
    expect(engine.board.tiles.whereType<Tile>().length, 25);
  });

  test('五连生成福珠', () {
    final engine = _engineFrom([
      'A A B A A',
      'B C A C B',
      'C D C D C',
      'D E D E D',
      'E C E C E',
    ]);
    final outcome = engine.trySwap(2, 7);
    expect(outcome.valid, isTrue);
    final clear = _firstClear(outcome);
    expect(clear.specials.single.tile.special, SpecialType.rainbow);
    expect(clear.tiles.length, 4);
  });

  test('拐角 L 形生成爆珠', () {
    final engine = _engineFrom([
      'A A B A C',
      'C D A E D',
      'D E A C E',
      'E C D E C',
      'C E C D E',
    ]);
    final outcome = engine.trySwap(2, 3);
    expect(outcome.valid, isTrue);
    final clear = _firstClear(outcome);
    expect(clear.specials.single.tile.special, SpecialType.bomb);
    expect(clear.specials.single.index, 2);
    expect(clear.tiles.length, 4);
  });

  test('无效交换回退棋盘并产生回退动画', () {
    final engine = _engineFrom([
      'A B A B',
      'C D C D',
      'A B A B',
      'C D C D',
    ]);
    final before = [
      for (final tile in engine.board.tiles) tile?.id,
    ];
    final outcome = engine.trySwap(0, 1);
    expect(outcome.valid, isFalse);
    expect(outcome.steps.whereType<SwapStep>(), hasLength(2));
    expect([
      for (final tile in engine.board.tiles) tile?.id,
    ], before);
  });

  test('特殊棋子参与消除时触发整行效果', () {
    final engine = _engineFrom([
      'A B A C D',
      'C A D E C',
      'D E C D E',
      'E C D E C',
      'C D E C D',
    ]);
    engine.board.tiles[0] = engine.board.tiles[0]!.withSpecial(
      SpecialType.row,
    );
    // 交换 (1,0) 与 (1,1)，让 A 形成三连并引爆 (0,0) 的横扫。
    final outcome = engine.trySwap(1, 6);
    expect(outcome.valid, isTrue);
    final clear = _firstClear(outcome);
    final cells = clear.cells.toSet();
    for (var col = 0; col < 5; col++) {
      expect(cells.contains(col), isTrue, reason: '第 0 行第 $col 列应被横扫');
    }
  });

  test('连续随机落子始终维持满盘且无现成三连', () {
    final engine = MatchEngine(level: _level(8, 8), seed: 7);
    for (var move = 0; move < 40; move++) {
      final hint = engine.findHint();
      expect(hint, isNotNull, reason: '第 $move 步应始终有可消除组合');
      final outcome = engine.trySwap(hint!.a, hint.b);
      expect(outcome.valid, isTrue);
      expect(engine.hasImmediateMatch, isFalse);
      expect(engine.board.tiles.whereType<Tile>().length, 64);
      expect(engine.board.tiles.whereType<Tile?>().any((t) => t == null), isFalse);
    }
  });

  test('洗牌后棋盘仍然可玩', () {
    final engine = MatchEngine(level: _level(8, 8), seed: 3);
    expect(engine.shuffle(), isTrue);
    expect(engine.hasImmediateMatch, isFalse);
    expect(engine.findHint(), isNotNull);
    expect(engine.board.tiles.whereType<Tile>().length, 64);
  });

  test('福珠交换清除全部同类棋子', () {
    final engine = _engineFrom([
      'A B A C D',
      'C D C B E',
      'D E D A C',
      'B C B D A',
      'E A E C B',
    ]);
    final targets = <int>{
      for (var i = 0; i < engine.board.length; i++)
        if (engine.board.tiles[i]?.type == TileType.ingot) i,
    };
    expect(targets, hasLength(5));
    engine.board.tiles[0] = engine.board.tiles[0]!.withSpecial(
      SpecialType.rainbow,
    );

    final outcome = engine.trySwap(0, 1);
    expect(outcome.valid, isTrue);
    final clear = _firstClear(outcome);
    // 5 枚元宝 + 福珠本身，交换后的福珠落在下标 1。
    expect(clear.tiles, hasLength(6));
    expect(clear.cells.toSet(), containsAll(targets));
    expect(clear.cells, contains(1));
  });

  test('提示评估不改动棋盘，也不超出可消除数量', () {
    final engine = MatchEngine(level: _level(8, 8), seed: 17);
    final before = [for (final tile in engine.board.tiles) tile?.id];
    final hint = engine.findHint()!;
    final evaluation = engine.evaluateHint(hint);
    expect(evaluation.tileCount, greaterThanOrEqualTo(3));
    expect(evaluation.hint.a, hint.a);
    expect(evaluation.hint.b, hint.b);
    expect([for (final tile in engine.board.tiles) tile?.id], before);
  });

  test('福珠提示评估只统计同色棋子而非整盘', () {
    final engine = _engineFrom([
      'A B A C D',
      'C D C B E',
      'D E D A C',
      'B C B D A',
      'E A E C B',
    ]);
    engine.board.tiles[0] = engine.board.tiles[0]!.withSpecial(
      SpecialType.rainbow,
    );
    final evaluation = engine.evaluateHint(const SwapHint(0, 1));
    // 5 枚元宝 + 福珠与相邻棋子，远少于整盘 25 格。
    expect(evaluation.tileCount, 6);
    expect(evaluation.tileCount, lessThan(engine.board.length));
    expect(evaluation.createsSpecial, isTrue);
    expect(evaluation.typeCounts[TileType.ingot], 5);
  });

  test('找提示可限制返回数量', () {
    final engine = MatchEngine(level: _level(8, 8), seed: 23);
    expect(engine.findHints(limit: 1), hasLength(1));
    expect(engine.findHints(limit: 2).length, lessThanOrEqualTo(2));
    expect(engine.findHints(), isNotEmpty);
  });
}
