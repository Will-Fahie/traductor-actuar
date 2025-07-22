import 'package:flutter/material.dart';
import 'package:myapp/models/vocabulary_item.dart';
import 'package:myapp/services/lesson_service.dart';
import 'package:myapp/screens/lesson_screen.dart';

class LevelScreen extends StatelessWidget {
  final Level level;
  
  const LevelScreen({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          level.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // (Header section removed as requested)
          const SizedBox(height: 8),
          // Lessons list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: level.lessons.length,
              itemBuilder: (context, index) {
                final lesson = level.lessons[index];
                final lessonNumber = index + 1;
                
                // Define colors for different lessons
                final lessonColors = [
                  const Color(0xFF6B5B95), // Purple
                  const Color(0xFF88B0D3), // Blue
                  const Color(0xFF82B366), // Green
                  const Color(0xFFFA6900), // Orange
                  const Color(0xFFF38630), // Light Orange
                  const Color(0xFF69D2E7), // Cyan
                  const Color(0xFFE94B3C), // Red
                  const Color(0xFF00A86B), // Jade
                ];
                
                final color = lessonColors[index % lessonColors.length];
                
                return _buildLessonCard(
                  context,
                  lesson: lesson,
                  lessonNumber: lessonNumber,
                  color: color,
                  isDarkMode: isDarkMode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(
    BuildContext context, {
    required Lesson lesson,
    required int lessonNumber,
    required Color color,
    required bool isDarkMode,
  }) {
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryDetailScreen(lesson: lesson),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Lesson number badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.8),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$lessonNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Lesson details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}