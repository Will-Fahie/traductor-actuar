import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/submission_tabs_screen.dart';
import 'package:myapp/screens/guide_categories_screen.dart';
import 'package:myapp/screens/animal_list_screen.dart';
import 'package:myapp/screens/teaching_resources_screen.dart';
import 'package:myapp/screens/dictionary_screen.dart';
import 'package:myapp/theme/app_theme.dart';
import 'firebase_options.dart';

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
  if (kDebugMode) {
    // Enable debug-specific features
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Traductor Achuar-Español',
      theme: AppTheme.theme,
      themeMode: ThemeMode.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/dictionary': (context) => const DictionaryScreen(),
        '/submit': (context) => const SubmissionTabsScreen(),
        '/translator': (context) => const NotImplementedScreen(featureName: 'Traductor'),
        '/teaching_resources': (context) => const TeachingResourcesScreen(),
        '/guide_resources': (context) => const GuideCategoriesScreen(),
        '/ecolodge_resources': (context) => const NotImplementedScreen(featureName: 'Recursos de Ecolodge'),
        '/birds': (context) => const AnimalListScreen(collectionName: 'animals_birds', title: 'Aves'),
        '/mammals': (context) => const AnimalListScreen(collectionName: 'animals_mammals', title: 'Mamíferos'),
      },
    );
  }
}
