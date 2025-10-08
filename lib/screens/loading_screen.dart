import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:achuar_ingis/services/sync_service.dart';
import 'package:achuar_ingis/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:achuar_ingis/screens/welcome_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize SyncService and wait for it to complete
    await SyncService().initialize();

    // Check for username and navigate accordingly
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username == null || username.isEmpty) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
