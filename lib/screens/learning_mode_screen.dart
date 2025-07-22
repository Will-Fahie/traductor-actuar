import 'package:flutter/material.dart';
import 'package:myapp/models/learning_question.dart';
import 'package:audioplayers/audioplayers.dart';

class LearningModeScreen extends StatefulWidget {
  final List<LearningQuestion> questions;
  const LearningModeScreen({super.key, required this.questions});

  @override
  _LearningModeScreenState createState() => _LearningModeScreenState();
}

class _LearningModeScreenState extends State<LearningModeScreen> {
  int _currentIndex = 0;
  bool _answered = false;
  int? _selectedOptionIndex;
  String? _typedAnswer;
  final TextEditingController _textController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    _textController.dispose();
    super.dispose();
  }
  
  void _checkAnswer(dynamic answer) {
    setState(() {
      _answered = true;
      if (answer is int) {
        _selectedOptionIndex = answer;
      } else if (answer is String) {
        _typedAnswer = answer;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _answered = false;
        _selectedOptionIndex = null;
        _typedAnswer = null;
        _textController.clear();
      });
    }
  }

  void _previousQuestion() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _answered = false;
        _selectedOptionIndex = null;
        _typedAnswer = null;
        _textController.clear();
      });
    }
  }

  Widget _buildQuestionWidget(LearningQuestion question) {
    switch (question.type) {
      case QuestionType.achuarToEnglish:
        return _buildMultipleChoice(question.correctEntry.achuar, question.options.map((o) => o.english).toList(), question.correctEntry.english);
      case QuestionType.englishToAchuar:
        return _buildMultipleChoice(question.correctEntry.english, question.options.map((o) => o.achuar).toList(), question.correctEntry.achuar);
      case QuestionType.typeEnglish:
        return _buildTextInput(question.correctEntry.achuar, question.correctEntry.english);
      case QuestionType.audioToAchuar:
        return _buildAudioMultipleChoice(question);
      case QuestionType.sentenceOrder:
        return _buildSentenceOrder(question);
      default:
        return const Text('Error: Tipo de pregunta no válido');
    }
  }

  Widget _buildMultipleChoice(String prompt, List<String> options, String correctAnswer) {
    bool isCorrect = _answered && options[_selectedOptionIndex!] == correctAnswer;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        ...options.asMap().entries.map((entry) {
          int idx = entry.key;
          String optionText = entry.value;
          Color buttonColor = Colors.grey.shade300;
          Color textColor = Colors.black;

          if (_answered) {
            if (optionText == correctAnswer) {
              buttonColor = Colors.green;
              textColor = Colors.white;
            } else if (_selectedOptionIndex == idx) {
              buttonColor = Colors.red;
              textColor = Colors.white;
            }
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: _answered ? null : () => _checkAnswer(idx),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: textColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(optionText),
            ),
          );
        }),
        const SizedBox(height: 30),
        if(_answered) ...[
          Text(isCorrect ? "¡Correcto!" : "¡Incorrecto!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red,)),
          if(!isCorrect) Text("La respuesta correcta es: $correctAnswer", style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
           ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              child: const Text('Siguiente'),
            )
        ]
      ],
    );
  }
   
  Widget _buildAudioMultipleChoice(LearningQuestion question) {
    String correctAnswer = question.correctEntry.achuar;
    List<String> options = question.options.map((o) => o.achuar).toList();
    bool isCorrect = _answered && options[_selectedOptionIndex!] == correctAnswer;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Text("Escucha y selecciona la palabra correcta", style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center,),
        const SizedBox(height: 20),
        IconButton(
          icon: const Icon(Icons.volume_up, size: 60),
          onPressed: () async {
            await _audioPlayer.play(AssetSource(question.correctEntry.audioPath.replaceFirst('assets/', '')));
          },
        ),
        const SizedBox(height: 40),
        ...options.asMap().entries.map((entry) {
          int idx = entry.key;
          String optionText = entry.value;
          Color buttonColor = Colors.grey.shade300;
          Color textColor = Colors.black;

          if (_answered) {
            if (optionText == correctAnswer) {
              buttonColor = Colors.green;
              textColor = Colors.white;
            } else if (_selectedOptionIndex == idx) {
              buttonColor = Colors.red;
              textColor = Colors.white;
            }
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: _answered ? null : () => _checkAnswer(idx),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: textColor,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(optionText),
            ),
          );
        }),
        const SizedBox(height: 30),
        if(_answered) ...[
          Text(isCorrect ? "¡Correcto!" : "¡Incorrecto!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red,)),
          if(!isCorrect) Text("La respuesta correcta es: $correctAnswer", style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 20),
           ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              child: const Text('Siguiente'),
            )
        ]
      ],
    );
  }
  
  Widget _buildTextInput(String prompt, String correctAnswer) {
     bool isCorrect = _typedAnswer?.toLowerCase() == correctAnswer.toLowerCase();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(prompt, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
          controller: _textController,
          enabled: !_answered,
          decoration: InputDecoration(
            hintText: 'Escribe la traducción aquí...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _answered ? null : () => _checkAnswer(_textController.text),
           style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          child: const Text('Enviar'),
        ),
        const SizedBox(height: 30),
        if(_answered) ...[
           Text(isCorrect ? "¡Correcto!" : "¡Incorrecto!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red,)),
           if(!isCorrect) Text("La respuesta correcta es: $correctAnswer", style: const TextStyle(fontSize: 18)),
           const SizedBox(height: 20),
           ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              child: const Text('Siguiente'),
            )
        ]
      ],
    );
  }

  // Duolingo-style sentence ordering question
  Widget _buildSentenceOrder(LearningQuestion question) {
    final correctWords = question.correctEntry.english.split(' ');
    final prompt = question.correctEntry.achuar;
    // State for this question
    List<String> selectedWords = [];
    List<String> availableWords = List<String>.from(correctWords);
    bool isCorrect = false;

    return StatefulBuilder(
      builder: (context, setState) {
        isCorrect = _answered && selectedWords.join(' ') == correctWords.join(' ');
        // Auto-complete if correct order is entered
        if (!_answered && selectedWords.length == correctWords.length && selectedWords.join(' ') == correctWords.join(' ')) {
          Future.microtask(() => setState(() { _answered = true; }));
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(prompt, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Toca las palabras en inglés en el orden correcto para formar la frase. Si te equivocas, toca una palabra en la frase para devolverla arriba.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableWords.where((w) => !selectedWords.contains(w)).map((word) => ElevatedButton(
                onPressed: _answered ? null : () {
                  setState(() { selectedWords.add(word); });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(word, style: const TextStyle(fontSize: 16)),
              )).toList(),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedWords.map((word) => OutlinedButton(
                onPressed: _answered ? null : () {
                  setState(() { selectedWords.remove(word); });
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blueGrey),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(word, style: const TextStyle(fontSize: 16)),
              )).toList(),
            ),
            const SizedBox(height: 24),
            if (!_answered) ...[
              TextButton(
                onPressed: _nextQuestion,
                child: const Text('Saltar', style: TextStyle(fontSize: 16)),
              ),
            ],
            const SizedBox(height: 30),
            if (_answered) ...[
              Text(isCorrect ? "¡Correcto!" : "¡Incorrecto!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.red,)),
              if (!isCorrect) Text("La respuesta correcta es: ${correctWords.join(' ')}", style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                child: const Text('Siguiente'),
              )
            ]
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo de Aprendizaje'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: _buildQuestionWidget(widget.questions[_currentIndex]),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: _previousQuestion,),
            Text('${_currentIndex + 1} / ${widget.questions.length}', style: const TextStyle(fontWeight: FontWeight.bold),),
            IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: _nextQuestion,),
          ],
        ),
      ),
    );
  }
}
