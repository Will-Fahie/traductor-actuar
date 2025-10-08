import 'package:flutter/material.dart';
import 'package:achuar_ingis/theme/app_theme.dart';

enum InfoBannerType { info, success, warning, error }

class InfoBanner extends StatefulWidget {
  final String title;
  final String? message;
  final InfoBannerType type;
  final VoidCallback? onDismiss;
  final Widget? action;

  const InfoBanner({
    super.key,
    required this.title,
    this.message,
    this.type = InfoBannerType.info,
    this.onDismiss,
    this.action,
  });

  @override
  State<InfoBanner> createState() => _InfoBannerState();
}

class _InfoBannerState extends State<InfoBanner> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationMedium,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurveSmooth,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _getColors();
    
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMedium),
          decoration: BoxDecoration(
            color: colors.backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: colors.borderColor,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                colors.icon,
                color: colors.iconColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spacingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.message != null) ...[
                      const SizedBox(height: AppTheme.spacingXSmall),
                      Text(
                        widget.message!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (widget.action != null) ...[
                      const SizedBox(height: AppTheme.spacingSmall),
                      widget.action!,
                    ],
                  ],
                ),
              ),
              if (widget.onDismiss != null) ...[
                const SizedBox(width: AppTheme.spacingSmall),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colors.textColor,
                    size: 20,
                  ),
                  onPressed: _dismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _BannerColors _getColors() {
    switch (widget.type) {
      case InfoBannerType.info:
        return _BannerColors(
          backgroundColor: AppTheme.infoColor.withOpacity(0.1),
          borderColor: AppTheme.infoColor.withOpacity(0.3),
          iconColor: AppTheme.infoColor,
          textColor: AppTheme.infoColor.withOpacity(0.9),
          icon: Icons.info_rounded,
        );
      case InfoBannerType.success:
        return _BannerColors(
          backgroundColor: AppTheme.successColor.withOpacity(0.1),
          borderColor: AppTheme.successColor.withOpacity(0.3),
          iconColor: AppTheme.successColor,
          textColor: AppTheme.successColor.withOpacity(0.9),
          icon: Icons.check_circle_rounded,
        );
      case InfoBannerType.warning:
        return _BannerColors(
          backgroundColor: AppTheme.warningColor.withOpacity(0.1),
          borderColor: AppTheme.warningColor.withOpacity(0.3),
          iconColor: AppTheme.warningColor,
          textColor: const Color(0xFFB37E00),
          icon: Icons.warning_amber_rounded,
        );
      case InfoBannerType.error:
        return _BannerColors(
          backgroundColor: AppTheme.errorColor.withOpacity(0.1),
          borderColor: AppTheme.errorColor.withOpacity(0.3),
          iconColor: AppTheme.errorColor,
          textColor: AppTheme.errorColor.withOpacity(0.9),
          icon: Icons.error_rounded,
        );
    }
  }
}

class _BannerColors {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  _BannerColors({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}
