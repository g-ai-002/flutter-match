import 'package:flutter/material.dart';

import '../../game/match_controller.dart';
import '../../models/level.dart';
import 'goal_chip.dart';
import 'hud_action_button.dart';
import 'prop_bar.dart';

/// 对局页顶部悬浮信息：左侧返回、关卡信息与操作提示，右侧目标与步数。
///
/// 整块信息悬浮在棋盘上方的留白里，不参与棋盘布局，出现与消失都不会挪动棋盘。
class GameTopHud extends StatelessWidget {
  const GameTopHud({
    super.key,
    required this.level,
    required this.controller,
    required this.compact,
    this.prompt,
  });

  final Level level;
  final MatchController controller;
  final bool compact;

  /// 道具待命或提示时的操作说明；null 时右侧只显示目标进度。
  final String? prompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 8 : 14,
        compact ? 2 : 8,
        compact ? 8 : 14,
        0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: '返回',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0.4,
                      ),
                    ),
                    Text(
                      level.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              MovesChip(moves: controller.movesLeft),
            ],
          ),
          SizedBox(height: compact ? 2 : 6),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _promptChip(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final progress in controller.goalProgress) ...[
                          GoalChip(progress: progress, compact: true),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _promptChip(BuildContext context) {
    final text = prompt;
    if (text == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: colors.outline),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// 剩余步数胶囊，步数告急时转为警示色。
class MovesChip extends StatelessWidget {
  const MovesChip({super.key, required this.moves});

  final int moves;

  static const Color _urgent = Color(0xFFC0392B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final urgent = moves <= 5;
    final accent = urgent ? _urgent : colors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: urgent ? _urgent.withValues(alpha: 0.5) : colors.outline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 15, color: accent),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '剩余步数',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                '$moves',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 16,
                  height: 1.05,
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 悬浮在棋盘上方的方形图标按钮。
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.surface.withValues(alpha: 0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: colors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 20, color: colors.onSurface),
          ),
        ),
      ),
    );
  }
}

/// 对局页底部工具条：道具、提示与重开。
class GameBottomBar extends StatelessWidget {
  const GameBottomBar({
    super.key,
    required this.compact,
    required this.propCount,
    required this.activeProp,
    required this.onProp,
    required this.onHint,
    required this.onRestart,
  });

  final bool compact;
  final int Function(PropKind kind) propCount;
  final PropKind? activeProp;
  final ValueChanged<PropKind> onProp;
  final VoidCallback? onHint;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 4, 8, compact ? 6 : 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final kind in PropKind.values) ...[
              PropButton(
                kind: kind,
                count: propCount(kind),
                active: activeProp == kind,
                compact: compact,
                onTap: () => onProp(kind),
              ),
              SizedBox(width: compact ? 6 : 8),
            ],
            Container(
              width: 1,
              height: compact ? 24 : 28,
              color: colors.outline.withValues(alpha: 0.8),
            ),
            SizedBox(width: compact ? 6 : 8),
            HudActionButton(
              icon: Icons.lightbulb_outline_rounded,
              label: '提示',
              compact: compact,
              onPressed: onHint,
            ),
            SizedBox(width: compact ? 6 : 8),
            HudActionButton(
              icon: Icons.refresh_rounded,
              label: '重开',
              compact: compact,
              onPressed: onRestart,
            ),
          ],
        ),
      ),
    );
  }
}
