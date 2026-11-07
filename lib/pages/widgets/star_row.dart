import 'package:flutter/material.dart';

/// 三星评级展示：通关星级 + 未获得的灰星。
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.stars,
    this.size = 18,
    this.spacing = 0,
  });

  final int stars;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 3; index++)
          Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : spacing),
            child: Icon(
              index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: index < stars
                  ? const Color(0xFFE9B44C)
                  : colors.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
      ],
    );
  }
}
