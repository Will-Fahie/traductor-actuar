import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class DictionaryEntry {
  final String achuar;
  final String english;
  final String spanish;
  final String typeOfWord;

  DictionaryEntry({
    required this.achuar,
    required this.english,
    required this.spanish,
    required this.typeOfWord,
  });

  factory DictionaryEntry.fromJson(Map<String, dynamic> json) {
    return DictionaryEntry(
      achuar: json['achuar_translation'] ?? '',
      english: json['english_translation'] ?? '',
      spanish: json['spanish_translation'] ?? '',
      typeOfWord: json['type_of_word'] ?? '',
    );
  }
}

class DictionaryService {
  Future<List<DictionaryEntry>> loadEntries() async {
    final String response = await rootBundle.loadString('dictionary.json');
    final data = await json.decode(response) as List;
    return data.map((i) => DictionaryEntry.fromJson(i)).toList();
  }
}
