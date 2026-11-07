import 'package:flutter_test/flutter_test.dart';
import 'package:fortune_match/game/scoring.dart';

void main() {
  test('连锁倍率从 1 起算并封顶', () {
    expect(ScoreRules.multiplierOf(0), 1);
    expect(ScoreRules.multiplierOf(1), 1);
    expect(ScoreRules.multiplierOf(3), 3);
    expect(ScoreRules.multiplierOf(99), ScoreRules.maxComboMultiplier);
  });

  test('单次消除得分由棋子、特殊棋子与破冰累加', () {
    expect(
      ScoreRules.forClear(tiles: 3, specials: 0, iceBroken: 0, combo: 1),
      3 * ScoreRules.perTile,
    );
    expect(
      ScoreRules.forClear(tiles: 3, specials: 0, iceBroken: 0, combo: 2),
      3 * ScoreRules.perTile * 2,
    );
    expect(
      ScoreRules.forClear(tiles: 4, specials: 1, iceBroken: 2, combo: 2),
      4 * ScoreRules.perTile * 2 +
          ScoreRules.perSpecial +
          2 * ScoreRules.perIce,
    );
  });

  test('按剩余步数占比评星，步数为零的关卡保底一星', () {
    expect(ScoreRules.starsFor(movesLeft: 20, moves: 20), 3);
    expect(ScoreRules.starsFor(movesLeft: 7, moves: 20), 3);
    expect(ScoreRules.starsFor(movesLeft: 6, moves: 20), 2);
    expect(ScoreRules.starsFor(movesLeft: 2, moves: 20), 1);
    expect(ScoreRules.starsFor(movesLeft: 0, moves: 20), 1);
    expect(ScoreRules.starsFor(movesLeft: 5, moves: 0), 1);
  });

  test('通关福币按星级递增，未通关不发放', () {
    expect(ScoreRules.rewardCoins(0), 0);
    expect(ScoreRules.rewardCoins(1), 20);
    expect(ScoreRules.rewardCoins(2), 28);
    expect(ScoreRules.rewardCoins(3), 36);
    expect(ScoreRules.rewardCoins(3), greaterThan(ScoreRules.rewardCoins(2)));
  });
}
