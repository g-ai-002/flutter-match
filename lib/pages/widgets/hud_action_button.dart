import 'package:flutter/material.dart';

/// 悬浮操作按钮：底部工具条的提示与重开。
class HudActionButton extends StatelessWidget {
  const HudActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.compact = false,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool compact;

  /// 主推按钮（提示）用暖金强调色。
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onPressed != null;
    final background = highlight
        ? const Color(0xFFD9985C).withValues(alpha: 0.92)
        : colors.surface.withValues(alpha: 0.9);
    final foreground = highlight
        ? const Color(0xFF2A1206)
        : enabled
        ? colors.onSurface
        : colors.onSurfaceVariant;
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: compact ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: highlight
                  ? const Color(0xFFB4781E)
                  : colors.outline.withValues(alpha: 0.8),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 17 : 19, color: foreground),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: label, child: button) : button;
  }
}
