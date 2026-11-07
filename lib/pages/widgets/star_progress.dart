import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// 福星总进度条：首页与关卡选择页共用。
class StarProgressBar extends StatelessWidget {
  const StarProgressBar({super.key, required this.value, this.height = 6});

  /// 0 到 1 的完成比例，越界时自动截断。
  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: colors.outline.withValues(alpha: 0.4),
        color: appGold,
      ),
    );
  }
}
