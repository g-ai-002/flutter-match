import 'tile.dart';

/// 关卡目标类型。
enum GoalKind { score, collect, ice }

/// 单条关卡目标：分数、收集指定棋子或敲碎冰层。
class LevelGoal {
  const LevelGoal.score(this.target)
    : kind = GoalKind.score,
      type = null;

  const LevelGoal.collect(TileType this.type, this.target)
    : kind = GoalKind.collect;

  const LevelGoal.ice(this.target)
    : kind = GoalKind.ice,
      type = null;

  final GoalKind kind;
  final TileType? type;
  final int target;

  String get label => switch (kind) {
    GoalKind.score => '得分 $target',
    GoalKind.collect => '收集${type?.label ?? ''}',
    GoalKind.ice => '破冰 $target 块',
  };

  /// 单行紧凑写法，用棋子纹样代替名称，适合多目标并排展示。
  String get shortLabel => switch (kind) {
    GoalKind.score => '得分 $target',
    GoalKind.collect => '收集${type?.glyph ?? ''} $target',
    GoalKind.ice => '破冰 $target',
  };

  /// 目标进度读数的单位后缀。
  String get unit => switch (kind) {
    GoalKind.score => '分',
    GoalKind.collect => '个',
    GoalKind.ice => '块',
  };
}

/// 关卡定义：棋盘规格、步数、目标、冰层布局与星级门槛。
class Level {
  const Level({
    required this.id,
    required this.name,
    required this.cols,
    required this.rows,
    required this.moves,
    required this.goals,
    this.palette = 6,
    this.ice = const {},
    this.dailyKey,
    this.dailySeed,
  });

  final int id;
  final String name;
  final int cols;
  final int rows;
  final int moves;
  final List<LevelGoal> goals;

  /// 出现几种棋子，前几关只用 5 种以降低难度。
  final int palette;

  /// 初始冰层：格子下标 → 冰层数（1 或 2）。
  final Map<int, int> ice;

  /// 每日挑战的日期键；闯关关卡为 null。
  final String? dailyKey;

  /// 每日挑战的棋盘种子，同一天开局一致。
  final int? dailySeed;

  bool get isDaily => dailyKey != null;

  int get cellCount => cols * rows;

  String get sizeLabel => '$cols × $rows';

  /// HUD 首行的关卡标识，每日挑战不显示关卡序号。
  String get heading => isDaily ? '每日挑战 · $sizeLabel' : '第 $id 关 · $sizeLabel';
}
