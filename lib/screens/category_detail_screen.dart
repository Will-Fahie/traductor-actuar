import 'dart:math';
import 'package:flutter/material.dart';
import 'package:myapp/models/learning_question.dart';
import 'package:myapp/models/vocabulary_item.dart';
import 'package:myapp/screens/learning_mode_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:myapp/services/lesson_service.dart';

class CategoryDetailScreen extends StatefulWidget {
  final Lesson lesson;
  const CategoryDetailScreen({super.key, required this.lesson});

  @override
  _CategoryDetailScreenState createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  List<LearningQuestion>? _learningSession;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  void _playAudio(String path) async {
    try {
      await _audioPlayer.play(AssetSource(path.replaceFirst('assets/', '')));
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Could not play audio: $e")));
    }
  }

  void _startNewLearningSession() {
    final random = Random();
    final shuffledData = List<VocabularyItem>.from(widget.lesson.entries)..shuffle();

    final session = shuffledData.map((entry) {
      final isMultiWord = entry.english.trim().split(' ').length > 1;
      List<QuestionType> allowedTypes = [
        QuestionType.achuarToEnglish,
        QuestionType.englishToAchuar,
        QuestionType.typeEnglish,
        QuestionType.audioToAchuar,
      ];
      if (isMultiWord) {
        // For multi-word entries, randomly pick from all types (including sentenceOrder)
        allowedTypes.add(QuestionType.sentenceOrder);
      }
      // For single-word entries, sentenceOrder is not included
      final questionType = allowedTypes[random.nextInt(allowedTypes.length)];
      if (questionType == QuestionType.sentenceOrder) {
        return LearningQuestion(
          correctEntry: entry,
          type: QuestionType.sentenceOrder,
          options: [],
        );
      }
      List<VocabularyItem> options = [];
      if (questionType == QuestionType.achuarToEnglish || questionType == QuestionType.englishToAchuar || questionType == QuestionType.audioToAchuar) {
        options.add(entry);
        final otherOptions = List<VocabularyItem>.from(widget.lesson.entries)..remove(entry);
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
        builder: (context) => CategoryDetailScreen(lesson: widget.lesson),
      ),
    );
  }
  
  void _resumeLearningSession() {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(lesson: widget.lesson),
      ),
    );
  }

  void _showStartOrResumeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modo de Aprendizaje'),
        content: const Text('¿Desea reanudar la sesión anterior o comenzar una nueva?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeLearningSession();
            },
            child: const Text('Reanudar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewLearningSession();
            },
            child: const Text('Comenzar de Nuevo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.name),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.style, size: 32),
              label: const Text('Iniciar Modo de Aprendizaje'),
              onPressed: () {
                if (_learningSession != null) {
                  _showStartOrResumeDialog();
                } else {
                  _startNewLearningSession();
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                minimumSize: const Size(double.infinity, 70),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: widget.lesson.entries.length,
              itemBuilder: (context, index) {
                final item = widget.lesson.entries[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ListTile(
                    title: Text(item.achuar),
                    subtitle: Text(item.english),
                    trailing: IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => _playAudio(item.audioPath),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
