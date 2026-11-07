/// 计分与评星规则：把散落在控制器里的魔数集中到一处，便于调参与测试。
class ScoreRules {
  ScoreRules._();

  /// 每枚普通棋子的基础分。
  static const int perTile = 50;

  /// 每枚新生成特殊棋子的额外分。
  static const int perSpecial = 150;

  /// 每敲碎一层冰的额外分。
  static const int perIce = 100;

  /// 连锁倍率上限，避免高连锁把分数拉得过高。
  static const int maxComboMultiplier = 6;

  /// 通关时剩余步数占比不低于该值评三星。
  static const double threeStarRemaining = 0.34;

  /// 通关时剩余步数占比不低于该值评两星。
  static const double twoStarRemaining = 0.12;

  /// 连锁序号对应的分数倍率，从 1 起算。
  static int multiplierOf(int combo) => combo.clamp(1, maxComboMultiplier);

  /// 单次消除的得分：棋子数 × 连锁倍率 + 特殊棋子 + 破冰。
  static int forClear({
    required int tiles,
    required int specials,
    required int iceBroken,
    required int combo,
  }) =>
      tiles * perTile * multiplierOf(combo) +
      specials * perSpecial +
      iceBroken * perIce;

  /// 通关福币奖励：基础 12 枚，每颗星再加 8 枚；未通关不发放。
  static int rewardCoins(int stars) => stars <= 0 ? 0 : 12 + stars * 8;

  /// 按通关时剩余步数占比评星，未通关返回 0。
  static int starsFor({required int movesLeft, required int moves}) {
    if (moves <= 0) return 1;
    final remaining = movesLeft / moves;
    if (remaining >= threeStarRemaining) return 3;
    if (remaining >= twoStarRemaining) return 2;
    return 1;
  }
}
