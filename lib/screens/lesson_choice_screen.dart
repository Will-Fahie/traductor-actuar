import 'package:flutter/material.dart';
import 'package:achuar_ingis/models/vocabulary_item.dart';
import 'package:achuar_ingis/services/lesson_service.dart';
import 'package:achuar_ingis/screens/lesson_screen.dart';
import 'package:achuar_ingis/services/tts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:achuar_ingis/l10n/app_localizations.dart';

class LevelScreen extends StatefulWidget {
  final Level level;
  
  const LevelScreen({super.key, required this.level});

  @override
  State<LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<LevelScreen> {
  final Set<int> _downloadingLessons = {};
  final Set<int> _downloadedLessons = {};
  bool _isConnected = true;
  StreamSubscription<dynamic>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _restoreDownloadedLessons();
    _initConnectivity();
  }

  Future<void> _restoreDownloadedLessons() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<int> downloaded = {};
    for (int i = 0; i < widget.level.lessons.length; i++) {
      final lesson = widget.level.lessons[i];
      final isDownloaded = prefs.getBool('offline_lesson_${lesson.name}_downloaded') ?? false;
      if (isDownloaded) downloaded.add(i);
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
        title: Text(
          widget.level.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Lessons list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: widget.level.lessons.length,
              itemBuilder: (context, index) {
                final lesson = widget.level.lessons[index];
                final lessonNumber = index + 1;
                
                // Define colors for different lessons
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
                
                final color = lessonColors[index % lessonColors.length];
                
                return _buildLessonCard(
                  context,
                  lesson: lesson,
                  lessonNumber: lessonNumber,
                  lessonIndex: index,
                  color: color,
                  isDarkMode: isDarkMode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(
    BuildContext context, {
    required Lesson lesson,
    required int lessonNumber,
    required int lessonIndex,
    required Color color,
    required bool isDarkMode,
  }) {
    final isDownloading = _downloadingLessons.contains(lessonIndex);
    final isDownloaded = _downloadedLessons.contains(lessonIndex);
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
            child: Row(
              children: [
                // Lesson number badge
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
                      '$lessonNumber',
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
                        lesson.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
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
                                  '${lesson.entries.length} frases',
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
                    ],
                  ),
                ),
                // Download status/button
                if (!kIsWeb)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: isDownloading
                        ? Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          )
                        : isDownloaded
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.green.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 16,
                                      color: Colors.green[700],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Descargado',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isOffline || isDownloading || isDownloaded ? null : () async {
                                    if (!mounted) return;
                                    final l10n = AppLocalizations.of(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(l10n?.doNotLeaveWhileDownloading ?? 'Please do not leave this page while downloading.'),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                    setState(() {
                                      _downloadingLessons.add(lessonIndex);
                                    });
                                    
                                    try {
                                      final phrases = lesson.entries
                                          .map((e) => e.english)
                                          .toList();
                                      final paths = await downloadLessonTTS(phrases);
                                      if (!mounted) return;
                                      setState(() {
                                        _downloadingLessons.remove(lessonIndex);
                                        _downloadedLessons.add(lessonIndex);
                                      });
                                      
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setBool('offline_lesson_${lesson.name}_downloaded', true);

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
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
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
                                      setState(() {
                                        _downloadingLessons.remove(lessonIndex);
                                      });
                                      
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
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
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.grey[800]!
                                            : Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      isDownloaded ? Icons.check_circle_rounded : Icons.download_rounded,
                                      size: 18,
                                      color: isOffline ? Colors.grey : Colors.blue,
                                    ),
                                  ),
                                ),
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
          ),
        ),
      ),
    );
  }
}