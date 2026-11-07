import 'package:flutter/material.dart';

import '../../game/match_controller.dart';
import '../../models/level.dart';
import '../../theme/palette.dart';
import '../../theme/tile_art.dart';

/// 关卡目标进度胶囊：HUD 与结算面板共用。
class GoalChip extends StatelessWidget {
  const GoalChip({super.key, required this.progress, this.compact = false});

  final GoalProgress progress;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final goal = progress.goal;
    final done = progress.done;
    final accent = done ? appSuccess : colors.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: done ? appSuccess.withValues(alpha: 0.6) : colors.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _leading(done, compact),
          SizedBox(width: compact ? 4 : 6),
          Text(
            compact
                ? '${progress.current}/${progress.target}'
                : '${goal.label} ${progress.current}/${progress.target}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: compact ? 10.5 : 11.5,
              color: accent,
              fontWeight: done ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (done) ...[
            const SizedBox(width: 3),
            const Icon(Icons.check_rounded, size: 13, color: appSuccess),
          ],
        ],
      ),
    );
  }

  Widget _leading(bool done, bool compact) {
    final size = compact ? 15.0 : 17.0;
    switch (progress.goal.kind) {
      case GoalKind.collect:
        return TileBadge(type: progress.goal.type!, size: size);
      case GoalKind.score:
        return Icon(Icons.auto_awesome_rounded, size: size, color: appGold);
      case GoalKind.ice:
        return Icon(
          Icons.ac_unit_rounded,
          size: size,
          color: done ? appSuccess : appIce,
        );
    }
  }
}
