import 'package:flutter/material.dart';
import 'package:achuar_ingis/theme/app_theme.dart';

enum AppButtonType { primary, secondary, text, danger }
enum AppButtonSize { small, medium, large }

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Gradient? gradient;
  final Color? backgroundColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.gradient,
    this.backgroundColor,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: AppTheme.animationFast,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
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
    if (widget.onPressed != null && !widget.isLoading) {
      _animationController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _resetAnimation();
  }

  void _onTapCancel() {
    _resetAnimation();
  }

  void _resetAnimation() {
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final buttonChild = widget.isLoading
        ? SizedBox(
            width: _getLoadingSize(),
            height: _getLoadingSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.type == AppButtonType.text 
                    ? theme.colorScheme.primary 
                    : Colors.white,
              ),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: _getIconSize()),
                const SizedBox(width: AppTheme.spacingSmall),
              ],
              Text(widget.label),
            ],
          );

    final button = _buildButton(context, buttonChild);
    
    return widget.fullWidth 
        ? SizedBox(width: double.infinity, child: button) 
        : button;
  }

  Widget _buildButton(BuildContext context, Widget child) {
    Widget button;
    
    switch (widget.type) {
      case AppButtonType.primary:
        if (widget.gradient != null) {
          // Custom gradient button
          button = Material(
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            child: Container(
              decoration: BoxDecoration(
                gradient: widget.onPressed != null && !widget.isLoading ? widget.gradient : null,
                color: widget.onPressed == null || widget.isLoading ? Colors.grey[400] : null,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                boxShadow: widget.onPressed != null && !widget.isLoading ? [
                  BoxShadow(
                    color: (widget.gradient?.colors.first ?? AppTheme.primaryColor).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onPressed,
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                child: Container(
                  padding: _getPadding(),
                  child: DefaultTextStyle(
                    style: _getTextStyle().copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          );
        } else {
          // Default primary button
          button = ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.backgroundColor,
              foregroundColor: widget.backgroundColor != null ? Colors.white : null,
              padding: _getPadding(),
              textStyle: _getTextStyle(),
            ),
            child: child,
          );
        }
        break;
        
      case AppButtonType.secondary:
        button = OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: OutlinedButton.styleFrom(
            padding: _getPadding(),
            textStyle: _getTextStyle(),
          ),
          child: child,
        );
        break;
        
      case AppButtonType.text:
        button = TextButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: TextButton.styleFrom(
            padding: _getPadding(),
            textStyle: _getTextStyle(),
          ),
          child: child,
        );
        break;
        
      case AppButtonType.danger:
        button = ElevatedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            padding: _getPadding(),
            textStyle: _getTextStyle(),
          ),
          child: child,
        );
        break;
    }
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: button,
          ),
        );
      },
    );
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: AppTheme.spacingSmall,
        );
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLarge,
          vertical: AppTheme.spacingMedium,
        );
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXLarge,
          vertical: AppTheme.spacingMedium + 4,
        );
    }
  }

  TextStyle _getTextStyle() {
    switch (widget.size) {
      case AppButtonSize.small:
        return const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
      case AppButtonSize.medium:
        return const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
      case AppButtonSize.large:
        return const TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }

  double _getLoadingSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }
}
