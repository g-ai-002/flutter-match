import 'package:flutter/material.dart';

/// 玩法说明弹窗：交换、连锁、特殊棋子与目标。
Future<void> showRulesDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: const Text('玩法说明'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final rule in const [
              ('交换', '点击或滑动交换相邻棋子，横竖连成三枚同色即可消除。'),
              ('连锁', '消除后上方棋子落下补充，连锁消除分数更高。'),
              ('特殊', '四连生成横扫或竖贯，拐角五连生成爆珠，五连生成福珠。'),
              ('目标', '在步数用尽前完成关卡目标；剩余步数越多越容易拿满三星。'),
            ]) ...[
              Text(rule.$1, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(rule.$2, style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('明白了'),
          ),
        ],
      );
    },
  );
}
