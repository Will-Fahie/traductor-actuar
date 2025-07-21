import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/screens/category_detail_screen.dart';
import 'package:myapp/models/vocabulary_item.dart';
import 'package:myapp/models/learning_question.dart';
import 'package:myapp/services/lesson_service.dart';
import 'package:myapp/screens/create_custom_lesson_screen.dart';
import 'dart:convert';

class CustomLessonsScreen extends StatefulWidget {
  const CustomLessonsScreen({super.key});

  @override
  State<CustomLessonsScreen> createState() => _CustomLessonsScreenState();
}

class _CustomLessonsScreenState extends State<CustomLessonsScreen> {
  String? _username;
  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lecciones personalizadas'),
      ),
      body: _username == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('custom_lessons')
                  .where('username', isEqualTo: _username)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No tienes lecciones personalizadas aún.'));
                }
                final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final lessonName = data['name'] ?? docs[index].id;
                    final color = lessonColors[index % lessonColors.length];
                    final phraseCount = (data['entries'] as List?)?.length ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Material(
                        elevation: isDarkMode ? 2 : 4,
                        borderRadius: BorderRadius.circular(16),
                        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                        shadowColor: Colors.black.withOpacity(0.1),
                        child: InkWell(
                          onTap: () {
                            // Open lesson in learning mode
                            final entries = (data['entries'] as List).map((e) => VocabularyItem(
                              achuar: e['achuar'] ?? '',
                              english: e['english'] ?? '',
                              spanish: e['spanish'] ?? '',
                              audioPath: '',
                            )).toList();
                            final lesson = Lesson(
                              name: lessonName,
                              entries: entries,
                            );
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
                                // Badge with lesson number
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
                                      '${index + 1}',
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
                                        lessonName,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Frases: $phraseCount',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Edit and delete buttons
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                                      tooltip: 'Editar',
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CreateCustomLessonScreen(
                                              lessonName: lessonName,
                                              initialData: data,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Eliminar',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Eliminar lección'),
                                            content: Text('¿Estás seguro de que deseas eliminar la lección "$lessonName"? Esta acción no se puede deshacer.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancelar'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await FirebaseFirestore.instance.collection('custom_lessons').doc(docs[index].id).delete();
                                          final prefs = await SharedPreferences.getInstance();
                                          final key = 'offline_custom_lessons_${_username}';
                                          if (prefs.containsKey(key)) {
                                            final customJson = prefs.getString(key)!;
                                            final customList = List<Map<String, dynamic>>.from(json.decode(customJson));
                                            customList.removeWhere((e) => (e['name'] ?? docs[index].id) == lessonName);
                                            await prefs.setString(key, json.encode(customList));
                                          }
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lección eliminada.')));
                                        }
                                      },
                                    ),
                                  ],
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
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/create_custom_lesson');
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva lección'),
      ),
    );
  }
} 