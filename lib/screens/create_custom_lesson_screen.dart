import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:translator/translator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:myapp/services/sync_service.dart';
import 'dart:math';

class CreateCustomLessonScreen extends StatefulWidget {
  final String? lessonName;
  final Map<String, dynamic>? initialData;
  const CreateCustomLessonScreen({super.key, this.lessonName, this.initialData});

  @override
  State<CreateCustomLessonScreen> createState() => _CreateCustomLessonScreenState();
}

class _CreateCustomLessonScreenState extends State<CreateCustomLessonScreen> {
  final _lessonNameController = TextEditingController();
  final List<_PhrasePair> _pairs = [ _PhrasePair() ];
  bool _isSaving = false;
  bool _isCheckingName = false;
  String? _username;
  String? _nameError;
  String? _saveError;
  bool _isConnected = true;
  bool _modelsDownloaded = false;
  bool _isDownloading = false;
  late final OnDeviceTranslator _onDeviceTranslator;
  bool _isWeb = false;
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
      _isWeb = identical(0, 0.0);
    });
    _onDeviceTranslator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.spanish,
      targetLanguage: TranslateLanguage.english,
    );
    _checkConnectivity();
    _checkModels();
    // If editing, prefill the form
    if (widget.lessonName != null && widget.initialData != null) {
      _isEditMode = true;
      _lessonNameController.text = widget.lessonName!;
      _pairs.clear();
      final entries = widget.initialData!['entries'] as List;
      for (var e in entries) {
        final pair = _PhrasePair()
          ..achuar = e['achuar'] ?? ''
          ..spanish = e['spanish'] ?? ''
          ..english = e['english'] ?? ''
          ..achuarController = TextEditingController(text: e['achuar'] ?? '')
          ..spanishController = TextEditingController(text: e['spanish'] ?? '');
        _pairs.add(pair);
      }
      if (_pairs.isEmpty) _pairs.add(_PhrasePair());
    }
  }

  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = !result.contains(ConnectivityResult.none);
    });
    Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
    });
  }

  Future<void> _checkModels() async {
    final modelManager = OnDeviceTranslatorModelManager();
    final spanishDownloaded = await modelManager.isModelDownloaded('es');
    final englishDownloaded = await modelManager.isModelDownloaded('en');
    setState(() {
      _modelsDownloaded = spanishDownloaded && englishDownloaded;
    });
  }

  Future<void> _downloadModels() async {
    setState(() { _isDownloading = true; });
    final modelManager = OnDeviceTranslatorModelManager();
    await modelManager.downloadModel('es');
    await modelManager.downloadModel('en');
    setState(() { _isDownloading = false; _modelsDownloaded = true; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Modelos descargados exitosamente!')));
  }

  Future<void> _translate(int index) async {
    final pair = _pairs[index];
    if (pair.spanish.isEmpty) return;
    setState(() { pair.isTranslating = true; });
    try {
      String translated = '';
      if (_isWeb || (_isConnected && !_modelsDownloaded)) {
        final translator = GoogleTranslator();
        final translation = await translator.translate(pair.spanish, from: 'es', to: 'en');
        translated = translation.text;
      } else if (_modelsDownloaded) {
        translated = await _onDeviceTranslator.translateText(pair.spanish);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin conexión. Descargue los modelos o conéctese a internet.')));
        return;
      }
      setState(() { pair.english = translated; });

      // Submit to achuar_submission collection
      final submission = {
        'achuar': pair.achuar,
        'spanish': pair.spanish,
        'english': translated,
        'user': _username,
        'source': 'lecciones',
        'timestamp': DateTime.now().toIso8601String(),
      };
      await SyncService().addSubmission(submission);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al traducir: $e')));
    } finally {
      setState(() { pair.isTranslating = false; });
    }
  }

  Future<bool> _checkLessonNameUnique(String name) async {
    setState(() { _isCheckingName = true; });
    final query = await FirebaseFirestore.instance
      .collection('custom_lessons')
      .where('username', isEqualTo: _username)
      .where('name', isEqualTo: name)
      .get();
    setState(() { _isCheckingName = false; });
    return query.docs.isEmpty;
  }

  Future<void> _saveLesson() async {
    setState(() { _isSaving = true; _saveError = null; });
    final name = _lessonNameController.text.trim();
    if (name.isEmpty) {
      setState(() { _nameError = 'Por favor, ingresa un nombre para la lección.'; _isSaving = false; });
      return;
    }
    if (!RegExp(r"^[A-Za-z0-9_\- !?()']{3,}$").hasMatch(name)) {
      setState(() { _nameError = 'El nombre debe tener al menos 3 caracteres y solo letras, números, guiones, espacios, !, ?, (, ), o apóstrofes.'; _isSaving = false; });
      return;
    }
    if (!_isEditMode && !await _checkLessonNameUnique(name)) {
      setState(() { _nameError = 'Ya existe una lección con ese nombre.'; _isSaving = false; });
      return;
    }
    setState(() { _nameError = null; });
    final entries = _pairs.where((p) => p.achuar.isNotEmpty && p.spanish.isNotEmpty && p.english.isNotEmpty).map((p) => {
      'achuar': p.achuar,
      'spanish': p.spanish,
      'english': p.english,
    }).toList();
    if (entries.isEmpty) {
      setState(() { _saveError = 'Agrega al menos una frase válida.'; _isSaving = false; });
      return;
    }
    final lessonDoc = FirebaseFirestore.instance.collection('custom_lessons').doc('${_username}_$name');
    final lessonData = {
      'name': name,
      'username': _username,
      'entries': entries,
      'created_at': DateTime.now().toIso8601String(),
    };
    try {
      if (_isConnected) {
        // If editing and the name changed, delete the old doc
        if (_isEditMode && widget.lessonName != null && widget.lessonName != name) {
          final oldDoc = FirebaseFirestore.instance.collection('custom_lessons').doc('${_username}_${widget.lessonName}');
          await oldDoc.delete();
        }
        await lessonDoc.set(lessonData);
      } else {
        // Save to pending submissions for later upload
        final prefs = await SharedPreferences.getInstance();
        final pending = prefs.getStringList('pendingCustomLessons') ?? [];
        pending.add('${_username}_$name');
        await prefs.setStringList('pendingCustomLessons', pending);
        await prefs.setString('customLesson_${_username}_$name', lessonData.toString());
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lección guardada correctamente.')));
    } catch (e) {
      setState(() { _saveError = 'Error al guardar la lección: $e'; });
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  @override
  void dispose() {
    _lessonNameController.dispose();
    _onDeviceTranslator.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Crear lección personalizada'),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre de la lección', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            TextField(
              controller: _lessonNameController,
              decoration: InputDecoration(
                hintText: 'Ejemplo: Animales de la selva',
                errorText: _nameError,
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 24),
            Text('Frases de la lección', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDarkMode ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            ..._pairs.asMap().entries.map((entry) {
              final i = entry.key;
              final pair = entry.value;
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Frase ${i + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Introduce Achuar...',
                          filled: true,
                          fillColor: isDarkMode ? const Color(0xFF232323) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                        ),
                        controller: pair.achuarController ??= TextEditingController(text: pair.achuar),
                        onChanged: (v) => pair.achuar = v,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Introduce español...',
                          filled: true,
                          fillColor: isDarkMode ? const Color(0xFF232323) : Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                        ),
                        controller: pair.spanishController ??= TextEditingController(text: pair.spanish),
                        onChanged: (v) => pair.spanish = v,
                        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Inglés (auto)', style: TextStyle(fontSize: 13, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF232323) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pair.english,
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          pair.isTranslating
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                              : ElevatedButton.icon(
                                  onPressed: (_isDownloading || (!_isConnected && !_modelsDownloaded)) ? null : () => _translate(i),
                                  icon: const Icon(Icons.translate, size: 18),
                                  label: const Text('Traducir'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF82B366),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                        ],
                      ),
                      if (!_modelsDownloaded && !_isWeb) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _isDownloading ? null : _downloadModels,
                          icon: const Icon(Icons.download, size: 18),
                          label: _isDownloading ? const Text('Descargando...') : const Text('Descargar modelos'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                      if (_pairs.length > 1)
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              setState(() { _pairs.removeAt(i); });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() { _pairs.add(_PhrasePair()); });
                },
                icon: const Icon(Icons.add),
                label: const Text('Agregar frase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B5B95),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Center(child: Text(_saveError!, style: const TextStyle(color: Colors.red))),
            ],
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveLesson,
                icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                label: const Text('Guardar lección'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF82B366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhrasePair {
  String achuar = '';
  String spanish = '';
  String english = '';
  bool isTranslating = false;
  TextEditingController? achuarController;
  TextEditingController? spanishController;
} 