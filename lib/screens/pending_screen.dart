
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  _PendingScreenState createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  List<Map<String, dynamic>> _pendingSubmissions = [];
  List<Map<String, dynamic>> _pendingEdits = [];

  @override
  void initState() {
    super.initState();
    _loadPendingData();
  }

  Future<void> _loadPendingData() async {
    final prefs = await SharedPreferences.getInstance();

    // Handle pendingSubmissions
    final submissionsValue = prefs.get('pendingSubmissions');
    List<Map<String, dynamic>> submissionsList = [];
    if (submissionsValue is String) {
      final decoded = json.decode(submissionsValue);
      if (decoded is List) {
        submissionsList = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } else if (submissionsValue is List<String>) {
      submissionsList = submissionsValue.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    }

    // Handle pendingEdits
    final editsValue = prefs.get('pendingEdits');
    List<Map<String, dynamic>> editsList = [];
    if (editsValue is String) {
      final decoded = json.decode(editsValue);
      if (decoded is List) {
        editsList = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } else if (editsValue is List<String>) {
      editsList = editsValue.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    }

    if (mounted) {
      setState(() {
        _pendingSubmissions = submissionsList;
        _pendingEdits = editsList;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Elementos Pendientes'),
      ),
      body: (_pendingSubmissions.isEmpty && _pendingEdits.isEmpty)
          ? const Center(child: Text('No hay elementos pendientes.'))
          : ListView(
              children: [
                if (_pendingSubmissions.isNotEmpty)
                  _buildSectionTitle('Contribuciones Pendientes'),
                ..._pendingSubmissions.map((submission) =>
                  _buildSubmissionCard(submission, isDarkMode)),
                if (_pendingEdits.isNotEmpty)
                  _buildSectionTitle('Ediciones Pendientes'),
                ..._pendingEdits.map((edit) =>
                  _buildEditCard(edit, isDarkMode)),
              ],
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Achuar: ${submission['achuar']}',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Español: ${submission['spanish']}',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditCard(Map<String, dynamic> edit, bool isDarkMode) {
    final data = edit['data'] as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Achuar: ${data['achuar']}',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Español: ${data['spanish']}',
              style: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 14,
              ),
            ),
             const SizedBox(height: 8),
            const Text(
              'Edición pendiente',
              style: TextStyle(
                color: Colors.orange,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
