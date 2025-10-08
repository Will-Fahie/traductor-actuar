import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:achuar_ingis/screens/lesson_screen.dart';
import 'package:achuar_ingis/models/vocabulary_item.dart';
import 'package:achuar_ingis/services/lesson_service.dart';
import 'package:achuar_ingis/screens/create_custom_lesson_screen.dart';
import 'package:achuar_ingis/services/tts_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:achuar_ingis/l10n/app_localizations.dart';

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
    final wasOffline = !_isConnected;
    setState(() {
      _isConnected = !connectivityResult.contains(ConnectivityResult.none);
    });
    
    // Sync pending changes if coming online
    if (_isConnected && wasOffline) {
      await _syncPendingChanges();
    }
    
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (mounted) {
        final wasOfflineBefore = !_isConnected;
        final isOnlineNow = !result.contains(ConnectivityResult.none);
        
        setState(() {
          _isConnected = isOnlineNow;
        });
        
        // Sync when coming back online
        if (isOnlineNow && wasOfflineBefore) {
          print('[CustomLessons] Connectivity restored, syncing pending changes...');
          await _syncPendingChanges();
        }
        
        // Refresh data when connectivity changes
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncPendingChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get pending deletions
      final pendingDeletes = prefs.getStringList('pending_custom_lesson_deletes') ?? [];
      print('[CustomLessons] Syncing ${pendingDeletes.length} pending deletions');
      
      // Delete from Firestore
      for (final docId in pendingDeletes) {
        try {
          await FirebaseFirestore.instance
              .collection('custom_lessons')
              .doc(docId)
              .delete();
          print('[CustomLessons] Synced deletion of $docId');
        } catch (e) {
          print('[CustomLessons] Error syncing deletion of $docId: $e');
        }
      }
      
      // Clear pending deletions
      await prefs.remove('pending_custom_lesson_deletes');
      
      // Get pending edits (lessons in local storage that need syncing)
      final pendingEdits = prefs.getStringList('pending_custom_lesson_edits') ?? [];
      print('[CustomLessons] Syncing ${pendingEdits.length} pending edits');
      
      final localLessons = await _loadLessonsFromLocal();
      
      for (final docId in pendingEdits) {
        try {
          // Find the lesson in local storage
          final lesson = localLessons.firstWhere(
            (l) => l['id'] == docId,
            orElse: () => {},
          );
          
          if (lesson.isNotEmpty) {
            // Remove the 'id' field before saving to Firestore
            final lessonData = Map<String, dynamic>.from(lesson);
            lessonData.remove('id');
            
            await FirebaseFirestore.instance
                .collection('custom_lessons')
                .doc(docId)
                .set(lessonData);
            print('[CustomLessons] Synced edit of $docId');
          }
        } catch (e) {
          print('[CustomLessons] Error syncing edit of $docId: $e');
        }
      }
      
      // Clear pending edits
      await prefs.remove('pending_custom_lesson_edits');
      
      print('[CustomLessons] Sync completed');
    } catch (e) {
      print('[CustomLessons] Error syncing pending changes: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadCustomLessons() async {
    try {
      // Try to load from Firestore first if online
      if (_isConnected) {
        try {
          // Sync any pending changes first
          await _syncPendingChanges();
          
          final query = await FirebaseFirestore.instance
              .collection('custom_lessons')
              .where('username', isEqualTo: _username)
              .get();
          
          final lessons = query.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          
          // Save to local storage for offline access
          await _saveLessonsLocally(lessons);
          
          return lessons;
        } catch (e) {
          print('[CustomLessons] Error loading from Firestore: $e');
          // Fall back to local storage
        }
      }
      
      // Load from local storage
      return await _loadLessonsFromLocal();
    } catch (e) {
      print('[CustomLessons] Error loading lessons: $e');
      return [];
    }
  }

  Future<void> _saveLessonsLocally(List<Map<String, dynamic>> lessons) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lessonsJson = lessons.map((lesson) => jsonEncode(lesson)).toList();
      await prefs.setStringList('local_custom_lessons', lessonsJson);
      print('[CustomLessons] Saved ${lessons.length} lessons locally');
    } catch (e) {
      print('[CustomLessons] Error saving lessons locally: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _loadLessonsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lessonsJson = prefs.getStringList('local_custom_lessons') ?? [];
      
      final lessons = lessonsJson
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      
      print('[CustomLessons] Loaded ${lessons.length} lessons from local storage');
      return lessons;
    } catch (e) {
      print('[CustomLessons] Error loading from local storage: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.customLessons ?? 'Lecciones personalizadas',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: _username == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadCustomLessons(),
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
                
                final lessons = snapshot.data ?? [];
                
                if (lessons.isEmpty) {
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
                          AppLocalizations.of(context)?.noCustomLessons ?? 'No tienes lecciones personalizadas',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)?.createFirstLesson ?? 'Crea tu primera lección personalizada',
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
                  itemCount: lessons.length,
                  itemBuilder: (context, index) {
                    final data = lessons[index];
                    final lessonName = data['name'] ?? data['id'] ?? 'Unknown Lesson';
                    final docId = data['id'] ?? 'unknown_id';
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
                                                  '$phraseCount ${AppLocalizations.of(context)?.phrases ?? 'frases'}',
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
                                          onTap: () async {
                                            try {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CreateCustomLessonScreen(
                                                    lessonName: lessonName,
                                                    initialData: data,
                                                  ),
                                                ),
                                              );
                                              
                                              // If the lesson was updated, refresh the list
                                              if (result != null && result['success'] == true) {
                                                setState(() {
                                                  // Trigger a rebuild to refresh the lesson list
                                                });
                                              }
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${AppLocalizations.of(context)?.errorOpeningEditor ?? 'Error opening editor'}: $e'),
                                                  backgroundColor: Colors.red,
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
                                                Icon(
                                                  Icons.edit_rounded,
                                                  size: 18,
                                                  color: Colors.blue[600],
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  AppLocalizations.of(context)?.edit ?? 'Editar',
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
                                    // Download button - Only show on mobile/desktop
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
                                                          SnackBar(
                                                            content: Text(AppLocalizations.of(context)?.noEnglishPhrasesToDownload ?? 'No English phrases to download in this lesson.'),
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
                                                                '${paths.length} ${AppLocalizations.of(context)?.audioFilesDownloaded ?? 'archivos de audio descargados'}',
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
                                                              Text(
                                                                AppLocalizations.of(context)?.errorDownloadingAudio ?? 'Error al descargar audio',
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
                                                    isDownloaded 
                                                      ? (AppLocalizations.of(context)?.downloaded ?? 'Descargado')
                                                      : (AppLocalizations.of(context)?.download ?? 'Descargar'),
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
                                    // Only add divider if download button is shown
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
                                                  AppLocalizations.of(context)?.delete ?? 'Delete',
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
          try {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateCustomLessonScreen(),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${AppLocalizations.of(context)?.errorOpeningLessonCreator ?? 'Error opening lesson creator'}: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        backgroundColor: const Color(0xFF82B366),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          AppLocalizations.of(context)?.newLesson ?? 'Nueva lección',
          style: const TextStyle(fontWeight: FontWeight.w600),
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
              Text(
                AppLocalizations.of(context)?.deleteLessonTitle ?? 'Delete lesson',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${AppLocalizations.of(context)?.deleteLessonConfirmation ?? 'Are you sure you want to delete the lesson'} "$lessonName"? ${AppLocalizations.of(context)?.actionCannotBeUndone ?? 'This action cannot be undone.'}',
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
                      child: Text(
                        AppLocalizations.of(context)?.cancel ?? 'Cancel',
                        style: const TextStyle(
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
                      child: Text(
                        AppLocalizations.of(context)?.delete ?? 'Delete',
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
      try {
        // Delete from local storage first (always works offline)
        final prefs = await SharedPreferences.getInstance();
        
        // Remove from local_custom_lessons
        final localLessons = await _loadLessonsFromLocal();
        localLessons.removeWhere((lesson) => lesson['id'] == docId || lesson['name'] == lessonName);
        await _saveLessonsLocally(localLessons);
        
        // Remove downloaded audio state
        await prefs.remove('offline_custom_lesson_${lessonName}_downloaded');
        _downloadedLessons.remove(lessonName);
        
        // Also remove from old storage format if exists
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
        
        // Try to delete from Firestore if online, otherwise add to pending
        if (_isConnected) {
          try {
            await FirebaseFirestore.instance
              .collection('custom_lessons')
              .doc(docId)
              .delete();
            print('[CustomLessons] Deleted from Firestore: $docId');
          } catch (e) {
            print('[CustomLessons] Error deleting from Firestore: $e');
            // Add to pending deletions
            final pendingDeletes = prefs.getStringList('pending_custom_lesson_deletes') ?? [];
            if (!pendingDeletes.contains(docId)) {
              pendingDeletes.add(docId);
              await prefs.setStringList('pending_custom_lesson_deletes', pendingDeletes);
            }
          }
        } else {
          // Offline - add to pending deletions
          print('[CustomLessons] Offline - adding to pending deletions: $docId');
          final pendingDeletes = prefs.getStringList('pending_custom_lesson_deletes') ?? [];
          if (!pendingDeletes.contains(docId)) {
            pendingDeletes.add(docId);
            await prefs.setStringList('pending_custom_lesson_deletes', pendingDeletes);
          }
        }
        
        // Refresh the UI
        if (mounted) {
          setState(() {});
          
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(l10n?.lessonDeleted ?? 'Lesson deleted'),
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
        print('[CustomLessons] Error deleting lesson: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Error: $e'),
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
    }
  }
}