import 'package:flutter/material.dart';
import 'package:myapp/models/learning_question.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:myapp/services/lesson_service.dart';
import 'package:myapp/screens/lesson_screen.dart';
import 'package:myapp/screens/custom_lessons_screen.dart'; // Added import for CustomLessonsScreen
import 'package:myapp/services/tts_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class LearningModeScreen extends StatefulWidget {
  final List<LearningQuestion> questions;
  final Lesson lesson;
  const LearningModeScreen({super.key, required this.questions, required this.lesson});

  @override
  State<LearningModeScreen> createState() => _LearningModeScreenState();
}

class _LearningModeScreenState extends State<LearningModeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _answered = false;
  int? _selectedOptionIndex;
  String? _typedAnswer;
  final TextEditingController _textController = TextEditingController();
  // final AudioPlayer _audioPlayer = AudioPlayer(); // Removed
  late AnimationController _animationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // Store selected and available words for each sentence order question
  final Map<int, List<String>> _selectedWordsMap = {};
  final Map<int, List<String>> _availableWordsMap = {};
  final Map<int, bool> _sentenceOrderCorrectMap = {};

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _progressAnimationController = AnimationController(
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
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _animationController.forward();
    _progressAnimationController.forward();
  }

  @override
  void dispose() {
    // _audioPlayer.dispose(); // Removed
    _textController.dispose();
    _animationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  void _checkAnswer(dynamic answer) {
    setState(() {
      _answered = true;
      if (answer is int) {
        _selectedOptionIndex = answer;
      } else if (answer is String) {
        _typedAnswer = answer;
        // For sentence order, store correctness
        final qIndex = _currentIndex;
        final correctWords = widget.questions[qIndex].correctEntry.english.split(' ');
        final correctAnswer = correctWords.join(' ').trim().toLowerCase();
        _sentenceOrderCorrectMap[qIndex] = (answer.trim().toLowerCase() == correctAnswer);
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      _animationController.reset();
      _progressAnimationController.reset();
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOptionIndex = null;
        _typedAnswer = null;
        _textController.clear();
      });
      _animationController.forward();
      _progressAnimationController.forward();
    } else {
      // Instead of showing a dialog, navigate back to the appropriate screen with a left-to-right transition
      _finishAndNavigateBack();
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      _animationController.reset();
      setState(() {
        _currentIndex--;
        _answered = false;
        _selectedOptionIndex = null;
        _typedAnswer = null;
        _textController.clear();
      });
      _animationController.forward();
    }
  }

  void _finishAndNavigateBack() async {
    // Check if this is a custom lesson by comparing with built-in lessons
    final builtInLevels = await LessonService().loadLevels();
    final isCustomLesson = !builtInLevels.any((level) => level.lessons.any((l) => l.name == widget.lesson.name));
    if (isCustomLesson) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(_createBackRoute(const CustomLessonsScreen()));
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(_createBackRoute(CategoryDetailScreen(lesson: widget.lesson)));
    }
  }

  PageRouteBuilder _createBackRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(-1.0, 0.0); // Slide from left to right
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  Widget _buildQuestionWidget(LearningQuestion question) {
    switch (question.type) {
      case QuestionType.achuarToEnglish:
        return _buildMultipleChoice(
          question.correctEntry.achuar,
          question.options.map((o) => o.english).toList(),
          question.correctEntry.english,
        );
      case QuestionType.englishToAchuar:
        return _buildMultipleChoice(
          question.correctEntry.english,
          question.options.map((o) => o.achuar).toList(),
          question.correctEntry.achuar,
        );
      case QuestionType.typeEnglish:
        return _buildTextInput(
          question.correctEntry.achuar,
          question.correctEntry.english,
        );
      case QuestionType.audioToAchuar:
        return _buildAudioMultipleChoice(question);
      case QuestionType.sentenceOrder:
        return _buildSentenceOrder(question);
      default:
        return const Text('Error: Tipo de pregunta no válido');
    }
  }

  Widget _buildMultipleChoice(
    String prompt,
    List<String> options,
    String correctAnswer,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    bool isCorrect = _answered && options[_selectedOptionIndex!] == correctAnswer;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, _slideAnimation.value / 1000),
          end: Offset.zero,
        ).animate(_animationController),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFF6B5B95).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                prompt,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            ...options.asMap().entries.map((entry) {
              int idx = entry.key;
              String optionText = entry.value;
              bool isThisCorrect = optionText == correctAnswer;
              bool isSelected = _selectedOptionIndex == idx;
              Color buttonColor;
              Color textColor;
              IconData? icon;
              if (_answered) {
                if (isThisCorrect) {
                  buttonColor = Colors.green;
                  textColor = Colors.white;
                  icon = Icons.check_circle_rounded;
                } else if (isSelected) {
                  buttonColor = Colors.red;
                  textColor = Colors.white;
                  icon = Icons.cancel_rounded;
                } else {
                  buttonColor = isDarkMode
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey[200]!;
                  textColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
                }
              } else {
                buttonColor = isDarkMode
                    ? const Color(0xFF1E1E1E)
                    : Colors.white;
                textColor = isDarkMode ? Colors.white : Colors.black87;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  transform: Matrix4.identity()
                    ..scale(_answered && isSelected ? 0.98 : 1.0),
                  child: Material(
                    elevation: _answered ? 0 : (isDarkMode ? 2 : 4),
                    borderRadius: BorderRadius.circular(16),
                    color: buttonColor,
                    child: InkWell(
                      onTap: _answered ? null : () => _checkAnswer(idx),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 20,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (icon != null)
                              Icon(icon, color: textColor, size: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 40),
            if (_answered) ...[
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCorrect ? Colors.green : Colors.red,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCorrect
                                ? Icons.celebration_rounded
                                : Icons.lightbulb_rounded,
                            color: isCorrect ? Colors.green : Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isCorrect ? "¡Correcto!" : "¡Incorrecto!",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      if (!isCorrect) ...[
                        const SizedBox(height: 12),
                        Text(
                          "La respuesta correcta es:",
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          correctAnswer,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _nextQuestion,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  _currentIndex < widget.questions.length - 1
                      ? 'Siguiente'
                      : 'Finalizar',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF82B366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAudioMultipleChoice(LearningQuestion question) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String correctAnswer = question.correctEntry.achuar;
    List<String> options = question.options.map((o) => o.achuar).toList();
    bool isCorrect = _answered && options[_selectedOptionIndex!] == correctAnswer;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: () async {
                    // Add web check for audio playback
                    if (kIsWeb) {
                      // On web, directly use TTS service
                      await playEnglishTTS(question.correctEntry.english, context: context);
                      return;
                    }
                    
                    // Original mobile/desktop logic
                    final appDocDir = await getApplicationDocumentsDirectory();
                    final safeName = question.correctEntry.english.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                    final filePath = '${appDocDir.path}/offline_lesson_audio/$safeName.mp3';
                    final file = File(filePath);
                    if (await file.exists()) {
                      final player = AudioPlayer();
                      await player.play(DeviceFileSource(file.path));
                      return;
                    }
                    // Check connectivity before calling TTS
                    final connectivity = await Connectivity().checkConnectivity();
                    if (connectivity == ConnectivityResult.none) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sin conexión. Descargue el audio para usarlo sin conexión.')),
                        );
                      }
                      return;
                    }
                    // Fallback to TTS if online
                    await playEnglishTTS(question.correctEntry.english, context: context);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  "Escucha y selecciona la palabra correcta",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.blue.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // Add web check for audio playback
                  if (kIsWeb) {
                    // On web, directly use TTS service
                    await playEnglishTTS(question.correctEntry.english, context: context);
                    return;
                  }
                  
                  // Original mobile/desktop logic
                  final appDocDir = await getApplicationDocumentsDirectory();
                  final safeName = question.correctEntry.english.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                  final filePath = '${appDocDir.path}/offline_lesson_audio/$safeName.mp3';
                  final file = File(filePath);
                  if (await file.exists()) {
                    final player = AudioPlayer();
                    await player.play(DeviceFileSource(file.path));
                  } else {
                    await playEnglishTTS(question.correctEntry.english, context: context);
                  }
                },
                customBorder: const CircleBorder(),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          ...options.asMap().entries.map((entry) {
            int idx = entry.key;
            String optionText = entry.value;
            bool isThisCorrect = optionText == correctAnswer;
            bool isSelected = _selectedOptionIndex == idx;
            Color buttonColor;
            Color textColor;
            IconData? icon;
            if (_answered) {
              if (isThisCorrect) {
                buttonColor = Colors.green;
                textColor = Colors.white;
                icon = Icons.check_circle_rounded;
              } else if (isSelected) {
                buttonColor = Colors.red;
                textColor = Colors.white;
                icon = Icons.cancel_rounded;
              } else {
                buttonColor = isDarkMode
                    ? const Color(0xFF2C2C2C)
                    : Colors.grey[200]!;
                textColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
              }
            } else {
              buttonColor = isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.white;
              textColor = isDarkMode ? Colors.white : Colors.black87;
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Material(
                elevation: _answered ? 0 : (isDarkMode ? 2 : 4),
                borderRadius: BorderRadius.circular(16),
                color: buttonColor,
                child: InkWell(
                  onTap: _answered ? null : () => _checkAnswer(idx),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            optionText,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (icon != null)
                          Icon(icon, color: textColor, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 40),
          if (_answered) ...[
            _buildFeedback(isCorrect, correctAnswer, isDarkMode),
            const SizedBox(height: 24),
            _buildNextButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildTextInput(String prompt, String correctAnswer) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    bool isCorrect = _typedAnswer?.toLowerCase() == correctAnswer.toLowerCase();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFF88B0D3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.keyboard_rounded,
                  size: 48,
                  color: const Color(0xFF88B0D3),
                ),
                const SizedBox(height: 16),
                Text(
                  prompt,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          TextField(
            controller: _textController,
            enabled: !_answered,
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'Escribe la traducción aquí...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : Colors.white,
              contentPadding: const EdgeInsets.all(20),
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
                  color: Color(0xFF88B0D3),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (!_answered)
            ElevatedButton.icon(
              onPressed: () => _checkAnswer(_textController.text),
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'Enviar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF88B0D3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          const SizedBox(height: 40),
          if (_answered) ...[
            _buildFeedback(isCorrect, correctAnswer, isDarkMode),
            const SizedBox(height: 24),
            _buildNextButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildSentenceOrder(LearningQuestion question) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final correctWords = question.correctEntry.english.split(' ');
    final prompt = question.correctEntry.achuar;
    final qIndex = _currentIndex;

    // Initialize state if not already
    _selectedWordsMap.putIfAbsent(qIndex, () => []);
    _availableWordsMap.putIfAbsent(qIndex, () => List<String>.from(correctWords)..shuffle());

    final selectedWords = _selectedWordsMap[qIndex]!;
    final availableWords = _availableWordsMap[qIndex]!;
    final isCorrect = _sentenceOrderCorrectMap[qIndex] ?? false;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.sort_rounded,
                  size: 48,
                  color: Colors.purple[700],
                ),
                const SizedBox(height: 16),
                Text(
                  prompt,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ordena las palabras para formar la frase correcta',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Selected words area
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 80),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode
                    ? Colors.grey[800]!
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: selectedWords.isEmpty
                ? Center(
                    child: Text(
                      'Toca las palabras abajo para construir la frase',
                      style: TextStyle(
                        color: isDarkMode
                            ? Colors.grey[600]
                            : Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedWords.map((word) {
                      return Material(
                        elevation: 2,
                        borderRadius: BorderRadius.circular(12),
                        color: isDarkMode
                            ? const Color(0xFF2C2C2C)
                            : Colors.white,
                        child: InkWell(
                          onTap: _answered
                              ? null
                              : () {
                                  setState(() {
                                    selectedWords.remove(word);
                                  });
                                },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  word,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: isDarkMode
                                      ? Colors.grey[600]
                                      : Colors.grey[500],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          // Available words
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableWords
                .where((w) => !selectedWords.contains(w))
                .map((word) {
              return Material(
                elevation: isDarkMode ? 2 : 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.purple,
                child: InkWell(
                  onTap: _answered
                      ? null
                      : () {
                          setState(() {
                            selectedWords.add(word);
                          });
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Text(
                      word,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          if (!_answered && selectedWords.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedWords.clear();
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reiniciar'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                if (selectedWords.length == correctWords.length)
                  ElevatedButton.icon(
                    onPressed: () {
                      final userAnswer = selectedWords.join(' ').trim().toLowerCase();
                      _checkAnswer(userAnswer);
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Comprobar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
              ],
            ),
          if (_answered) ...[
            _buildFeedback(
              isCorrect,
              correctWords.join(' '),
              isDarkMode,
            ),
            const SizedBox(height: 24),
            _buildNextButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildFeedback(bool isCorrect, String correctAnswer, bool isDarkMode) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: (isCorrect ? Colors.green : Colors.red).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCorrect ? Colors.green : Colors.red,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCorrect
                      ? Icons.celebration_rounded
                      : Icons.lightbulb_rounded,
                  color: isCorrect ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  isCorrect ? "¡Correcto!" : "¡Incorrecto!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isCorrect ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            if (!isCorrect) ...[
              const SizedBox(height: 12),
              Text(
                "La respuesta correcta es:",
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                correctAnswer,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    return ElevatedButton.icon(
      onPressed: _nextQuestion,
      icon: const Icon(Icons.arrow_forward_rounded),
      label: Text(
        _currentIndex < widget.questions.length - 1
            ? 'Siguiente'
            : 'Finalizar',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF82B366),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final progress = (_currentIndex + 1) / widget.questions.length;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Modo de Aprendizaje',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF82B366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 16,
                      color: const Color(0xFF82B366),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_currentIndex + 1}/${widget.questions.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF82B366),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          AnimatedBuilder(
            animation: _progressAnimationController,
            builder: (context, child) {
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey[200],
                ),
                child: Stack(
                  children: [
                    FractionallySizedBox(
                      widthFactor: progress * _progressAnimationController.value,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF82B366),
                              const Color(0xFF62A346),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Question content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: _buildQuestionWidget(widget.questions[_currentIndex]),
              ),
            ),
          ),
          // Navigation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      onPressed: _currentIndex > 0 ? _previousQuestion : null,
                      color: _currentIndex > 0
                          ? (isDarkMode ? Colors.white : Colors.black87)
                          : Colors.grey[400],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pregunta ${_currentIndex + 1} de ${widget.questions.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 120,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF82B366),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      onPressed: _currentIndex < widget.questions.length - 1
                          ? _nextQuestion
                          : null,
                      color: _currentIndex < widget.questions.length - 1
                          ? (isDarkMode ? Colors.white : Colors.black87)
                          : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}