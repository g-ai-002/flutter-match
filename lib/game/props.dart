/// 局内道具：小锤、换位与洗牌。
enum PropKind {
  hammer,
  swap,
  shuffle;

  String get label => switch (this) {
    PropKind.hammer => '小锤',
    PropKind.swap => '换位',
    PropKind.shuffle => '洗牌',
  };

  String get description => switch (this) {
    PropKind.hammer => '敲掉任意一枚棋子，特殊棋子照常引爆',
    PropKind.swap => '交换任意两枚棋子，形成消除才生效',
    PropKind.shuffle => '立刻重排棋盘，寻找新的连线',
  };

  /// 购买价格，单位为福币。
  int get price => switch (this) {
    PropKind.hammer => 40,
    PropKind.swap => 60,
    PropKind.shuffle => 30,
  };

  /// 首次进入游戏时赠送的数量。
  int get initialStock => switch (this) {
    PropKind.hammer => 2,
    PropKind.swap => 1,
    PropKind.shuffle => 2,
  };

  String get storageKey => 'prop_$name';
}

/// 单局道具库存：只在内存中增减，落盘由界面层负责。
class PropStock {
  PropStock([Map<PropKind, int>? counts])
    : _counts = {for (final kind in PropKind.values) kind: counts?[kind] ?? 0};

  final Map<PropKind, int> _counts;

  int count(PropKind kind) => _counts[kind] ?? 0;

  bool has(PropKind kind) => count(kind) > 0;

  /// 扣掉一枚道具；数量不足时返回 false 且不改动库存。
  bool take(PropKind kind) {
    if (!has(kind)) return false;
    _counts[kind] = count(kind) - 1;
    return true;
  }

  void add(PropKind kind, [int amount = 1]) {
    _counts[kind] = count(kind) + amount;
  }

  Map<PropKind, int> get snapshot => Map.unmodifiable(_counts);
}
