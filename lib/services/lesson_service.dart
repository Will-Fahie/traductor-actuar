import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:achuar_ingis/models/vocabulary_item.dart';

class Lesson {
  final String name;
  final List<VocabularyItem> entries;

  Lesson({required this.name, required this.entries});

  factory Lesson.fromJson(Map<String, dynamic> json) {
    var entriesList = json['entries'] as List;
    List<VocabularyItem> vocabularyEntries = entriesList.map((i) => VocabularyItem.fromJson(i)).toList();
    return Lesson(
      name: json['name'],
      entries: vocabularyEntries,
    );
  }
}

class Level {
  final String name;
  final List<Lesson> lessons;

  Level({required this.name, required this.lessons});

  factory Level.fromJson(Map<String, dynamic> json) {
    var lessonsList = json['lessons'] as List;
    List<Lesson> lessons = lessonsList.map((i) => Lesson.fromJson(i)).toList();
    return Level(
      name: json['name'],
      lessons: lessons,
    );
  }
}

class LessonService {
  Future<List<Level>> loadLevels() async {
    final String response = await rootBundle.loadString('lessons.json');
    final data = await json.decode(response);
    var levelsList = data['levels'] as List;
    return levelsList.map((i) => Level.fromJson(i)).toList();
  }
}
