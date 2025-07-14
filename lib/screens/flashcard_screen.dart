import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:myapp/data/numbers_data.dart';

class FlashcardScreen extends StatefulWidget {
  final String categoryName;
  const FlashcardScreen({super.key, required this.categoryName});

  @override
  _FlashcardScreenState createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late AudioPlayer _audioPlayer;
  int _currentIndex = 0;
  bool _isRevealed = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playAudio(String audioPath) async {
    try {
      await _audioPlayer.play(AssetSource(audioPath.replaceFirst('assets/', '')));
      print('Playback successful for: $audioPath');
    } catch (e) {
      print('Error playing audio: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play audio. Please check the file path.')),
      );
    }
  }

  void _nextCard() {
    if (_currentIndex < numbersData.length - 1) {
      setState(() {
        _currentIndex++;
        _isRevealed = false;
      });
    }
  }

  void _previousCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isRevealed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = numbersData[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Modo de Aprendizaje: ${widget.categoryName}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item.achuar,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            if (_isRevealed)
              Column(
                children: [
                  Text(
                    item.english,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => _playAudio(item.audioPath),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isRevealed = true;
                  });
                },
                child: const Text('Toca para revelar la traducción al inglés'),
              ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: _previousCard,
                  child: const Text('Anterior'),
                ),
                ElevatedButton(
                  onPressed: _nextCard,
                  child: const Text('Siguiente'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
