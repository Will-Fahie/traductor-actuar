import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/submission_tabs_screen.dart';
import 'package:myapp/screens/guide_categories_screen.dart';
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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username == null || username.isEmpty) {
      return const WelcomeScreen();
    } else {
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
        return MaterialApp(
          title: 'Traductor Achuar-Español',
          theme: AppTheme.theme,
          themeMode: ThemeMode.light,
          home: snapshot.data,
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/home': (context) => const HomeScreen(),
            '/loading': (context) => const LoadingScreen(),
            '/dictionary': (context) => const DictionaryScreen(),
            '/submit': (context) => const SubmissionTabsScreen(),
            '/translator': (context) => const TranslatorScreen(),
            '/teaching_resources': (context) => const TeachingResourcesScreen(),
            '/guide_resources': (context) => const GuideCategoriesScreen(),
            '/ecolodge_resources': (context) => const NotImplementedScreen(featureName: 'Recursos de Ecolodge'),
            '/birds': (context) => const AnimalListScreen(collectionName: 'animals_birds', title: 'Aves'),
            '/mammals': (context) => const AnimalListScreen(collectionName: 'animals_mammals', title: 'Mamíferos'),
            '/custom_lessons': (context) => const CustomLessonsScreen(),
            '/create_custom_lesson': (context) => const CreateCustomLessonScreen(),
          },
        );
      },
    );
  }
}
