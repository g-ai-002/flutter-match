import 'package:flutter/material.dart';

import '../../models/tile.dart';
import '../../theme/tile_art.dart';
import '../../utils/constants.dart';
import 'coin_chip.dart';

/// 首页顶栏：品牌标识、福币余额、玩法说明、深浅色切换与设置入口。
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.coins,
    required this.darkMode,
    required this.onShowRules,
    required this.onToggleDarkMode,
    required this.onOpenSettings,
  });

  final int coins;
  final bool darkMode;
  final VoidCallback onShowRules;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.primary, width: 1.3),
          ),
          child: const TileBadge(type: TileType.coin),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppConstants.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                'FORTUNE MATCH',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1.6,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '玩法说明',
          onPressed: onShowRules,
          icon: const Icon(Icons.help_outline_rounded, size: 21),
        ),
        CoinChip(coins: coins),
        const SizedBox(width: 2),
        IconButton(
          tooltip: darkMode ? '切换浅色' : '切换深色',
          onPressed: onToggleDarkMode,
          icon: Icon(
            darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 21,
          ),
        ),
        IconButton(
          tooltip: '设置',
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined, size: 21),
        ),
      ],
    );
  }
}
