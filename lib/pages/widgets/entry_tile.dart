import 'package:flutter/material.dart';

/// 入口卡片：左侧徽章 + 标题/副标题 + 右侧箭头。
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    return Material(
      color: colors.surface,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: colors.outline.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: 8),
                          trailing!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 入口卡片的方形徽章：图标或文字，底色由强调色淡化得到。
class EntryBadge extends StatelessWidget {
  const EntryBadge({
    super.key,
    required this.accent,
    this.icon,
    this.label,
    this.size = 44,
  }) : assert(icon != null || label != null, '徽章需要图标或文字');

  final Color accent;
  final IconData? icon;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: icon != null
          ? Icon(icon, color: accent, size: size * 0.5)
          : Text(
              label ?? '',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: accent),
            ),
    );
  }
}
