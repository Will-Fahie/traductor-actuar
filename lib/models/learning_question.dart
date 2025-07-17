import 'package:myapp/models/vocabulary_item.dart';

enum QuestionType {
  achuarToEnglish,
  englishToAchuar,
  typeEnglish,
  audioToAchuar,
}

class LearningQuestion {
  final VocabularyItem correctEntry;
  final QuestionType type;
  final List<VocabularyItem> options; // For multiple choice

  LearningQuestion({
    required this.correctEntry,
    required this.type,
    this.options = const [],
  });
}
