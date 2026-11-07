import 'package:flutter/material.dart';

import '../../game/daily_challenge.dart';
import '../../game/props.dart';
import '../../providers/settings_provider.dart';
import '../../theme/palette.dart';
import 'coin_chip.dart';

/// 道具图标：小锤敲击、换位互换、洗牌重排。
IconData propIcon(PropKind kind) => switch (kind) {
  PropKind.hammer => Icons.gavel_rounded,
  PropKind.swap => Icons.swap_horiz_rounded,
  PropKind.shuffle => Icons.casino_rounded,
};

/// 底部道具按钮：图标 + 数量徽章，待命时用暖金描边强调。
class PropButton extends StatelessWidget {
  const PropButton({
    super.key,
    required this.kind,
    required this.count,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final PropKind kind;
  final int count;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  static const Color _gold = appGold;
  static const Color _goldDeep = appGoldDark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = compact ? 42.0 : 46.0;
    final empty = count <= 0;
    return Tooltip(
      message: '${kind.label} · ${kind.description}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: active
                  ? _gold.withValues(alpha: 0.95)
                  : colors.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: active ? _goldDeep : colors.outline,
                width: active ? 1.4 : 1,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    propIcon(kind),
                    size: compact ? 18 : 20,
                    color: active ? appInkOnGold : colors.onSurface,
                  ),
                ),
                Positioned(
                  right: 3,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: empty ? colors.surfaceContainerHighest : _goldDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      empty ? '+' : '×$count',
                      style: TextStyle(
                        fontSize: 9,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: empty ? colors.onSurfaceVariant : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 道具铺：局内用福币购买道具，购买后立即补充到本局库存。
Future<void> showPropShop(
  BuildContext context, {
  required SettingsProvider settings,
  required PropStock stock,
  ValueChanged<PropKind>? onBought,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: theme.colorScheme.surface,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        final colors = theme.colorScheme;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('道具铺', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    CoinChip(coins: settings.coins),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '通关按星级获得福币，每日挑战首次通关再奖 '
                  '${DailyChallenge.rewardCoins} 福币。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                for (final kind in PropKind.values)
                  _ShopRow(
                    kind: kind,
                    owned: stock.count(kind),
                    coins: settings.coins,
                    onBuy: () async {
                      final bought = await settings.buyProp(kind, stock);
                      if (!bought) return;
                      onBought?.call(kind);
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.kind,
    required this.owned,
    required this.coins,
    required this.onBuy,
  });

  final PropKind kind;
  final int owned;
  final int coins;
  final Future<void> Function() onBuy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final affordable = coins >= kind.price;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: appGold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(propIcon(kind), size: 20, color: appGoldDeep),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(kind.label, style: theme.textTheme.titleSmall),
                    const SizedBox(width: 6),
                    Text(
                      '已有 $owned',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  kind.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: affordable ? () => onBuy() : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              backgroundColor: appRed,
            ),
            child: Text(
              affordable ? '${kind.price} 福币' : '福币不足',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
