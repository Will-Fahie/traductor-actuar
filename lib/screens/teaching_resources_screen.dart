import 'package:flutter/material.dart';
import 'package:myapp/services/lesson_service.dart';
import 'package:myapp/models/vocabulary_item.dart';
import 'package:myapp/screens/level_screen.dart';

class TeachingResourcesScreen extends StatefulWidget {
  const TeachingResourcesScreen({super.key});

  @override
  _TeachingResourcesScreenState createState() => _TeachingResourcesScreenState();
}

class _TeachingResourcesScreenState extends State<TeachingResourcesScreen> {
  late Future<List<Level>> _levelsFuture;

  @override
  void initState() {
    super.initState();
    _levelsFuture = LessonService().loadLevels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recursos de Enseñanza'),
      ),
      body: FutureBuilder<List<Level>>(
        future: _levelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final levels = snapshot.data!;
            return ListView.builder(
              itemCount: levels.length,
              itemBuilder: (context, index) {
                final level = levels[index];
                return _buildLevelCard(context, level);
              },
            );
          } else {
            return const Center(child: Text('No se encontraron niveles.'));
          }
        },
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, Level level) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => LevelScreen(level: level)));
        },
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withAlpha(180)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                level.name,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Icon(Icons.arrow_forward_ios, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
