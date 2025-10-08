import 'dart:math';
import 'package:flutter/material.dart';
import 'package:achuar_ingis/models/learning_question.dart';
import 'package:achuar_ingis/models/vocabulary_item.dart';
import 'package:achuar_ingis/screens/learning_mode_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:achuar_ingis/services/lesson_service.dart';
import 'package:achuar_ingis/screens/create_custom_lesson_screen.dart';
import 'package:achuar_ingis/services/tts_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:achuar_ingis/l10n/app_localizations.dart';

class CategoryDetailScreen extends StatefulWidget {
  final Lesson lesson;
  const CategoryDetailScreen({super.key, required this.lesson});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen>
    with SingleTickerProviderStateMixin {
  List<LearningQuestion>? _learningSession;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  int? _playingIndex;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _playAudio(String path, int index) async {
    if (!mounted) return;
    setState(() {
      _playingIndex = index;
    });
    
    try {
      await _audioPlayer.play(AssetSource(path.replaceFirst('assets/', '')));
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text("${AppLocalizations.of(context)?.couldNotPlayAudioError ?? 'Could not play audio'}: $e")),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _playingIndex = null;
      });
    }
  }

  void _startNewLearningSession() async {
    final random = Random();
    final shuffledData = List<VocabularyItem>.from(widget.lesson.entries)..shuffle();
    
    // Check if lesson has been downloaded for offline use
    final prefs = await SharedPreferences.getInstance();
    final lessonDownloaded = prefs.getBool('offline_lesson_${widget.lesson.name}_downloaded') ?? false;
    final customLessonDownloaded = prefs.getBool('offline_custom_lesson_${widget.lesson.name}_downloaded') ?? false;
    final isDownloaded = lessonDownloaded || customLessonDownloaded;
    
    print('[LearningMode] Lesson "${widget.lesson.name}" downloaded: $isDownloaded');
    
    final session = shuffledData.map((entry) {
      final isMultiWord = entry.english.trim().split(' ').length > 1;
      
      List<QuestionType> allowedTypes = [
        QuestionType.achuarToEnglish,
        QuestionType.englishToAchuar,
        QuestionType.typeEnglish,
      ];
      
      // Only include audio questions if lesson has been downloaded
      if (isDownloaded) {
        allowedTypes.add(QuestionType.audioToAchuar);
      }
      
      if (isMultiWord) {
        allowedTypes.add(QuestionType.sentenceOrder);
      }
      
      final questionType = allowedTypes[random.nextInt(allowedTypes.length)];
      
      if (questionType == QuestionType.sentenceOrder) {
        return LearningQuestion(
          correctEntry: entry,
          type: QuestionType.sentenceOrder,
          options: [],
        );
      }
      
      List<VocabularyItem> options = [];
      if (questionType == QuestionType.achuarToEnglish ||
          questionType == QuestionType.englishToAchuar ||
          questionType == QuestionType.audioToAchuar) {
        options.add(entry);
        final otherOptions = List<VocabularyItem>.from(widget.lesson.entries)
          ..remove(entry);
        otherOptions.shuffle();
        options.addAll(otherOptions.take(2));
        options.shuffle();
      }
      
      return LearningQuestion(
        correctEntry: entry,
        type: questionType,
        options: options,
      );
    }).toList();
    
    session.shuffle();
    
    setState(() {
      _learningSession = session;
    });
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningModeScreen(
          questions: _learningSession!,
          lesson: widget.lesson,
        ),
      ),
    );
  }

  void _resumeLearningSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningModeScreen(
          questions: _learningSession!,
          lesson: widget.lesson,
        ),
      ),
    );
  }

  void _showStartOrResumeDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF82B366).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 32,
                  color: Color(0xFF82B366),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)?.learningMode ?? 'Modo de Aprendizaje',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)?.resumeOrStartNew ?? '¿Desea reanudar la sesión anterior o comenzar una nueva?',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _resumeLearningSession();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.resume ?? 'Reanudar',
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
                      onPressed: () {
                        Navigator.pop(context);
                        _startNewLearningSession();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF82B366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLocalizations.of(context)?.newSession ?? 'Nueva Sesión',
                        style: const TextStyle(
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
  }

  List<VocabularyItem> get filteredEntries {
    if (_searchQuery.isEmpty) {
      return widget.lesson.entries;
    }
    
    return widget.lesson.entries.where((item) {
      final query = _searchQuery.toLowerCase();
      return item.achuar.toLowerCase().contains(query) ||
          item.english.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final filteredItems = filteredEntries;

    return FutureBuilder<List<Level>>(
      future: LessonService().loadLevels(),
      builder: (context, snapshot) {
        final builtInLevels = snapshot.data ?? [];
        final isCustomLesson = !builtInLevels.any((level) => level.lessons.any((l) => l.name == widget.lesson.name));
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 8, right: 8, bottom: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (isCustomLesson)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.edit, color: Colors.white),
                            label: Text(AppLocalizations.of(context)?.edit ?? 'Editar', style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              elevation: 0,
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateCustomLessonScreen(
                                    lessonName: widget.lesson.name,
                                    initialData: {
                                      'name': widget.lesson.name,
                                      'entries': widget.lesson.entries.map((e) => {
                                        'achuar': e.achuar,
                                        'english': e.english,
                                        'spanish': e.spanish,
                                      }).toList(),
                                    },
                                  ),
                                ),
                              );
                              
                              // If the lesson was updated, refresh the data
                              if (result != null && result['success'] == true && result['lessonData'] != null) {
                                final updatedData = result['lessonData'] as Map<String, dynamic>;
                                final updatedEntries = (updatedData['entries'] as List).map((e) => 
                                  VocabularyItem(
                                    achuar: e['achuar'] ?? '',
                                    english: e['english'] ?? '',
                                    spanish: e['spanish'] ?? '',
                                    audioPath: '', // Custom lessons don't have audio initially
                                  )
                                ).toList();
                                
                                setState(() {
                                  widget.lesson.entries.clear();
                                  widget.lesson.entries.addAll(updatedEntries);
                                });
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                // Learning Mode Button and Search
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Learning Mode Button
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF82B366),
                                  const Color(0xFF62A346),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF82B366).withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (_learningSession != null) {
                                    _showStartOrResumeDialog();
                                  } else {
                                    _startNewLearningSession();
                                  }
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20.0,
                                    horizontal: 24.0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.school_rounded,
                                          size: 28,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              AppLocalizations.of(context)?.startLearningMode ?? 'Iniciar Modo de Aprendizaje',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _learningSession != null
                                                  ? (AppLocalizations.of(context)?.continueYourProgress ?? 'Continua tu progreso')
                                                  : (AppLocalizations.of(context)?.practiceInteractive ?? 'Practica con ejercicios interactivos'),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.white.withOpacity(0.9),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Search Bar
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)?.searchInLesson ?? 'Buscar palabras...',
                            hintStyle: TextStyle(
                              color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? const Color(0xFF1E1E1E)
                                : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFF82B366),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_searchQuery.isNotEmpty)
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${filteredItems.length} resultados encontrados',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                // Vocabulary List
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: filteredItems.isEmpty
                      ? SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 64,
                                    color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No se encontraron palabras',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = filteredItems[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _buildVocabularyCard(
                                  item,
                                  index,
                                  isDarkMode,
                                ),
                              );
                            },
                            childCount: filteredItems.length,
                          ),
                        ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVocabularyCard(
    VocabularyItem item,
    int index,
    bool isDarkMode,
  ) {
    final isPlaying = _playingIndex == index;
    return Material(
      elevation: isDarkMode ? 2 : 4,
      borderRadius: BorderRadius.circular(16),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Achuar text with label
                    const Text(
                      'Achuar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B5B95),
                        letterSpacing: 0.2,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.achuar,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // English translation with label
                    const Text(
                      'English',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B5B95),
                        letterSpacing: 0.2,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.english,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? const Color.fromARGB(255, 255, 255, 255) : const Color.fromARGB(221, 0, 0, 0),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Audio button
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPlaying
                        ? [
                            const Color(0xFF82B366),
                            const Color(0xFF62A346),
                          ]
                        : [
                            const Color(0xFF82B366).withOpacity(0.1),
                            const Color(0xFF62A346).withOpacity(0.1),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                    color: isPlaying
                        ? Colors.white
                        : (isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  onPressed: () async {
                    // Add web check before accessing file system
                    if (kIsWeb) {
                      // On web, directly use TTS service
                      await playEnglishTTS(item.english, context: context);
                      return;
                    }
                    
                    // Original mobile/desktop logic
                    final appDocDir = await getApplicationDocumentsDirectory();
                    final safeName = item.english.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                    final filePath = '${appDocDir.path}/offline_lesson_audio/${safeName}.mp3';
                    final file = File(filePath);
                    final connectivity = await Connectivity().checkConnectivity();
                    final isOffline = connectivity == ConnectivityResult.none;
                    
                    print('Checking for audio file: $filePath');
                    if (await file.exists()) {
                      try {
                        final player = AudioPlayer();
                        await player.play(DeviceFileSource(file.path));
                      } catch (e) {
                        print('[AUDIO] Error playing local audio file: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      AppLocalizations.of(context)?.redownloadLessonMessage ?? 'Could not play audio. Re-download the lesson when online to update the audio.',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orange[700],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      }
                    } else if (isOffline) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)?.audioNotAvailableOffline ?? 'Audio no disponible sin conexión. Descargue la lección cuando esté en línea para guardar el audio para uso offline.',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.blue[700],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    } else {
                      await playEnglishTTS(item.english, context: context);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}