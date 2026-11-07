import 'package:flutter/material.dart';

import '../../models/tile.dart';
import '../../theme/tile_art.dart';

/// 福币余额胶囊：首页顶栏与道具铺共用。
class CoinChip extends StatelessWidget {
  const CoinChip({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TileBadge(type: TileType.coin, size: 18),
          const SizedBox(width: 5),
          Text(
            '$coins',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
