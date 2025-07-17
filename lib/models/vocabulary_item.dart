class VocabularyItem {
  final String achuar;
  final String english;
  final String spanish;
  final String audioPath;

  VocabularyItem({
    required this.achuar,
    required this.english,
    required this.spanish,
    required this.audioPath,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      achuar: json['achuar'] ?? '',
      english: json['english'] ?? '',
      spanish: json['spanish'] ?? '',
      audioPath: json['audioPath'] ?? '',
    );
  }
}
