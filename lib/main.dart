import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/submission_tabs_screen.dart';
import 'package:myapp/screens/guide_categories_screen.dart';
import 'package:myapp/screens/animal_list_screen.dart';
import 'package:myapp/screens/teaching_resources_screen.dart';
import 'package:myapp/screens/level1_screen.dart';
import 'package:myapp/screens/level2_screen.dart';
import 'package:myapp/screens/level3_screen.dart';
import 'package:myapp/screens/category_detail_screen.dart';
import 'firebase_options.dart';

// A placeholder screen for features that are not yet implemented
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
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF0A3A67),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: Color(0xFF0A3A67)),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.grey[850],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/dictionary': (context) => const NotImplementedScreen(featureName: 'Diccionario'),
        '/submit': (context) => const SubmissionTabsScreen(),
        '/translator': (context) => const NotImplementedScreen(featureName: 'Traductor'),
        '/teaching_resources': (context) => const TeachingResourcesScreen(),
        '/guide_resources': (context) => const GuideCategoriesScreen(),
        '/ecolodge_resources': (context) => const NotImplementedScreen(featureName: 'Recursos de Ecolodge'),
        '/level1': (context) => const Level1Screen(),
        '/level2': (context) => const Level2Screen(),
        '/level3': (context) => const Level3Screen(),
        '/numbers': (context) => const CategoryDetailScreen(categoryName: 'Números 1-10'),
        '/animals': (context) => const CategoryDetailScreen(categoryName: 'Animales Básicos'),
        '/phrases': (context) => const CategoryDetailScreen(categoryName: 'Frases Básicas'),
        '/colors': (context) => const CategoryDetailScreen(categoryName: 'Colores'),
        '/birds': (context) => const AnimalListScreen(collectionName: 'animals_birds', title: 'Aves'),
        '/mammals': (context) => const AnimalListScreen(collectionName: 'animals_mammals', title: 'Mamíferos'),
      },
    );
  }
}
