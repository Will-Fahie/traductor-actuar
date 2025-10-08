import 'package:flutter/material.dart';
import 'package:achuar_ingis/services/lesson_service.dart';
import 'package:achuar_ingis/screens/lesson_choice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:achuar_ingis/theme/app_theme.dart';
import 'package:achuar_ingis/widgets/section_header.dart';
import 'package:achuar_ingis/services/language_service.dart';
import 'package:achuar_ingis/l10n/app_localizations.dart';

class TeachingResourcesScreen extends StatefulWidget {
  const TeachingResourcesScreen({super.key});

  @override
  _TeachingResourcesScreenState createState() => _TeachingResourcesScreenState();
}

class _TeachingResourcesScreenState extends State<TeachingResourcesScreen> {
  late Future<List<Level>> _levelsFuture;
  bool _isOnline = true;
  bool _isGuestMode = false;

  @override
  void initState() {
    super.initState();
    _initUserAndConnectivity();
    _checkGuestMode();
    _levelsFuture = _loadLevels();
  }
  
  Future<void> _checkGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuestMode = prefs.getBool('guest_mode') ?? false;
    setState(() {
      _isGuestMode = isGuestMode;
    });
  }

  Future<void> _initUserAndConnectivity() async {
    await _checkConnectivityAndLocal();
  }

  Future<void> _checkConnectivityAndLocal() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = !result.contains(ConnectivityResult.none);
    });
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isOnline = !result.contains(ConnectivityResult.none);
      });
    });
  }

  Future<List<Level>> _loadLevels() async {
    final prefs = await SharedPreferences.getInstance();
    final isOffline = !_isOnline;
    List<Level> builtInLevels = [];
    // Custom lessons are not added to the levels list
    if (isOffline && prefs.containsKey('offline_lessons')) {
      final data = await Future.value(json.decode(prefs.getString('offline_lessons')!)) as Map<String, dynamic>;
      var levelsList = data['levels'] as List;
      builtInLevels = levelsList.map((i) => Level.fromJson(i)).toList();
    } else {
      builtInLevels = await LessonService().loadLevels();
    }
    return builtInLevels;
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: LanguageService(),
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            return Text(l10n?.teachingResourcesTitle ?? 'Recursos de Enseñanza');
          },
        ),
        elevation: 0,

      ),
      body: FutureBuilder<List<Level>>(
        future: _levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  AnimatedBuilder(
                    animation: LanguageService(),
                    builder: (context, child) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.loadingResources ?? 'Cargando recursos...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    'Error: ${snapshot.error}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final levels = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section header
                  AnimatedBuilder(
                    animation: LanguageService(),
                    builder: (context, child) {
                      final l10n = AppLocalizations.of(context);
                      return SectionHeader(
                        title: l10n?.availableResources ?? 'Recursos disponibles',
                        subtitle: l10n?.accessLessonsAndMaterials ?? 'Accede a lecciones y materiales educativos',
                        icon: Icons.school_rounded,
                      );
                    },
                  ),
                  
                  // Custom Lessons card (hidden in guest mode)
                  if (!_isGuestMode)
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return _buildResourceCard(
                          context,
                          title: l10n?.myLessons ?? 'Mis Lecciones',
                          subtitle: l10n?.createAndManageLessons ?? 'Crea y gestiona tus propias lecciones',
                          icon: Icons.edit_note_rounded,
                          color: AppTheme.secondaryColor,
                          onTap: () => Navigator.pushNamed(context, '/custom_lessons'),
                        );
                      },
                    ),
                
                  
                  // Level cards with different colors
                  ...levels.asMap().entries.map((entry) {
                    final index = entry.key;
                    final level = entry.value;
                    
                    final levelColors = [
                      AppTheme.primaryColor,
                      AppTheme.accentColor,
                      const Color(0xFFFA6900), // Orange
                      AppTheme.secondaryColor,
                    ];
                    
                    final color = levelColors[index % levelColors.length];
                    
                    // Calculate total lessons (categories removed, as Lesson has no 'categories')
                    // int totalCategories = 0;
                    // for (final lesson in level.lessons) {
                    //   totalCategories += lesson.categories?.length ?? 0;
                    // }
                    
                    final l10n = AppLocalizations.of(context);
                    return _buildLevelCard(
                      context,
                      level: level,
                      subtitle: '${level.lessons.length} ${l10n?.lessons ?? 'lecciones'}',
                      icon: Icons.school_outlined,
                      color: color,
                    );
                  }).toList(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 48,
                      color: theme.colorScheme.primary.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingLarge),
                  AnimatedBuilder(
                    animation: LanguageService(),
                    builder: (context, child) {
                      final l10n = AppLocalizations.of(context);
                      return Text(
                        l10n?.noResourcesFound ?? 'No se encontraron recursos',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildResourceCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        color: theme.cardColor,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
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
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSmall),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: theme.textTheme.bodySmall?.color,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLevelCard(
    BuildContext context, {
    required Level level,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        color: theme.cardColor,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LevelScreen(level: level),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacingLarge),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
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
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        level.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSmall),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: theme.textTheme.bodySmall?.color,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}