
import 'package:flutter/material.dart';
import 'package:myapp/screens/guide_resources_screen.dart';
import 'package:myapp/screens/main_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Traductor Achuar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildGridItem(context, 'Diccionario', Icons.book, () {}),
            _buildGridItem(context, 'Envío de Frases', Icons.send, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MainScreen()),
              );
            }),
            _buildGridItem(context, 'Traductor', Icons.translate, () {}),
            _buildGridItem(context, 'Recursos de Enseñanza', Icons.school, () {}),
            _buildGridItem(context, 'Recursos de Guía', Icons.map, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GuideResourcesScreen()),
              );
            }),
            _buildGridItem(context, 'Recursos de Ecolodge', Icons.eco, () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
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
