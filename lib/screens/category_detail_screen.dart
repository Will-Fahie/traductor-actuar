import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:myapp/data/numbers_data.dart';
import 'package:myapp/screens/flashcard_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  _CategoryDetailScreenState createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late AudioPlayer _audioPlayer;

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
      // The path in pubspec.yaml is assets/audio/level_1/numbers/
      // The audioPath is like 'assets/audio/level_1/numbers/1.mp3'
      // AssetSource expects the path *relative* to the assets directory.
      await _audioPlayer.play(AssetSource(audioPath.replaceFirst('assets/', '')));
      print('Playback successful for: $audioPath');
    } catch (e) {
      print('Error playing audio: $e');
      // Optionally, show a snackbar or dialog to the user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play audio. Please check the file path.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.style),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FlashcardScreen(categoryName: widget.categoryName),
                ),
              );
            },
            tooltip: 'Modo de Aprendizaje',
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: numbersData.length,
        itemBuilder: (context, index) {
          final item = numbersData[index];
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
    );
  }
}
