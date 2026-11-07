import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/models/tile.dart';
import 'package:fortune_match/services/sound_service.dart';

Level _level({Map<int, int> ice = const {}}) => Level(
  id: 1,
  name: '道具测试',
  cols: 8,
  rows: 8,
  moves: 20,
  goals: const [LevelGoal.score(999999)],
  ice: ice,
);

MatchController _controller({
  Map<PropKind, int>? stock,
  Map<int, int> ice = const {},
  int seed = 7,
}) => MatchController(
  level: _level(ice: ice),
  props: PropStock(stock),
  seed: seed,
);

void main() {
  setUp(() {
    SoundService.sink = (_) {};
    SoundService.configure(sound: false, haptics: false);
  });

  tearDown(SoundService.reset);

  test('道具库存增减，数量不足时不扣减', () {
    final stock = PropStock({PropKind.hammer: 2});
    expect(stock.count(PropKind.hammer), 2);
    expect(stock.count(PropKind.swap), 0);
    expect(stock.has(PropKind.swap), isFalse);

    expect(stock.take(PropKind.hammer), isTrue);
    expect(stock.count(PropKind.hammer), 1);
    expect(stock.take(PropKind.swap), isFalse);
    expect(stock.count(PropKind.swap), 0);

    stock.add(PropKind.swap, 3);
    expect(stock.count(PropKind.swap), 3);
    expect(stock.snapshot[PropKind.swap], 3);
  });

  test('库存为空时无法启用道具', () {
    final controller = _controller(stock: {PropKind.hammer: 1});
    expect(controller.activateProp(PropKind.swap), isFalse);
    expect(controller.activeProp, isNull);
    expect(controller.propCount(PropKind.swap), 0);
  });

  test('小锤敲掉指定棋子，不消耗步数并破冰', () {
    final controller = _controller(
      stock: {PropKind.hammer: 1},
      ice: {12: 1},
    );
    final used = <PropKind>[];
    controller.onPropUsed = used.add;
    final moves = controller.movesLeft;
    final before = controller.board.tiles[12]!;

    expect(controller.activateProp(PropKind.hammer), isTrue);
    expect(controller.activeProp, PropKind.hammer);
    controller.tapCell(12);

    expect(controller.status, GameStatus.animating);
    controller.settleImmediately();

    expect(controller.movesLeft, moves);
    expect(controller.propCount(PropKind.hammer), 0);
    expect(controller.activeProp, isNull);
    expect(used, [PropKind.hammer]);
    expect(controller.iceBroken, 1);
    expect(controller.board.ice[12], 0);
    expect(controller.board.tiles[12]!.id, isNot(before.id));
    expect(controller.score, greaterThan(0));
  });

  test('换位只在形成消除时生效并消耗道具', () {
    final controller = _controller(stock: {PropKind.swap: 1});
    controller.requestHint();
    final hint = controller.hint!;
    final moves = controller.movesLeft;

    expect(controller.activateProp(PropKind.swap), isTrue);
    expect(controller.activeProp, PropKind.swap);
    controller.tapCell(hint.a);
    expect(controller.selected, hint.a);
    controller.tapCell(hint.b);

    expect(controller.status, GameStatus.animating);
    expect(controller.propCount(PropKind.swap), 0);
    expect(controller.activeProp, isNull);
    controller.settleImmediately();
    expect(controller.movesLeft, moves);
    expect(controller.score, greaterThan(0));
  });

  test('换位遇到同色交换会退回，道具与棋盘都不变', () {
    final controller = _controller(stock: {PropKind.swap: 2}, seed: 13);
    final board = controller.board;
    final first = board.tiles.indexWhere(
      (tile) => tile != null && tile.special == SpecialType.none,
    );
    final type = board.tiles[first]!.type;
    var second = -1;
    for (var index = first + 1; index < board.length; index++) {
      final tile = board.tiles[index];
      if (tile == null || tile.type != type) continue;
      if (tile.special != SpecialType.none) continue;
      if (board.isAdjacent(first, index)) continue;
      second = index;
      break;
    }
    expect(second, greaterThanOrEqualTo(0));

    final before = board.tiles[first]!.id;
    controller.activateProp(PropKind.swap);
    controller.tapCell(first);
    controller.tapCell(second);

    // 同色互换后棋盘状态完全一致，引擎判定无效并原样退回。
    expect(controller.status, GameStatus.ready);
    expect(controller.propCount(PropKind.swap), 2);
    expect(controller.selected, second);
    expect(board.tiles[first]!.id, before);
  });

  test('洗牌道具立即重排并消耗一枚', () {
    final controller = _controller(stock: {PropKind.shuffle: 1});
    final revision = controller.boardRevision;
    final ids = controller.board.tiles.whereType<Tile>().map((t) => t.id).toSet();

    expect(controller.activateProp(PropKind.shuffle), isTrue);
    expect(controller.propCount(PropKind.shuffle), 0);
    expect(controller.boardRevision, revision + 1);
    expect(controller.activeProp, isNull);
    final after = controller.board.tiles.whereType<Tile>().map((t) => t.id).toSet();
    expect(after, ids);
    expect(controller.board.tiles.every((tile) => tile != null), isTrue);
  });

  test('道具铺购买后局内库存同步增加', () {
    final controller = _controller(stock: {PropKind.hammer: 0});
    expect(controller.propCount(PropKind.hammer), 0);
    controller.addProp(PropKind.hammer);
    expect(controller.propCount(PropKind.hammer), 1);
    expect(controller.activateProp(PropKind.hammer), isTrue);
    controller.cancelProp();
    expect(controller.activeProp, isNull);
  });
}
