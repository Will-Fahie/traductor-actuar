import 'package:flutter/material.dart';
import 'package:achuar_ingis/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(
        bottom: AppTheme.spacingMedium,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 24,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppTheme.spacingSmall),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppTheme.spacingXSmall),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
