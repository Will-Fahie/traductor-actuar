import 'package:flutter/material.dart';

class Level1Screen extends StatelessWidget {
  const Level1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nivel 1'),
      ),
      body: ListView(
        children: [
          _buildCategoryCard(context, 'Números 1-10', '/numbers'),
          _buildCategoryCard(context, 'Animales Básicos', '/animals'),
          _buildCategoryCard(context, 'Frases Básicas', '/phrases'),
          _buildCategoryCard(context, 'Colores', '/colors'),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, String routeName) {
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
