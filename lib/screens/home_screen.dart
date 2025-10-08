import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:achuar_ingis/theme/app_theme.dart';
import 'package:achuar_ingis/widgets/app_card.dart';
import 'package:achuar_ingis/widgets/app_button.dart';
import 'package:achuar_ingis/services/language_service.dart';
import 'package:achuar_ingis/l10n/app_localizations.dart';
import 'package:achuar_ingis/widgets/language_toggle.dart';
import 'package:achuar_ingis/widgets/info_banner.dart';
import 'package:achuar_ingis/widgets/section_header.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isGuestMode = false;
  AnimationController? _staggerController;
  List<Animation<double>>? _fadeAnimations;
  List<Animation<Offset>>? _slideAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkGuestMode();
    _startAnimations();
  }

  void _setupAnimations() {
    _staggerController = AnimationController(
      duration: AppTheme.animationSlow * 2,
      vsync: this,
    );

    const menuItemCount = 5;
    _fadeAnimations = List.generate(menuItemCount, (index) {
      final start = index * 0.1;
      final end = start + 0.5;
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _staggerController!,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: AppTheme.animationCurveSmooth),
      ));
    });

    _slideAnimations = List.generate(menuItemCount, (index) {
      final start = index * 0.1;
      final end = start + 0.5;
      return Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _staggerController!,
        curve: Interval(start, end.clamp(0.0, 1.0), curve: AppTheme.animationCurveSmooth),
      ));
    });
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _staggerController != null) {
        _staggerController!.forward();
      }
    });
  }

  @override
  void dispose() {
    _staggerController?.dispose();
    super.dispose();
  }

  Future<void> _checkGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuestMode = prefs.getBool('guest_mode') ?? false;
    if (mounted) {
      setState(() {
        _isGuestMode = isGuestMode;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1400 : double.infinity),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : AppTheme.spacingMedium,
                vertical: isDesktop ? 24 : AppTheme.spacingMedium,
              ),
              children: [
                // Guest mode warning message
                if (_isGuestMode) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingMedium),
                    child: InfoBanner(
                      title: 'Modo Invitado',
                      message: 'Aunque es posible crear lecciones personalizadas y listas en modo invitado, si te desconectas es probable que pierdas estos datos. Para guardar lecciones personalizadas, traducciones y listas, crea una cuenta.',
                      type: InfoBannerType.warning,
                    ),
                  ),
                ],
                // Welcome section
                AppCard(
                  padding: EdgeInsets.all(isDesktop ? AppTheme.spacingLarge : AppTheme.spacingLarge),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AnimatedBuilder(
                                  animation: LanguageService(),
                                  builder: (context, child) {
                                    final l10n = AppLocalizations.of(context);
                                    return Text(
                                      l10n?.welcomeTitle ?? 'Winiajai!',
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: AppTheme.spacingSmall),
                                AnimatedBuilder(
                                  animation: LanguageService(),
                                  builder: (context, child) {
                                    final l10n = AppLocalizations.of(context);
                                    return Text(
                                      l10n?.welcomeSubtitle ?? 'Explora las herramientas de traducción y recursos educativos.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacingMedium),
                          Column(
                            children: [
                              AnimatedBuilder(
                                animation: LanguageService(),
                                builder: (context, child) {
                                  final l10n = AppLocalizations.of(context);
                                  return AppButton(
                                    label: l10n?.logoutButton ?? 'Cerrar sesión',
                                    icon: Icons.logout_rounded,
                                    size: AppButtonSize.small,
                                    type: AppButtonType.danger,
                                    onPressed: () async {
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.remove('username');
                                      await prefs.remove('guest_mode');
                                      Navigator.of(context).pushNamedAndRemoveUntil('/loading', (route) => false);
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: AppTheme.spacingSmall),
                              const LanguageToggle(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: isDesktop ? 28 : AppTheme.spacingLarge),
                
                // Main menu section
                AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return SectionHeader(
                      title: l10n?.homeTitle ?? 'Herramientas',
                      subtitle: l10n?.homeSubtitle ?? 'Accede a todas las funciones de la aplicación',
                      icon: Icons.apps_rounded,
                    );
                  },
                ),
                
                SizedBox(height: isDesktop ? 20 : AppTheme.spacingMedium),
                
                // Responsive menu grid
                _buildResponsiveMenuGrid(),
                
                SizedBox(height: isDesktop ? 24 : AppTheme.spacingXLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveMenuGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        // Determine grid layout based on screen size
        int crossAxisCount;
        double childAspectRatio;
        double maxWidth;
        double horizontalPadding;
        double spacing;
        
        if (screenWidth >= 1200) {
          // Large Desktop: 3 columns with constrained width
          crossAxisCount = 3;
          childAspectRatio = 1.5;
          maxWidth = 1200;
          horizontalPadding = 40;
          spacing = 20;
        } else if (screenWidth >= 900) {
          // Desktop: 3 columns
          crossAxisCount = 3;
          childAspectRatio = 1.45;
          maxWidth = 1000;
          horizontalPadding = 32;
          spacing = 18;
        } else if (screenWidth >= 600) {
          // Tablet: 3 columns
          crossAxisCount = 3;
          childAspectRatio = 1.1;
          maxWidth = double.infinity;
          horizontalPadding = 20;
          spacing = 16;
        } else {
          // Mobile: 2 columns
          crossAxisCount = 2;
          childAspectRatio = 1.2;
          maxWidth = double.infinity;
          horizontalPadding = 16;
          spacing = 12;
        }
        
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
                childAspectRatio: childAspectRatio,
              children: [
                AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return _buildAnimatedMenuItem(
                      context,
                      index: 0,
                      title: l10n?.dictionary ?? 'Diccionario',
                      subtitle: l10n?.dictionarySubtitle ?? 'Buscar palabras',
                      icon: Icons.book_rounded,
                      routeName: '/dictionary',
                      color: AppTheme.primaryColor,
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return _buildAnimatedMenuItem(
                      context,
                      index: 1,
                      title: l10n?.spanishAchuar ?? 'Español-Achuar',
                      subtitle: l10n?.translator ?? 'Traductor',
                      icon: Icons.translate_rounded,
                      routeName: '/translator',
                      color: AppTheme.accentColor,
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return _buildAnimatedMenuItem(
                      context,
                      index: 2,
                      title: l10n?.phraseSubmission ?? 'Envío de Frases',
                      subtitle: l10n?.contribute ?? 'Contribuir',
                      icon: Icons.send_rounded,
                      routeName: '/submit',
                      color: AppTheme.secondaryColor,
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return _buildAnimatedMenuItem(
                      context,
                      index: 3,
                      title: l10n?.teaching ?? 'Enseñanza',
                      subtitle: l10n?.educationalResources ?? 'Recursos educativos',
                      icon: Icons.school_rounded,
                      routeName: '/teaching_resources',
                      color: const Color(0xFFFA6900),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return _buildAnimatedMenuItem(
                      context,
                      index: 4,
                      title: l10n?.guides ?? 'Guías',
                      subtitle: l10n?.comingSoon ?? 'Próximamente',
                      icon: Icons.explore_rounded,
                      routeName: '/guide_resources',
                      color: const Color(0xFFF38630),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return _buildAnimatedMenuItem(
                      context,
                      index: 5,
                      title: l10n?.englishAchuar ?? 'Inglés-Achuar',
                      subtitle: l10n?.comingSoon ?? 'Próximamente',
                      icon: Icons.auto_awesome_rounded,
                      routeName: '/english_achuar_translator',
                      color: const Color(0xFF9C27B0),
                    );
                  },
                ),
              ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedMenuItem(
    BuildContext context, {
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required String routeName,
    required Color color,
  }) {
    // If animations aren't ready yet, show static item
    if (_slideAnimations == null || _fadeAnimations == null || 
        index >= _slideAnimations!.length || index >= _fadeAnimations!.length) {
      return _buildMenuItem(
        context,
        title: title,
        subtitle: subtitle,
        icon: icon,
        routeName: routeName,
        color: color,
      );
    }
    
    return SlideTransition(
      position: _slideAnimations![index],
      child: FadeTransition(
        opacity: _fadeAnimations![index],
        child: _buildMenuItem(
          context,
          title: title,
          subtitle: subtitle,
          icon: icon,
          routeName: routeName,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String routeName,
    required Color color,
  }) {
    final theme = Theme.of(context);
    
    return AppCard(
      onTap: () => _navigateWithAnimation(routeName),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
        vertical: AppTheme.spacingMedium,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.8),
                  color,
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 13,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateWithAnimation(String routeName) {
    // Add haptic feedback
    HapticFeedback.lightImpact();
    
    // Use regular navigation with enhanced transition
    Navigator.pushNamed(context, routeName);
  }
}