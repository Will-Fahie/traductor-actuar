import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class GuideCategoriesScreen extends StatelessWidget {
  const GuideCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recursos de Guía'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildCategoryCard(
            context,
            'Aves',
            Icons.flutter_dash, 
            () {
              Navigator.pushNamed(context, '/birds');
            },
          ),
          const SizedBox(height: 16),
          _buildCategoryCard(
            context,
            'Mamíferos',
            Icons.pets, 
            () {
              Navigator.pushNamed(context, '/mammals');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _downloadResources(context),
        tooltip: 'Descargar recursos',
        icon: const Icon(Icons.download),
        label: const Text('Descargar'),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).primaryColor),
              const SizedBox(width: 24),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadResources(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando recursos...')),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final firestore = FirebaseFirestore.instance;

      // Download birds
      final birdsSnapshot = await firestore.collection('animals_birds').get();
      final birdsData = birdsSnapshot.docs.map((doc) => doc.data()).toList();
      await prefs.setString('offline_birds', jsonEncode(birdsData));

      // Download mammals
      final mammalsSnapshot = await firestore.collection('animals_mammals').get();
      final mammalsData = mammalsSnapshot.docs.map((doc) => doc.data()).toList();
      await prefs.setString('offline_mammals', jsonEncode(mammalsData));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recursos descargados con éxito!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    }
  }
}
