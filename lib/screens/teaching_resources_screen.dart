import 'package:flutter/material.dart';

class TeachingResourcesScreen extends StatelessWidget {
  const TeachingResourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recursos de Enseñanza'),
      ),
      body: ListView(
        children: [
          _buildLevelCard(context, 'Nivel 1', '/level1'),
          _buildLevelCard(context, 'Nivel 2', '/level2'),
          _buildLevelCard(context, 'Nivel 3', '/level3'),
        ],
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, String title, String routeName) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: ListTile(
        title: Text(title),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.pushNamed(context, routeName),
      ),
    );
  }
}
