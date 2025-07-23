import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/screens/lesson_screen.dart';
import 'package:myapp/models/vocabulary_item.dart';
import 'package:myapp/models/learning_question.dart';
import 'package:myapp/services/lesson_service.dart';
import 'package:myapp/screens/create_custom_lesson_screen.dart';
import 'package:myapp/services/tts_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class CustomLessonsScreen extends StatefulWidget {
  const CustomLessonsScreen({super.key});

  @override
  State<CustomLessonsScreen> createState() => _CustomLessonsScreenState();
}

class _CustomLessonsScreenState extends State<CustomLessonsScreen> {
  String? _username;
  final Set<String> _downloadingLessons = {};
  final Set<String> _downloadedLessons = {};
  bool _isConnected = true;
  StreamSubscription<dynamic>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _restoreDownloadedCustomLessons();
    _initConnectivity();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restoreDownloadedCustomLessons();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
    });
  }

  Future<void> _restoreDownloadedCustomLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = <String>{};
    // This assumes lesson names are unique and used as keys
    final keys = prefs.getKeys();
    print('[CustomLessons] SharedPreferences keys:');
    for (final key in keys) {
      print('  $key: ${prefs.get(key)}');
      if (key.startsWith('offline_custom_lesson_') && prefs.getBool(key) == true) {
        var lessonName = key.substring('offline_custom_lesson_'.length);
        if (lessonName.endsWith('_downloaded')) {
          lessonName = lessonName.substring(0, lessonName.length - '_downloaded'.length);
        }
        print('[CustomLessons] Restoring downloaded lesson: $lessonName');
        downloaded.add(lessonName);
      }
    }
    setState(() {
      _downloadedLessons.clear();
      _downloadedLessons.addAll(downloaded);
    });
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = !connectivityResult.contains(ConnectivityResult.none);
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isConnected = !result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Lecciones personalizadas',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: _username == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('custom_lessons')
                  .where('username', isEqualTo: _username)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                
                final docs = snapshot.data?.docs ?? [];
                
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 80,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No tienes lecciones personalizadas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Crea tu primera lección personalizada',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                final lessonColors = [
                  const Color(0xFF6B5B95), // Purple
                  const Color(0xFF88B0D3), // Blue
                  const Color(0xFF82B366), // Green
                  const Color(0xFFFA6900), // Orange
                  const Color(0xFFF38630), // Light Orange
                  const Color(0xFF69D2E7), // Cyan
                  const Color(0xFFE94B3C), // Red
                  const Color(0xFF00A86B), // Jade
                ];
                
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final lessonName = data['name'] ?? docs[index].id;
                    final docId = docs[index].id;
                    final color = lessonColors[index % lessonColors.length];
                    final phraseCount = (data['entries'] as List?)?.length ?? 0;
                    final isDownloading = _downloadingLessons.contains(docId);
                    final isDownloaded = _downloadedLessons.contains(lessonName);
                    final isOffline = !_isConnected;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Material(
                        elevation: isDarkMode ? 2 : 4,
                        borderRadius: BorderRadius.circular(16),
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        shadowColor: Colors.black.withOpacity(0.1),
                        child: InkWell(
                          onTap: () {
                            // Open lesson in learning mode
                            final entries = (data['entries'] as List).map((e) => VocabularyItem(
                              achuar: e['achuar'] ?? '',
                              english: e['english'] ?? '',
                              spanish: e['spanish'] ?? '',
                              audioPath: '',
                            )).toList();
                            
                            final lesson = Lesson(
                              name: lessonName,
                              entries: entries,
                            );
                            
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CategoryDetailScreen(lesson: lesson),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                // Main content row
                                Row(
                                  children: [
                                    // Badge with lesson number
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
                                            blurRadius: 12,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    // Lesson details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lessonName,
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.menu_book_rounded,
                                                  size: 14,
                                                  color: color,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '$phraseCount frases',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: color,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Arrow icon
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                                      size: 18,
                                    ),
                                  ],
                                ),
                                // Action buttons section
                                const SizedBox(height: 16),
                                Container(
                                  height: 1,
                                  color: isDarkMode 
                                    ? Colors.white.withOpacity(0.05) 
                                    : Colors.grey.withOpacity(0.1),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Edit button
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CreateCustomLessonScreen(
                                                  lessonName: lessonName,
                                                  initialData: data,
                                                ),
                                              ),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.edit_rounded,
                                                  size: 18,
                                                  color: Colors.blue[600],
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Editar',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.blue[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 24,
                                      color: isDarkMode 
                                        ? Colors.white.withOpacity(0.1) 
                                        : Colors.grey.withOpacity(0.2),
                                    ),
                                    // Download button
                                    if (!kIsWeb)
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: isOffline || isDownloading || isDownloaded
                                                ? null
                                                : () async {
                                                    if (!mounted) return;
                                                    setState(() {
                                                      _downloadingLessons.add(docId);
                                                    });
                                                    
                                                    final messenger = ScaffoldMessenger.of(context);

                                                    try {
                                                      final entries = List<Map<String, dynamic>>.from(data['entries'] as List);
                                                      final phrases = entries
                                                          .map((e) => e['english'] as String? ?? '')
                                                          .where((phrase) => phrase.isNotEmpty)
                                                          .toList();
                                                      
                                                      if (phrases.isEmpty) {
                                                        if (!mounted) return;
                                                        setState(() {
                                                          _downloadingLessons.remove(docId);
                                                        });
                                                        messenger.showSnackBar(
                                                          const SnackBar(
                                                            content: Text('No English phrases to download in this lesson.'),
                                                            backgroundColor: Colors.orange,
                                                          ),
                                                        );
                                                        return;
                                                      }

                                                      print('[CustomLessons] Downloading phrases:');
                                                      for (final phrase in phrases) {
                                                        print('  $phrase');
                                                      }
                                                      final paths = await downloadCustomLessonTTS(phrases, context: context);
                                                      print('[CustomLessons] Downloaded paths:');
                                                      for (final p in paths) {
                                                        print('  $p');
                                                      }
                                                      // Persist download state
                                                      final prefs = await SharedPreferences.getInstance();
                                                      print('[CustomLessons] Setting download state: offline_custom_lesson_${lessonName}_downloaded = true');
                                                      await prefs.setBool('offline_custom_lesson_${lessonName}_downloaded', true);
                                                      
                                                      if (!mounted) return;
                                                      setState(() {
                                                        _downloadingLessons.remove(docId);
                                                        _downloadedLessons.add(lessonName);
                                                      });
                                                      
                                                      messenger.showSnackBar(
                                                        SnackBar(
                                                          content: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.check_circle,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 12),
                                                              Text(
                                                                'Descargados ${paths.length} archivos de audio',
                                                              ),
                                                            ],
                                                          ),
                                                          backgroundColor: Colors.green,
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                      );
                                                    } catch (e) {
                                                      if (!mounted) return;
                                                      setState(() {
                                                        _downloadingLessons.remove(docId);
                                                      });
                                                      
                                                      messenger.showSnackBar(
                                                        SnackBar(
                                                          content: Row(
                                                            children: [
                                                              const Icon(
                                                                Icons.error_outline,
                                                                color: Colors.white,
                                                              ),
                                                              const SizedBox(width: 12),
                                                              const Text(
                                                                'Error al descargar audio',
                                                              ),
                                                            ],
                                                          ),
                                                          backgroundColor: Colors.red,
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                            borderRadius: BorderRadius.circular(8),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (isDownloading)
                                                    SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor: AlwaysStoppedAnimation<Color>(
                                                          Colors.green[600]!,
                                                        ),
                                                      ),
                                                    )
                                                  else if (isDownloaded)
                                                    Icon(
                                                      Icons.check_circle_rounded,
                                                      size: 18,
                                                      color: Colors.green[600],
                                                    )
                                                  else
                                                    Icon(
                                                      Icons.download_rounded,
                                                      size: 18,
                                                      color: Colors.green[600],
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isDownloaded ? 'Descargado' : 'Descargar',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w500,
                                                      color: isOffline ? Colors.grey : Colors.green[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (!kIsWeb)
                                      Container(
                                        width: 1,
                                        height: 24,
                                        color: isDarkMode 
                                          ? Colors.white.withOpacity(0.1) 
                                          : Colors.grey.withOpacity(0.2),
                                      ),
                                    // Delete button
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _showDeleteDialog(
                                            context,
                                            lessonName,
                                            docId,
                                            isDarkMode,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: Colors.red[600],
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Eliminar',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.red[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/create_custom_lesson');
        },
        backgroundColor: const Color(0xFF82B366),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Nueva lección',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(
    BuildContext context,
    String lessonName,
    String docId,
    bool isDarkMode,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode 
              ? const Color(0xFF1E1E1E) 
              : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 32,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Eliminar lección',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '¿Estás seguro de que deseas eliminar la lección "$lessonName"? Esta acción no se puede deshacer.',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode 
                    ? Colors.grey[400] 
                    : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    
    if (confirm == true) {
      await FirebaseFirestore.instance
        .collection('custom_lessons')
        .doc(docId)
        .delete();
      
      final prefs = await SharedPreferences.getInstance();
      final key = 'offline_custom_lessons_${_username}';
      if (prefs.containsKey(key)) {
        final customJson = prefs.getString(key)!;
        final customList = List<Map<String, dynamic>>.from(
          json.decode(customJson)
        );
        customList.removeWhere(
          (e) => (e['name'] ?? docId) == lessonName
        );
        await prefs.setString(key, json.encode(customList));
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Lección eliminada'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}