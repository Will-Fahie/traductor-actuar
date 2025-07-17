import 'package:flutter/material.dart';
import 'package:myapp/models/vocabulary_item.dart';
import 'package:myapp/services/lesson_service.dart';
import 'package:myapp/screens/category_detail_screen.dart';

class LevelScreen extends StatelessWidget {
  final Level level;
  const LevelScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(level.name),
      ),
      body: ListView.builder(
        itemCount: level.lessons.length,
        itemBuilder: (context, index) {
          final lesson = level.lessons[index];
          return _buildCategoryCard(context, lesson.name, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => CategoryDetailScreen(lesson: lesson)));
          });
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}
