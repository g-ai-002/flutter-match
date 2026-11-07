import 'package:flutter/material.dart';

/// 设置页与首页等信息卡片的统一容器。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.trailing,
    this.radius = 14,
    this.color,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;
  final Widget? trailing;
  final double radius;

  /// 卡片底色，缺省为当前主题的 surface。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: colors.primary),
                const SizedBox(width: 8),
              ],
              Text(title, style: theme.textTheme.titleSmall),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
