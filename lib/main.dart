
import 'package:flutter/material.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/submission_tabs_screen.dart';
import 'package:myapp/screens/animal_list_screen.dart';
import 'package:myapp/screens/teaching_resources_screen.dart';
import 'package:myapp/screens/dictionary_screen.dart';
import 'package:myapp/screens/translator_screen.dart';
import 'package:myapp/screens/loading_screen.dart';
import 'package:myapp/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/screens/custom_lessons_screen.dart';
import 'package:myapp/screens/create_custom_lesson_screen.dart';
import 'package:myapp/screens/coming_soon_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:myapp/services/language_service.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class NotImplementedScreen extends StatelessWidget {
  final String featureName;
  const NotImplementedScreen({super.key, required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(featureName)),
      body: Center(child: Text('$featureName has not been implemented')),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: "env.json");
  
  // Debug: Check if environment variables are loaded
  final apiKey = dotenv.env['GOOGLE_TTS_API_KEY'];
  print('[MAIN] Google TTS API Key loaded: ${apiKey != null ? 'YES' : 'NO'}');
  if (apiKey != null) {
    print('[MAIN] API Key starts with: ${apiKey.substring(0, 10)}...');
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize language service
  await LanguageService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    print('App initialization - username: $username');
    if (username == null || username.isEmpty) {
      print('No username found, showing WelcomeScreen');
      return const WelcomeScreen();
    } else {
      print('Username found: $username, showing HomeScreen');
      return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getStartScreen(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        return AnimatedBuilder(
          animation: LanguageService(),
          builder: (context, child) {
            return MaterialApp(
              title: 'Traductor Achuar-Español',
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: ThemeMode.system,
              locale: LanguageService().currentLocale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: snapshot.data,
          onUnknownRoute: (settings) {
            print('Unknown route: ${settings.name}');
            return MaterialPageRoute(
              builder: (context) => const HomeScreen(),
            );
          },
          onGenerateRoute: (settings) {
            // Create smooth page transitions for all routes
            Widget? page;
            
            // Handle regular routes
            switch (settings.name) {
              case '/welcome':
                page = const WelcomeScreen();
                break;
              case '/home':
                page = const HomeScreen();
                break;
              case '/loading':
                page = const LoadingScreen();
                break;
              case '/dictionary':
                page = const DictionaryScreen();
                break;
              case '/submit':
                page = const SubmissionTabsScreen();
                break;
              case '/translator':
                page = const TranslatorScreen();
                break;
              case '/teaching_resources':
                page = const TeachingResourcesScreen();
                break;
              case '/guide_resources':
                // Temporarily showing coming soon screen - guide pages still exist
                page = AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return ComingSoonScreen(
                      title: l10n?.guideResourcesTitle ?? 'Recursos de Guía',
                      subtitle: l10n?.comingSoon ?? 'Próximamente',
                      description: l10n?.guideResourcesComingSoon ?? 'Estamos trabajando en recursos educativos de guía incluyendo información sobre la flora, fauna y cultura de la región Achuar. Esta sección estará disponible próximamente con categorías detalladas de aves, mamíferos y otros recursos naturales.',
                      icon: Icons.explore_rounded,
                      color: const Color(0xFFF38630),
                    );
                  },
                );
                break;
              case '/ecolodge_resources':
                page = const NotImplementedScreen(featureName: 'Recursos de Ecolodge');
                break;
              case '/birds':
                page = const AnimalListScreen(collectionName: 'animals_birds', title: 'Aves');
                break;
              case '/mammals':
                page = const AnimalListScreen(collectionName: 'animals_mammals', title: 'Mamíferos');
                break;
              case '/english_achuar_translator':
                page = AnimatedBuilder(
                  animation: LanguageService(),
                  builder: (context, child) {
                    final l10n = AppLocalizations.of(context);
                    return ComingSoonScreen(
                      title: l10n?.englishAchuarTranslator ?? 'Traductor Inglés-Achuar',
                      subtitle: l10n?.comingSoon ?? 'Próximamente',
                      description: l10n?.workingOnFeature ?? 'Estamos trabajando en un traductor directo de Inglés a Achuar. Esta característica estará disponible próximamente y te permitirá traducir directamente desde el inglés al idioma Achuar sin pasos intermedios.',
                      icon: Icons.auto_awesome_rounded,
                      color: const Color(0xFF9C27B0),
                    );
                  },
                );
                break;
            }
            
            // Handle guarded routes
            final guardedRoutes = ['/custom_lessons', '/create_custom_lesson'];
            if (guardedRoutes.contains(settings.name)) {
              return _createAnimatedRoute(
                FutureBuilder<Widget>(
                  future: (() async {
                    final prefs = await SharedPreferences.getInstance();
                    final username = prefs.getString('username');
                    if (username == null || username.isEmpty) {
                      return const WelcomeScreen();
                    }
                    if (settings.name == '/custom_lessons') {
                      return const CustomLessonsScreen();
                    } else if (settings.name == '/create_custom_lesson') {
                      return const CreateCustomLessonScreen();
                    }
                    return const HomeScreen();
                  })(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Scaffold(body: Center(child: CircularProgressIndicator()));
                    }
                    return snapshot.data!;
                  },
                ),
                settings,
              );
            }
            
            // Create animated route for regular pages
            if (page != null) {
              return _createAnimatedRoute(page, settings);
            }
            
            return null;
              },
            );
          },
        );
      },
    );
  }

  PageRouteBuilder _createAnimatedRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      settings: settings,
      transitionDuration: AppTheme.animationMedium,
      reverseTransitionDuration: AppTheme.animationMedium,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide transition from right to left
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppTheme.animationCurveSmooth,
        );

        // Fade transition for the previous page
        final fadeOut = Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).animate(curvedAnimation);

        return Stack(
          children: [
            // Previous page fading out
            if (secondaryAnimation.value > 0)
              FadeTransition(
                opacity: fadeOut,
                child: Container(),
              ),
            // New page sliding in
            SlideTransition(
              position: tween.animate(curvedAnimation),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}
