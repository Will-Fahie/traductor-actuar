import 'package:flutter/material.dart';
import 'package:myapp/services/lesson_service.dart';
import 'package:myapp/models/vocabulary_item.dart';
import 'package:myapp/screens/lesson_choice_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TeachingResourcesScreen extends StatefulWidget {
  const TeachingResourcesScreen({super.key});

  @override
  _TeachingResourcesScreenState createState() => _TeachingResourcesScreenState();
}

class _TeachingResourcesScreenState extends State<TeachingResourcesScreen> {
  late Future<List<Level>> _levelsFuture;
  bool _isOnline = true;
  bool _allLessonsDownloaded = false;
  bool _isDownloading = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _initUserAndConnectivity();
    _levelsFuture = _loadLevels();
  }

  Future<void> _initUserAndConnectivity() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
    });
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
    final prefs = await SharedPreferences.getInstance();
    _allLessonsDownloaded = prefs.containsKey('offline_lessons');
    setState(() {});
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

  Future<void> _downloadAllLessons() async {
    if (!mounted) return;
    setState(() { _isDownloading = true; });
    final levels = await LessonService().loadLevels();
    // Save built-in lessons as JSON string
    final levelsJson = {
      'levels': levels.map((l) => {
        'name': l.name,
        'lessons': l.lessons.map((lesson) => {
          'name': lesson.name,
          'entries': lesson.entries.map((e) => {
            'achuar': e.achuar,
            'english': e.english,
            'spanish': e.spanish,
            'audioPath': e.audioPath,
          }).toList(),
        }).toList(),
      }).toList(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_lessons', json.encode(levelsJson));
    // Download and save custom lessons for the user
    if (_username != null) {
      final query = await FirebaseFirestore.instance.collection('custom_lessons').where('username', isEqualTo: _username).get();
      final customLessons = query.docs.map((doc) => doc.data()).toList();
      await prefs.setString('offline_custom_lessons_$_username', json.encode(customLessons));
    }
    if (!mounted) return;
    setState(() { _allLessonsDownloaded = true; _isDownloading = false; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lecciones descargadas para uso sin conexión.'),
        backgroundColor: Colors.green[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Recursos de Enseñanza',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
                    color: const Color(0xFFFA6900),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando recursos...',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
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
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasData) {
            final levels = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // (Top section removed as requested)
                  
                  // Custom Lessons card
                  _buildResourceCard(
                    context,
                    title: 'Mis Lecciones',
                    subtitle: 'Crea y gestiona tus propias lecciones',
                    icon: Icons.edit_note,
                    color: const Color(0xFF88B0D3),
                    onTap: () => Navigator.pushNamed(context, '/custom_lessons'),
                    isDarkMode: isDarkMode,
                  ),
                
                  
                  // Level cards with different colors
                  ...levels.asMap().entries.map((entry) {
                    final index = entry.key;
                    final level = entry.value;
                    
                    final levelColors = [
                      const Color(0xFF6B5B95), // Purple
                      const Color(0xFF82B366), // Green
                      const Color(0xFFFA6900), // Orange
                      const Color(0xFF88B0D3), // Blue
                    ];
                    
                    final color = levelColors[index % levelColors.length];
                    
                    // Calculate total lessons (categories removed, as Lesson has no 'categories')
                    // int totalCategories = 0;
                    // for (final lesson in level.lessons) {
                    //   totalCategories += lesson.categories?.length ?? 0;
                    // }
                    
                    return _buildLevelCard(
                      context,
                      level: level,
                      subtitle: '${level.lessons.length} lecciones',
                      icon: Icons.school_outlined,
                      color: color,
                      isDarkMode: isDarkMode,
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
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No se encontraron recursos',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
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
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
        child: Container(
            padding: const EdgeInsets.all(20),
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
                    borderRadius: BorderRadius.circular(14),
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
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
    required bool isDarkMode,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
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
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
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
                    borderRadius: BorderRadius.circular(14),
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
                const SizedBox(width: 16),
                Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
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