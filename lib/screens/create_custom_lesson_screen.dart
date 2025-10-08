import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:translator/translator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:myapp/l10n/app_localizations.dart';

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
  OnDeviceTranslator? _onDeviceTranslator; // Make nullable for web
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
    });
    
    // Only initialize on-device translator on mobile/desktop
    if (!kIsWeb) {
      _onDeviceTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.spanish,
        targetLanguage: TranslateLanguage.english,
      );
      _checkModels();
    } else {
      // On web, mark models as "downloaded" since we'll use online translation
      setState(() {
        _modelsDownloaded = true;
      });
    }
    
    _checkConnectivity();
    
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
      if (mounted) {
        setState(() {
          _isConnected = !result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _checkModels() async {
    if (kIsWeb) return; // Skip model checking on web
    
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      final spanishDownloaded = await modelManager.isModelDownloaded('es');
      final englishDownloaded = await modelManager.isModelDownloaded('en');
      if (mounted) {
        setState(() {
          _modelsDownloaded = spanishDownloaded && englishDownloaded;
        });
      }
    } catch (e) {
      print('Error checking models: $e');
      // On error, assume models are not downloaded
      if (mounted) {
        setState(() {
          _modelsDownloaded = false;
        });
      }
    }
  }

  Future<void> _downloadModels() async {
    if (kIsWeb) return; // No model downloads on web
    
    setState(() { _isDownloading = true; });
    try {
      final modelManager = OnDeviceTranslatorModelManager();
      await modelManager.downloadModel('es');
      await modelManager.downloadModel('en');
      if (mounted) {
        setState(() { _isDownloading = false; _modelsDownloaded = true; });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.modelsDownloadedSuccessfully ?? 'Models downloaded successfully!'))
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isDownloading = false; });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n?.errorDownloadingModels ?? 'Error downloading models'}: $e'))
        );
      }
    }
  }

  // Text preprocessing for better translation quality
  String _preprocessText(String text) {
    if (text.isEmpty) return text;
    
    // Remove extra whitespace and normalize
    String processed = text.trim();
    
    // Replace multiple spaces with single space
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');
    
    // Normalize punctuation spacing
    processed = processed.replaceAll(RegExp(r'\s*([.!?,:;])\s*'), r'$1 ');
    processed = processed.replaceAll(RegExp(r'\s*([.!?])\s*$'), r'$1');
    
    // Ensure proper sentence capitalization
    if (processed.isNotEmpty) {
      processed = processed[0].toUpperCase() + processed.substring(1);
    }
    
    // Add period if sentence doesn't end with punctuation
    if (processed.isNotEmpty && !RegExp(r'[.!?]$').hasMatch(processed)) {
      processed += '.';
    }
    
    return processed;
  }

  // Post-processing for translation output
  String _postprocessTranslation(String translation) {
    if (translation.isEmpty) return translation;
    
    String processed = translation.trim();
    
    // Remove extra whitespace
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove any remaining context phrases (comprehensive cleanup)
    processed = processed.replaceAll(RegExp(r'^(Translate\s+(to|into)\s+English:\s*|Traducir\s+al\s+inglés:\s*)', caseSensitive: false), '');
    processed = processed.replaceAll(RegExp(r'^(Translation:\s*|Traducción:\s*)', caseSensitive: false), '');
    processed = processed.replaceAll(RegExp(r'^(English:\s*|Inglés:\s*)', caseSensitive: false), '');
    
    // Ensure proper capitalization
    if (processed.isNotEmpty) {
      processed = processed[0].toUpperCase() + processed.substring(1);
    }
    
    // Clean up common translation artifacts
    processed = processed.replaceAll(RegExp(r'^(The\s+)?'), '');
    processed = processed.replaceAll(RegExp(r'\s*\.$'), '');
    
    return processed;
  }

  Future<void> _translate(int index) async {
    final pair = _pairs[index];
    if (pair.spanish.isEmpty) return;
    
    setState(() { pair.isTranslating = true; });
    
    try {
      // Preprocess the input text
      final processedText = _preprocessText(pair.spanish);
      
      // Add context for better translation if it's a short phrase
      String contextualText = processedText;
      if (processedText.split(' ').length <= 3) {
        contextualText = 'Traducir al inglés: $processedText';
      }
      
      String translated = '';
      
      if (kIsWeb || (_isConnected && !_modelsDownloaded)) {
        // Use online translation for web or when models aren't downloaded
        final translator = GoogleTranslator();
        try {
          final translation = await translator.translate(contextualText, from: 'es', to: 'en');
          translated = translation.text;
          
          // Clean up context prefix if we added it
          if (contextualText != processedText) {
            translated = translated.replaceFirst(RegExp(r'^(Translate to English:\s*|Translate into English:\s*|Traducir al inglés:\s*)', caseSensitive: false), '');
          }
        } catch (e) {
          print('[TRANSLATE] Error with context, trying without: $e');
          // Fallback without context
          final translation = await translator.translate(processedText, from: 'es', to: 'en');
          translated = translation.text;
        }
      } else if (_modelsDownloaded && _onDeviceTranslator != null) {
        // Use on-device translation for mobile when models are available
        translated = await _onDeviceTranslator!.translateText(contextualText);
        
        // Clean up context prefix if we added it
        if (contextualText != processedText) {
          translated = translated.replaceFirst(RegExp(r'^(Translate to English:\s*|Traducir al inglés:\s*)', caseSensitive: false), '');
        }
      } else {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.noConnectionDownloadModelsOrConnect ?? 'No connection. Download models or connect to internet.'))
          );
        }
        return;
      }
      
      // Post-process the translation
      translated = _postprocessTranslation(translated);
      
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
      
      try {
        await SyncService().addSubmission(submission);
      } catch (syncError) {
        print('[TRANSLATE] Error saving submission: $syncError');
        // Continue without saving submission - translation still worked
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n?.errorTranslating ?? 'Error translating'}: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() { pair.isTranslating = false; });
      }
    }
  }

  Future<bool> _checkLessonNameUnique(String name) async {
    setState(() { _isCheckingName = true; });
    try {
      final query = await FirebaseFirestore.instance
        .collection('custom_lessons')
        .where('username', isEqualTo: _username)
        .where('name', isEqualTo: name)
        .get();
      setState(() { _isCheckingName = false; });
      return query.docs.isEmpty;
    } catch (e) {
      setState(() { _isCheckingName = false; });
      return true; // Assume unique on error
    }
  }

  Future<void> _saveLesson() async {
    setState(() { _isSaving = true; _saveError = null; });
    
    final name = _lessonNameController.text.trim();
    if (name.isEmpty) {
      setState(() { 
        _nameError = 'Por favor, ingresa un nombre para la lección.'; 
        _isSaving = false; 
      });
      return;
    }
    
    if (!RegExp(r"^[A-Za-z0-9_\- !?()']{3,}$").hasMatch(name)) {
      setState(() { 
        _nameError = 'El nombre debe tener al menos 3 caracteres y solo letras, números, guiones, espacios, !, ?, (, ), o apóstrofes.'; 
        _isSaving = false; 
      });
      return;
    }
    
    if (!_isEditMode && !await _checkLessonNameUnique(name)) {
      setState(() { 
        final l10n = AppLocalizations.of(context);
        _nameError = l10n?.lessonNameAlreadyExistsMessage ?? 'A lesson with that name already exists.'; 
        _isSaving = false; 
      });
      return;
    }
    
    setState(() { _nameError = null; });
    
    final entries = _pairs.where((p) => 
      p.achuar.isNotEmpty && p.spanish.isNotEmpty && p.english.isNotEmpty
    ).map((p) => {
      'achuar': p.achuar,
      'spanish': p.spanish,
      'english': p.english,
    }).toList();
    
    if (entries.isEmpty) {
      setState(() { 
        _saveError = 'Agrega al menos una frase válida.'; 
        _isSaving = false; 
      });
      return;
    }
    
    final lessonDoc = FirebaseFirestore.instance
        .collection('custom_lessons')
        .doc('${_username}_$name');
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
          final oldDoc = FirebaseFirestore.instance
              .collection('custom_lessons')
              .doc('${_username}_${widget.lessonName}');
          await oldDoc.delete();
        }
        await lessonDoc.set(lessonData);
        
        // If editing, mark the lesson as undownloaded (for both name and content changes)
        if (_isEditMode) {
          final prefs = await SharedPreferences.getInstance();
          final currentLessonName = widget.lessonName ?? name;
          final newLessonName = name;
          
          // Remove download status for both old and new names (in case name changed)
          await prefs.remove('offline_custom_lesson_${currentLessonName}_downloaded');
          if (currentLessonName != newLessonName) {
            await prefs.remove('offline_custom_lesson_${newLessonName}_downloaded');
          }
          print('[CustomLesson] Marked edited lesson as undownloaded: $currentLessonName');
        }
      } else {
        // Save offline - update local storage
        final prefs = await SharedPreferences.getInstance();
        
        // Load existing lessons
        final lessonsJson = prefs.getStringList('local_custom_lessons') ?? [];
        final lessons = lessonsJson
            .map((json) => jsonDecode(json) as Map<String, dynamic>)
            .toList();
        
        // Add the document ID
        final docId = '${_username}_$name';
        lessonData['id'] = docId;
        
        if (_isEditMode) {
          // If editing and name changed, remove old lesson
          if (widget.lessonName != null && widget.lessonName != name) {
            final oldDocId = '${_username}_${widget.lessonName}';
            lessons.removeWhere((lesson) => 
              lesson['id'] == oldDocId || lesson['name'] == widget.lessonName
            );
          }
          
          // Update existing lesson or add if not found
          final existingIndex = lessons.indexWhere((lesson) => 
            lesson['id'] == docId || lesson['name'] == name
          );
          
          if (existingIndex != -1) {
            lessons[existingIndex] = lessonData;
          } else {
            lessons.add(lessonData);
          }
          
          // Remove download status for old and new names
          final currentLessonName = widget.lessonName ?? name;
          final newLessonName = name;
          await prefs.remove('offline_custom_lesson_${currentLessonName}_downloaded');
          if (currentLessonName != newLessonName) {
            await prefs.remove('offline_custom_lesson_${newLessonName}_downloaded');
          }
          print('[CustomLesson] Updated lesson offline: $name');
        } else {
          // Adding new lesson
          lessons.add(lessonData);
          print('[CustomLesson] Added new lesson offline: $name');
        }
        
        // Save back to local storage
        final updatedLessonsJson = lessons.map((lesson) => jsonEncode(lesson)).toList();
        await prefs.setStringList('local_custom_lessons', updatedLessonsJson);
        
        // Track as pending edit for sync when online
        final pendingEdits = prefs.getStringList('pending_custom_lesson_edits') ?? [];
        if (!pendingEdits.contains(docId)) {
          pendingEdits.add(docId);
          await prefs.setStringList('pending_custom_lesson_edits', pendingEdits);
        }
        
        print('[CustomLesson] Saved ${lessons.length} lessons to local storage (marked $docId as pending sync)');
      }
      
      if (mounted) {
        // Return the updated lesson data to the previous screen
        Navigator.of(context).pop({
          'success': true,
          'lessonData': lessonData,
        });
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n?.lessonSaved ?? 'Lesson saved successfully.'))
        );
      }
    } catch (e) {
      setState(() { _saveError = 'Error al guardar la lección: $e'; });
    } finally {
      setState(() { _isSaving = false; });
    }
  }

  @override
  void dispose() {
    _lessonNameController.dispose();
    if (!kIsWeb && _onDeviceTranslator != null) {
      _onDeviceTranslator!.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_isEditMode 
          ? (AppLocalizations.of(context)?.editLesson ?? 'Editar lección')
          : (AppLocalizations.of(context)?.createCustomLessonTitle ?? 'Crear lección personalizada')),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.lessonName ?? 'Nombre de la lección', 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 18, 
                color: isDarkMode ? Colors.white : Colors.black87
              )
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lessonNameController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)?.exampleJungleAnimals ?? 'Ejemplo: Animales de la selva',
                errorText: _nameError,
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), 
                  borderSide: BorderSide.none
                ),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 16),
            
            // Show warning about redownload requirement when editing
            if (_isEditMode) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.editLessonRedownloadWarning ?? 'Al editar esta lección, será necesario redescargarla para uso offline',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 24),
            ],
            
            Text(
              AppLocalizations.of(context)?.lessonPhrases ?? 'Frases de la lección', 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 18, 
                color: isDarkMode ? Colors.white : Colors.black87
              )
            ),
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
                      Text(
                        '${AppLocalizations.of(context)?.phrase ?? 'Frase'} ${i + 1}', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: isDarkMode ? Colors.white : Colors.black87
                        )
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)?.enterAchuar ?? 'Introduce Achuar...',
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
                          hintText: AppLocalizations.of(context)?.enterSpanish ?? 'Introduce español...',
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
                                Text(AppLocalizations.of(context)?.englishAuto ?? 'English (auto)', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? const Color(0xFF232323) : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    pair.english.isEmpty 
                                      ? (AppLocalizations.of(context)?.translationAppearHere ?? 'Traducción aparecerá aquí...') 
                                      : pair.english,
                                    style: TextStyle(
                                      color: pair.english.isEmpty 
                                        ? Colors.grey 
                                        : (isDarkMode ? Colors.white : Colors.black87),
                                      fontSize: 16,
                                      fontStyle: pair.english.isEmpty ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          pair.isTranslating
                              ? const SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(strokeWidth: 2)
                                )
                              : ElevatedButton.icon(
                                  onPressed: (_isDownloading || (!_isConnected && !_modelsDownloaded && !kIsWeb)) 
                                    ? null 
                                    : () => _translate(i),
                                  icon: const Icon(Icons.translate, size: 18),
                                  label: Text(AppLocalizations.of(context)?.translate ?? 'Translate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF82B366),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)
                                    ),
                                  ),
                                ),
                        ],
                      ),

                      // Only show model download option on mobile when models aren't downloaded
                      if (!_modelsDownloaded && !kIsWeb) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, size: 16, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Para traducción offline',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: (_isDownloading || !_isConnected) ? null : _downloadModels,
                                icon: _isDownloading 
                                  ? const SizedBox(
                                      width: 16, 
                                      height: 16, 
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                    )
                                  : const Icon(Icons.download, size: 18),
                                label: Text(_isDownloading ? 'Descargando...' : (!_isConnected ? 'Sin conexión' : 'Descargar modelos')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (_isDownloading || !_isConnected) ? Colors.grey[400] : Colors.orange[700],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                label: Text(AppLocalizations.of(context)?.addPhrase ?? 'Add phrase'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B5B95),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!, 
                          style: const TextStyle(color: Colors.red)
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveLesson,
                icon: _isSaving 
                  ? const SizedBox(
                      width: 18, 
                      height: 18, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    ) 
                  : const Icon(Icons.save),
                label: Text(_isEditMode 
                  ? (AppLocalizations.of(context)?.saveChanges ?? 'Guardar cambios')
                  : (AppLocalizations.of(context)?.saveLesson ?? 'Guardar lección')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF82B366),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40), // Extra padding at bottom
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