import 'package:flutter/material.dart';

import '../../models/tile.dart';
import '../../theme/tile_art.dart';
import '../../utils/constants.dart';

/// 首页主视觉：扇形陈列的棋子 + 品牌标题与装饰行。
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        const _TileFan(),
        const SizedBox(height: 18),
        Text(
          AppConstants.appName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 40,
            letterSpacing: 8,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OrnamentLine(color: colors.outline),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '三 消 成 趣 · 福 运 连 连',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 2,
                  ),
                ),
              ),
              _OrnamentLine(color: colors.outline),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '交换相邻棋子，连成三枚即可消除',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 五枚棋子的扇形陈列，作为首页主视觉。
class _TileFan extends StatelessWidget {
  const _TileFan();

  static const List<(TileType, double, double)> _layout = [
    (TileType.lantern, 44, -0.13),
    (TileType.jade, 52, -0.07),
    (TileType.coin, 62, 0),
    (TileType.porcelain, 52, 0.07),
    (TileType.lotus, 44, 0.13),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var index = 0; index < _layout.length; index++)
            Transform.translate(
              offset: Offset((index - 2) * 46.0, (index - 2).abs() * 5.0),
              child: Transform.rotate(
                angle: _layout[index].$3,
                child: TileBadge(
                  type: _layout[index].$1,
                  size: _layout[index].$2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrnamentLine extends StatelessWidget {
  const _OrnamentLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 40, height: 1, color: color.withValues(alpha: 0.9));
  }
}
