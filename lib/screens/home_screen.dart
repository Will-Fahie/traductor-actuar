import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // A little helper to get the number of columns based on screen width
    int getCrossAxisCount(double width) {
      if (width < 600) return 2; // Mobile
      if (width < 1200) return 3; // Tablet
      return 4; // Desktop
    }
    
    // A little helper to get the aspect ratio based on screen width
    double getAspectRatio(double width) {
      if (width < 600) return 1.0; // Mobile
      if (width < 1200) return 1.2; // Tablet
      return 1.4; // Desktop
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Traductor Achuar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.count(
            crossAxisCount: getCrossAxisCount(constraints.maxWidth),
            childAspectRatio: getAspectRatio(constraints.maxWidth),
            padding: const EdgeInsets.all(16.0),
            mainAxisSpacing: 16.0,
            crossAxisSpacing: 16.0,
            children: [
              _buildGridItem(context, 'Diccionario', Icons.book, '/dictionary'),
              _buildGridItem(context, 'Envío de Frases', Icons.send, '/submit'),
              _buildGridItem(context, 'Traductor', Icons.translate, '/translator'),
              _build_grid_item(context, 'Recursos de Enseñanza', Icons.school, '/teaching_resources'),
              _build_grid_item(context, 'Recursos de Guía', Icons.map, '/guide_resources'),
              _build_grid_item(context, 'Recursos de Ecolodge', Icons.eco, '/ecolodge_resources'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String title, IconData icon, String routeName) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, routeName),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
