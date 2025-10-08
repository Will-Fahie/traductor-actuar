import 'package:flutter/material.dart';
import 'package:achuar_ingis/theme/app_theme.dart';

class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? elevation;
  final BorderRadius? borderRadius;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.elevation,
    this.borderRadius,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationFast,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: widget.elevation ?? AppTheme.elevationMedium,
      end: (widget.elevation ?? AppTheme.elevationMedium) + 2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: AppTheme.animationCurve,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _animationController.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget card = AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Material(
            elevation: _elevationAnimation.value,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusLarge),
            color: widget.color ?? theme.cardTheme.color,
            shadowColor: theme.cardTheme.shadowColor,
            child: InkWell(
              onTap: null, // Handled by GestureDetector
              borderRadius: widget.borderRadius ?? BorderRadius.circular(AppTheme.radiusLarge),
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.all(AppTheme.spacingMedium),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: card,
      );
    }
    
    return card;
  }
}
