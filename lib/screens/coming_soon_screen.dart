import 'package:flutter/material.dart';
import 'package:achuar_ingis/theme/app_theme.dart';
import 'package:achuar_ingis/services/language_service.dart';
import 'package:achuar_ingis/l10n/app_localizations.dart';
import 'package:achuar_ingis/widgets/language_toggle.dart';

class ComingSoonScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;

  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: LanguageService(),
          builder: (context, child) {
            return Text(title);
          },
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,

      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with animated container
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 60,
                  color: color,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingXLarge),
              
              // Title
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppTheme.spacingMedium),
              
              // Subtitle
              Text(
                subtitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: AppTheme.spacingLarge),
              
              // Description
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLarge),
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingXLarge),
              
              // Coming Soon Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLarge,
                  vertical: AppTheme.spacingMedium,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withOpacity(0.1),
                      color.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacingSmall),
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.comingSoon ?? 'Próximamente',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
