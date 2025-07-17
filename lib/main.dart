import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:myapp/screens/home_screen.dart';
import 'package:myapp/screens/submission_tabs_screen.dart';
import 'package:myapp/screens/guide_categories_screen.dart';
import 'package:myapp/screens/animal_list_screen.dart';
import 'package:myapp/screens/teaching_resources_screen.dart';
import 'package:myapp/screens/dictionary_screen.dart';
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
    const primaryColor = Color(0xFF3A86FF);
    const lightBackgroundColor = Color(0xFFF7F9FC);
    const darkBackgroundColor = Color(0xFF1A1A1A);
    const lightCardColor = Colors.white;
    const darkCardColor = Color(0xFF2C2C2C);

    final lightTheme = ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.light),
      scaffoldBackgroundColor: lightBackgroundColor,
      cardColor: lightCardColor,
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(bodyColor: Colors.black87),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
       visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.dark),
      scaffoldBackgroundColor: darkBackgroundColor,
      cardColor: darkCardColor,
      textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme).apply(bodyColor: Colors.white),
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
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return MaterialApp(
      title: 'Traductor Achuar-Español',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
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
