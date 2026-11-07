import 'package:flutter/material.dart';

import '../../game/match_controller.dart';
import 'goal_chip.dart';
import 'star_row.dart';

/// 结算面板：通关星级、分数与目标达成情况，以及下一步操作。
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.controller,
    required this.hasNext,
    required this.onNext,
    required this.onReplay,
    required this.onLevels,
  });

  final MatchController controller;
  final bool hasNext;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onLevels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final won = controller.status == GameStatus.won;
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.8),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 30,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ResultSeal(won: won),
                const SizedBox(height: 12),
                Text(
                  won ? '通关！' : '步数用尽',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  won
                      ? (hasNext ? '福运正旺，继续下一关吧' : '全部关卡已通关，福运圆满')
                      : '目标还没完成，调整思路再试一次',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                if (won) StarRow(stars: controller.stars, size: 34, spacing: 4),
                const SizedBox(height: 12),
                Text(
                  '${controller.score} 分',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFA63A2B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final progress in controller.goalProgress)
                      GoalChip(progress: progress),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onReplay,
                        child: const Text('再来一局'),
                      ),
                    ),
                    if (won && hasNext) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onNext,
                          child: const Text('下一关'),
                        ),
                      ),
                    ] else if (!won) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onReplay,
                          child: const Text('再试一次'),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onLevels,
                  child: const Text('返回关卡列表'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultSeal extends StatelessWidget {
  const _ResultSeal({required this.won});

  final bool won;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: won
              ? const [Color(0xFFE7B24B), Color(0xFFC47A24)]
              : const [Color(0xFF9A8F80), Color(0xFF6B6258)],
        ),
      ),
      child: Text(
        won ? '福' : '叹',
        style: const TextStyle(
          fontSize: 30,
          height: 1,
          fontWeight: FontWeight.w700,
          color: Color(0xFFFFF8EA),
        ),
      ),
    );
  }
}
