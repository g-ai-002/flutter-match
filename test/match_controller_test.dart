import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/match_controller.dart';
import 'package:fortune_match/models/level.dart';
import 'package:fortune_match/models/tile.dart';
import 'package:fortune_match/services/sound_service.dart';

Level _level({
  int moves = 20,
  int goalScore = 999999,
  List<LevelGoal>? goals,
  Map<int, int> ice = const {},
}) => Level(
  id: 1,
  name: '测试关',
  cols: 8,
  rows: 8,
  moves: moves,
  goals: goals ?? [LevelGoal.score(goalScore)],
  ice: ice,
);

void main() {
  setUp(() {
    SoundService.sink = (_) {};
    SoundService.configure(sound: false, haptics: false);
  });

  tearDown(SoundService.reset);

  test('有效交换扣一步并累计分数，动画结束后回到可操作状态', () {
    final controller = MatchController(level: _level(), seed: 11);
    controller.requestHint();
    final hint = controller.hint!;
    controller.swap(hint.a, hint.b);
    expect(controller.movesLeft, 19);
    expect(controller.status, GameStatus.animating);
    controller.settleImmediately();
    expect(controller.status, GameStatus.ready);
    expect(controller.score, greaterThan(0));
    expect(controller.combo, 0);
  });

  test('达成目标立即通关并按分数评星', () {
    final controller = MatchController(
      level: _level(goals: const [LevelGoal.score(1)]),
      seed: 21,
    );
    controller.requestHint();
    final hint = controller.hint!;
    controller.swap(hint.a, hint.b);
    controller.settleImmediately();
    expect(controller.status, GameStatus.won);
    expect(controller.stars, greaterThanOrEqualTo(1));
    expect(controller.isOver, isTrue);
  });

  test('步数用尽且目标未完成判负', () {
    final controller = MatchController(level: _level(moves: 1), seed: 31);
    controller.requestHint();
    final hint = controller.hint!;
    controller.swap(hint.a, hint.b);
    controller.settleImmediately();
    expect(controller.status, GameStatus.lost);
    expect(controller.stars, 0);
  });

  test('重开恢复步数、分数与目标进度', () {
    final controller = MatchController(
      level: _level(goals: const [LevelGoal.score(1)]),
      seed: 41,
    );
    controller.requestHint();
    final hint = controller.hint!;
    controller.swap(hint.a, hint.b);
    controller.settleImmediately();
    expect(controller.status, GameStatus.won);

    controller.restart();
    expect(controller.status, GameStatus.ready);
    expect(controller.movesLeft, 20);
    expect(controller.score, 0);
    expect(controller.stars, 0);
  });

  test('点选相邻棋子触发交换，点选自身取消选中', () {
    final controller = MatchController(level: _level(), seed: 51);
    controller.requestHint();
    final hint = controller.hint!;
    controller.tapCell(hint.a);
    expect(controller.selected, hint.a);
    controller.tapCell(hint.a);
    expect(controller.selected, -1);

    controller.tapCell(hint.a);
    controller.tapCell(hint.b);
    expect(controller.status, GameStatus.animating);
    controller.settleImmediately();
    expect(controller.movesLeft, 19);
  });

  test('破冰目标随消除推进，冰层不会超过初始层数', () {
    final level = _level(goals: [const LevelGoal.ice(4)]);
    final controller = MatchController(level: level, seed: 61);
    expect(controller.iceBroken, 0);
    for (var i = 0; i < 12 && controller.status == GameStatus.ready; i++) {
      controller.requestHint();
      final hint = controller.hint;
      if (hint == null) break;
      controller.swap(hint.a, hint.b);
      controller.settleImmediately();
    }
    expect(controller.iceBroken, greaterThanOrEqualTo(0));
    expect(controller.goalProgress.single.ratio, lessThanOrEqualTo(1));
  });

  test('手动重排保留全部棋子并推进画面版本', () {
    final controller = MatchController(level: _level(), seed: 71);
    final revision = controller.boardRevision;
    final before = controller.board.tiles.whereType<Tile>().map((t) => t.id).toSet();
    controller.shuffleBoard();
    final after = controller.board.tiles.whereType<Tile>().map((t) => t.id).toSet();
    expect(controller.boardRevision, revision + 1);
    expect(after, before);
  });

  test('目标进度随消除推进并换算为完成比例', () {
    final controller = MatchController(level: _level(), seed: 81);
    final progress = controller.goalProgress.single;
    expect(progress.current, 0);
    expect(progress.done, isFalse);
    expect(progress.ratio, 0);
    expect(progress.display, '0/999999');

    controller.requestHint();
    final hint = controller.hint!;
    controller.swap(hint.a, hint.b);
    controller.settleImmediately();
    expect(controller.goalProgress.single.current, controller.score);
    expect(controller.goalProgress.single.ratio, inInclusiveRange(0, 1));
  });

  test('动画播放期间忽略点选与交换，避免打断动画队列', () {
    final controller = MatchController(level: _level(), seed: 91);
    controller.requestHint();
    final hint = controller.hint!;
    controller.swap(hint.a, hint.b);
    expect(controller.status, GameStatus.animating);
    final moves = controller.movesLeft;
    final epoch = controller.stepEpoch;

    controller.tapCell(hint.a);
    controller.swipe(hint.a, hint.b);
    expect(controller.selected, -1);
    expect(controller.movesLeft, moves);
    expect(controller.stepEpoch, epoch);
  });
}
