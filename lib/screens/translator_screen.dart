import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:translator/translator.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:myapp/services/tts_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

// THIS EXTENSION PROVIDES THE MISSING .bcp47Code GETTER
extension TranslateLanguageExtension on TranslateLanguage {
  /// Returns the BCP-47 language code for the TranslateLanguage enum.
  String get bcp47Code {
    switch (this) {
      case TranslateLanguage.spanish:
        return 'es';
      case TranslateLanguage.english:
        return 'en';
      // Add other languages here if you use them
      default:
        throw ArgumentError('BCP-47 code not defined for $this');
    }
  }
}

class TranslatorScreen extends StatefulWidget {
  const TranslatorScreen({super.key});

  @override
  State<TranslatorScreen> createState() => _TranslatorScreenState();
}

class _TranslatorScreenState extends State<TranslatorScreen> with SingleTickerProviderStateMixin {
  final _achuarTextController = TextEditingController();
  final _sourceTextController = TextEditingController();
  final _translatedTextController = TextEditingController();
  late final OnDeviceTranslator _onDeviceTranslator;
  late TabController _tabController;
  
  bool _modelsDownloaded = false;
  bool _isDownloading = false;
  bool _isTranslating = false;
  bool _isSubmitting = false;
  bool _isConnected = false;

  List<Map<String, dynamic>> _recentTranslations = [];
  // Replace _userLists with a list of list objects from Firestore
  List<Map<String, dynamic>> _userLists = [];
  bool _loadingLists = true;

  String? _username;
  bool _loadingTranslations = true;
  
  final int _maxRecentTranslations = 20;

  String get _currentUserId => _username ?? '';

  String? _downloadingListName;
  double _downloadListProgress = 0.0;
  double _modelDownloadProgress = 0.0;
  StreamSubscription<dynamic>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // No need to set _isWeb, use kIsWeb directly

    if (!kIsWeb) {
      _onDeviceTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.spanish,
        targetLanguage: TranslateLanguage.english,
      );
      _checkModels();
    }
    _restoreModelDownloadState();
    _initConnectivity();
    _loadUsernameAndTranslations().then((_) {
      _loadUserLists();
    });
    _achuarTextController.addListener(_onTextChanged);
    _sourceTextController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    if (!kIsWeb) {
      _onDeviceTranslator.close();
    }
    _achuarTextController.removeListener(_onTextChanged);
    _sourceTextController.removeListener(_onTextChanged);
    _achuarTextController.dispose();
    _sourceTextController.dispose();
    _translatedTextController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isConnected = !result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (mounted) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
    }
  }

  Future<void> _loadUsernameAndTranslations() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    setState(() {
      _username = username;
    });
    if (username != null && username.isNotEmpty) {
      _fetchRecentTranslations(username);
    }
  }

  Future<void> _fetchRecentTranslations(String username) async {
    setState(() { _loadingTranslations = true; });
    final query = await FirebaseFirestore.instance
        .collection('achuar_submission')
        .where('user', isEqualTo: username)
        .orderBy('timestamp', descending: true)
        .limit(_maxRecentTranslations)
        .get();
    setState(() {
      _recentTranslations = query.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();
      _loadingTranslations = false;
    });
  }

  Future<void> _saveTranslations() async {
    final prefs = await SharedPreferences.getInstance();
    
    final recentJson = _recentTranslations.map((translation) => 
      jsonEncode(translation)
    ).toList();
    
    await prefs.setStringList('recentTranslations', recentJson);
  }

  Future<void> _addToRecent(String achuar, String english) async {
    final translation = {
      'achuar': achuar,
      'english': english,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _recentTranslations.removeWhere((t) => 
        t['achuar'] == achuar && t['english'] == english
      );
      _recentTranslations.insert(0, translation);
      if (_recentTranslations.length > _maxRecentTranslations) {
        _recentTranslations = _recentTranslations.take(_maxRecentTranslations).toList();
      }
    });
    
    await _saveTranslations();
  }

  Future<void> _toggleFavorite(Map<String, dynamic> translation) async {
    if (_username == null) return;
    // Optimistically update UI
    setState(() {
      // The _favoriteTranslations list is removed, so this logic is no longer needed.
      // The _userLists feature handles favorites.
    });
    // Update Firestore in background
    final query = await FirebaseFirestore.instance
        .collection('achuar_submission')
        .where('user', isEqualTo: _username)
        .where('achuar', isEqualTo: translation['achuar'])
        .where('english', isEqualTo: translation['english'])
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final isFav = (doc.data()['favourite'] == true);
      await doc.reference.update({'favourite': !isFav});
      // Optionally, re-fetch from Firestore to ensure consistency
      // await _fetchFavoriteTranslations(_username!);
    }
  }

  bool _isFavorite(Map<String, dynamic> translation) {
    // The _favoriteTranslations list is removed, so this logic is no longer needed.
    // The _userLists feature handles favorites.
    return false; // Placeholder, as _favoriteTranslations is removed
  }

  Future<void> _addLocalSubmissionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('localSubmissionIds') ?? [];
    if (!ids.contains(id)) {
      ids.add(id);
      await prefs.setStringList('localSubmissionIds', ids);
    }
  }

  Future<void> _checkModels() async {
    final modelManager = OnDeviceTranslatorModelManager();
    final spanishDownloaded = await modelManager
        .isModelDownloaded(TranslateLanguage.spanish.bcp47Code);
    final englishDownloaded = await modelManager
        .isModelDownloaded(TranslateLanguage.english.bcp47Code);
    if (mounted) {
      setState(() {
        _modelsDownloaded = spanishDownloaded && englishDownloaded;
      });
    }
  }

  Future<void> _restoreModelDownloadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDownloading = prefs.getBool('translator_model_downloading') ?? false;
      _modelDownloadProgress = prefs.getDouble('translator_model_download_progress') ?? 0.0;
    });
    if (_isDownloading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _downloadModels();
      });
    }
  }

  Future<void> _downloadModels() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin conexión. Conéctese a internet para descargar los modelos de traducción.')),
      );
      return;
    }
    if (_isDownloading) return;
    if (!mounted) return;
    setState(() {
      _isDownloading = true;
      _modelDownloadProgress = 0.0;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('translator_model_downloading', true);
    await prefs.setDouble('translator_model_download_progress', 0.0);

    final modelManager = OnDeviceTranslatorModelManager();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Descargando modelos...'),
            SizedBox(height: 8),
            Text('Por favor, no abandone esta página mientras se descargan los modelos.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        duration: Duration(minutes: 2),
      ),
    );

    // Spanish model
    await modelManager.downloadModel(TranslateLanguage.spanish.bcp47Code);
    if (!mounted) return;
    setState(() {
      _modelDownloadProgress = 0.5;
    });
    await prefs.setDouble('translator_model_download_progress', 0.5);

    // English model
    await modelManager.downloadModel(TranslateLanguage.english.bcp47Code);
    if (!mounted) return;
    setState(() {
      _modelDownloadProgress = 1.0;
    });
    await prefs.setDouble('translator_model_download_progress', 1.0);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Modelos descargados exitosamente!')),
    );

    if (!mounted) return;
    setState(() {
      _isDownloading = false;
      _modelDownloadProgress = 0.0;
    });
    await prefs.setBool('translator_model_downloading', false);
    await prefs.setDouble('translator_model_download_progress', 0.0);
    _checkModels();
  }

  Future<void> _translateText() async {
    if (_achuarTextController.text.isEmpty || _sourceTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingrese texto en ambos campos.')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isTranslating = true;
        _translatedTextController.text = '';
      });
    }

    final sourceText = _sourceTextController.text;
    String translatedText;

    try {
      print('DEBUG: _translateText called. kIsWeb=$kIsWeb');
      if (kIsWeb || (!kIsWeb && (_modelsDownloaded || _isConnected))) {
        final translator = GoogleTranslator();
        final translation = await translator.translate(sourceText, from: 'es', to: 'en');
        translatedText = translation.text;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin conexión. Descargue los modelos o conéctese a internet.')),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _translatedTextController.text = translatedText;
        });
        await _addToRecent(_achuarTextController.text, translatedText);
        await _submitToFirestore();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al traducir: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  Future<void> _submitToFirestore() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final deviceId = await SyncService().getDeviceId();
    final submission = {
      'achuar': _achuarTextController.text,
      'spanish': _sourceTextController.text,
      'english': _translatedTextController.text,
      'source': 'translator',
      'notes': '',
      'location': 'Desde Traductor',
      'deviceId': deviceId,
    };
    
    final wasSavedLocally = await SyncService().addSubmission(submission);

    if (mounted && wasSavedLocally) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guardado localmente. Se enviará cuando haya conexión.')),
      );
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _clearAll() {
    _achuarTextController.clear();
    _sourceTextController.clear();
    _translatedTextController.clear();
  }

  Future<void> _loadUserLists() async {
    setState(() { _loadingLists = true; });
    if (_currentUserId.isEmpty) {
      setState(() { _userLists = []; _loadingLists = false; });
      return;
    }
    final query = await FirebaseFirestore.instance
        .collection('custom_lists')
        .where('userId', isEqualTo: _currentUserId)
        .get();
    setState(() {
      _userLists = query.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      _loadingLists = false;
    });
  }

  Future<void> _saveList(String listName, List<Map<String, dynamic>> translations) async {
    if (_currentUserId.isEmpty) return;
    final docId = '${_currentUserId}_$listName';
    await FirebaseFirestore.instance.collection('custom_lists').doc(docId).set({
      'userId': _currentUserId,
      'listName': listName,
      'translations': translations,
    });
  }

  Future<void> _addToListDialog(Map<String, dynamic> translation) async {
    String? selectedList;
    String? newListName;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF82B366);
    await _showModernDialog(
      context: context,
      title: 'Agregar a lista',
      icon: Icons.playlist_add_rounded,
      iconColor: accentColor,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_userLists.isNotEmpty)
            DropdownButton<String>(
              value: selectedList,
              hint: const Text('Selecciona una lista'),
              items: _userLists.map((list) => DropdownMenuItem<String>(
                value: list['listName'],
                child: Text(list['listName']),
              )).toList(),
              onChanged: (val) => selectedList = val,
              isExpanded: true,
            ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              labelText: 'Crear nueva list...',
              filled: true,
              fillColor: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: accentColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 15,
            ),
            onChanged: (val) => newListName = val,
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (newListName != null && newListName!.trim().isNotEmpty) {
                    if (_userLists.any((l) => l['listName'] == newListName!.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ya existe una lista con ese nombre.')),
                      );
                      return;
                    }
                    await _saveList(newListName!.trim(), [translation]);
                    await _loadUserLists();
                    Navigator.pop(context);
                  } else if (selectedList != null) {
                    final list = _userLists.firstWhere((l) => l['listName'] == selectedList);
                    final translations = List<Map<String, dynamic>>.from(list['translations']);
                    if (translations.any((t) => t['achuar'] == translation['achuar'] && t['english'] == translation['english'])) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Esta traducción ya está en la lista.')),
                      );
                      return;
                    }
                    translations.add(translation);
                    await _saveList(selectedList!, translations);
                    await _loadUserLists();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Agregar'),
              ),
            ),
          ],
        ),
      ],
    );
    setState(() {});
  }

  Future<void> _createNewListDialog() async {
    String? newListName;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColor = const Color(0xFF82B366);
    await _showModernDialog(
      context: context,
      title: 'Crear nueva lista',
      icon: Icons.create_new_folder_rounded,
      iconColor: accentColor,
      content: TextField(
        decoration: InputDecoration(
          labelText: 'Nombre de la lista...',
          filled: true,
          fillColor: isDarkMode ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        onChanged: (val) => newListName = val,
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (newListName != null && newListName!.trim().isNotEmpty) {
                    if (_userLists.any((l) => l['listName'] == newListName!.trim())) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ya existe una lista con ese nombre.')),
                      );
                      return;
                    }
                    await _saveList(newListName!.trim(), []);
                    await _loadUserLists();
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
                child: const Text('Crear'),
              ),
            ),
          ],
        ),
      ],
    );
    setState(() {});
  }

  void _showListTranslationsDialog(String listName) {
    final list = _userLists.firstWhere((l) => l['listName'] == listName);
    final translations = List<Map<String, dynamic>>.from(list['translations']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(listName),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: translations.isEmpty
                  ? [const Text('No hay traducciones en esta lista.')]
                  : translations.map((translation) => ListTile(
                        title: Text(translation['achuar'] ?? ''),
                        subtitle: Text(translation['english'] ?? ''),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            translations.remove(translation);
                            await _saveList(listName, translations);
                            await _loadUserLists();
                            Navigator.of(context).pop();
                            _showListTranslationsDialog(listName);
                          },
                        ),
                      )).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _isListDownloadedOffline(String listName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('offline_list_${listName}_downloaded') ?? false;
  }

  Future<void> _downloadListOffline(String listName, List<Map<String, dynamic>> translations, void Function(void Function()) setState) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _downloadingListName = listName; _downloadListProgress = 0.0; });
    // Save translations locally
    await prefs.setString('offline_list_$listName', jsonEncode(translations));
    
    // Add web check before downloading TTS audio
    if (kIsWeb) {
      // On web, just save the list data locally, no file downloads
      await prefs.setBool('offline_list_${listName}_downloaded', true);
      setState(() { _downloadingListName = null; _downloadListProgress = 0.0; });
      return;
    }
    
    // Download TTS audio for each translation (mobile/desktop only)
    final appDocDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDocDir.path}/offline_list_audio');
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }
    int completed = 0;
    try {
      for (final translation in translations) {
        final english = translation['english'] as String?;
        if (english != null && english.isNotEmpty) {
          final safeName = english.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          final filePath = '${audioDir.path}/${listName}_$safeName.mp3';
          print('[LIST AUDIO DOWNLOAD] listName: $listName, safeName: $safeName, filePath: $filePath');
          final file = File(filePath);
          if (!file.existsSync()) {
            try {
              print('[LIST AUDIO DOWNLOAD] Starting download for: $filePath');
              final path = await downloadAndSaveEnglishTTS(
                english,
                filename: '${listName}_$safeName',
                forLesson: true,
              );
              print('[LIST AUDIO DOWNLOAD] Finished download for: $filePath');
              if (path != null) {
                print('[LIST AUDIO DOWNLOAD] Downloaded and saved: $path');
              } else {
                print('[LIST AUDIO DOWNLOAD] Failed to download: $filePath');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al descargar el audio para "$english".'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              print('[LIST AUDIO DOWNLOAD] Exception for $filePath: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al descargar el audio para "$english": $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else {
            print('[LIST AUDIO DOWNLOAD] Already exists: $filePath');
          }
        }
        completed++;
        setState(() { _downloadListProgress = completed / translations.length; });
        await Future.delayed(const Duration(milliseconds: 10)); // Yield to UI
      }
    } catch (e) {
      print('[LIST AUDIO DOWNLOAD] Outer exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error general al descargar la lista: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    await prefs.setBool('offline_list_${listName}_downloaded', true);
    setState(() { _downloadingListName = null; _downloadListProgress = 0.0; });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final canTranslate = kIsWeb
      ? _achuarTextController.text.isNotEmpty && _sourceTextController.text.isNotEmpty
      : (_modelsDownloaded || _isConnected);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Traductor',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          if (_achuarTextController.text.isNotEmpty || 
              _sourceTextController.text.isNotEmpty || 
              _translatedTextController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAll,
              tooltip: 'Limpiar todo',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF82B366),
          labelColor: const Color(0xFF82B366),
          unselectedLabelColor: isDarkMode ? Colors.grey[600] : Colors.grey[600],
          tabs: const [
            Tab(text: 'Traductor'),
            Tab(text: 'Listas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Translator Tab
          SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInputSection(
                        title: 'Achuar',
                        hint: 'Ingrese texto en Achuar...',
                        controller: _achuarTextController,
                        color: const Color(0xFF6B5B95),
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 20),
                      _buildInputSection(
                        title: 'Español',
                        hint: 'Ingrese texto en español...',
                        controller: _sourceTextController,
                        color: const Color(0xFF88B0D3),
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: canTranslate ? _translateText : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF82B366),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFF82B366).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isTranslating || _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.translate, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Traducir a Inglés',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildOutputSection(
                        title: 'Inglés',
                        controller: _translatedTextController,
                        color: const Color(0xFF82B366),
                        isDarkMode: isDarkMode,
                      ),
                      if (!kIsWeb && !_modelsDownloaded) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isDownloading) ...[
                                LinearProgressIndicator(
                                  minHeight: 8,
                                  backgroundColor: Colors.orange.withOpacity(0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Descargando modelos...',
                                  style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange),
                                textAlign: TextAlign.center,
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: (!_isConnected || _isDownloading) ? null : _downloadModels,
                                  icon: const Icon(Icons.download_rounded, color: Colors.orange),
                                  label: const Text('Descargar modelos de traducción'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: !_isConnected ? Colors.grey : Colors.orange,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                              ),
                                            ),
                                          ],
                            ],
                          ),
                        ),
                      ],
                      if (_recentTranslations.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              size: 20,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Traducciones recientes',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._recentTranslations.map((translation) => 
                          _buildTranslationCard(translation, isDarkMode)
                        ).toList(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildListsTab(isDarkMode),
        ],
      ),
    );
  }

  // 1. Updated translation card with modern styling
  Widget _buildTranslationCard(Map<String, dynamic> translation, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Achuar title and text
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Achuar:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B5B95),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            translation['achuar'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSquareButton(
                      icon: Icons.playlist_add_rounded,
                      color: const Color(0xFF82B366),
                      background: const Color(0xFF82B366).withOpacity(0.1),
                      onPressed: () => _addToListDialog(translation),
                      tooltip: 'Agregar a lista',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // English title and text (below title)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'English:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            translation['english'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSquareButton(
                      icon: Icons.volume_up_rounded,
                      color: Colors.blue,
                      background: Colors.blue.withOpacity(0.1),
                      onPressed: () async {
                        final englishText = translation['english'] as String?;
                        if (englishText == null || englishText.isEmpty) return;
                        
                        // Add web check for audio playback
                        if (kIsWeb) {
                          // On web, directly use TTS service
                          await playEnglishTTS(englishText, context: context);
                          return;
                        }
                        
                        // Original mobile/desktop logic
                        final appDocDir = await getApplicationDocumentsDirectory();
                        final safeName = englishText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                        final filePath = '${appDocDir.path}/offline_list_audio/recents_$safeName.mp3';
                        final file = File(filePath);
                        final connectivity = await Connectivity().checkConnectivity();
                        final isOffline = connectivity == ConnectivityResult.none;
                        if (await file.exists()) {
                          final player = AudioPlayer();
                          await player.play(DeviceFileSource(file.path));
                        } else if (isOffline) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Solo se puede reproducir audio sin conexión para traducciones descargadas.')),
                          );
                        } else {
                          await playEnglishTTS(englishText, context: context);
                        }
                      },
                      tooltip: 'Play English audio',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSquareButton({
    required IconData icon,
    required Color color,
    required Color background,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: color,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }

  // 2. Updated Lists tab UI
  Widget _buildListsTab(bool isDarkMode) {
    if (_loadingLists) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_userLists.isEmpty) {
      return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
              Icons.folder_outlined,
              size: 80,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                      ),
            const SizedBox(height: 24),
                      Text(
              'No hay listas creadas',
                        style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
              'Crea listas para organizar tus traducciones',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createNewListDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Crear nueva lista',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF82B366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
                ),
        ],
      ),
    );
  }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ..._userLists.map((list) => FutureBuilder<bool>(
          future: _isListDownloadedOffline(list['listName'] ?? ''),
          builder: (context, snapshot) {
            final isDownloaded = snapshot.data ?? false;
            final isDownloading = _downloadingListName == list['listName'];
            final translationCount = (list['translations'] as List?)?.length ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
                elevation: isDarkMode ? 2 : 4,
                borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
                  onTap: () {
                    final translations = List<Map<String, dynamic>>.from(list['translations']);
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => ListTranslationsPage(
                        listName: list['listName'] ?? '',
                        translations: translations,
                        isDarkMode: isDarkMode,
                      ),
                    ));
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF82B366).withOpacity(0.8),
                                const Color(0xFF82B366),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.folder_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                              Text(
                                list['listName'] ?? '',
                              style: TextStyle(
                                  fontSize: 18,
                                fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$translationCount traducciones',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                        ),
                        if (isDownloading)
                          Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              value: _downloadListProgress,
                              strokeWidth: 3,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF82B366),
                              ),
                            ),
                          )
                        else if (isDownloaded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                        ),
                        decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Descargado',
                          style: TextStyle(
                                    fontSize: 13,
                            fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.download_rounded, size: 20),
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                              padding: EdgeInsets.zero,
                              tooltip: 'Descargar para uso sin conexión',
                            onPressed: () {
                                _downloadListOffline(
                                  list['listName'] ?? '',
                                  List<Map<String, dynamic>>.from(list['translations']),
                                  setState,
                                );
                              },
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
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
        )),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _createNewListDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Crear nueva lista',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF82B366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 3. Updated dialogs with modern styling
  Future<void> _showModernDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> actions,
    IconData? icon,
    Color? iconColor,
  }) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: (iconColor ?? const Color(0xFF82B366)).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: iconColor ?? const Color(0xFF82B366),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              content,
              const SizedBox(height: 24),
              Row(
                children: actions.map((action) => 
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: actions.indexOf(action) > 0 ? 6 : 0,
                      ),
                      child: action,
                    ),
                  ),
                ).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required String title,
    required String hint,
    required TextEditingController controller,
    required Color color,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: 2,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
              ),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: color,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputSection({
    required String title,
    required TextEditingController controller,
    required Color color,
    required bool isDarkMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            readOnly: true,
            maxLines: 2,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'La traducción aparecerá aquí...',
              hintStyle: TextStyle(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
              filled: true,
              fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[50],
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Add a new page for showing translations in a list
class ListTranslationsPage extends StatelessWidget {
  final String listName;
  final List<Map<String, dynamic>> translations;
  final bool isDarkMode;
  const ListTranslationsPage({required this.listName, required this.translations, required this.isDarkMode, super.key});

  Future<void> _playAudio(BuildContext context, String listName, String english) async {
    // Add web check for audio playback
    if (kIsWeb) {
      // On web, directly use TTS service
      await playEnglishTTS(english, context: context);
      return;
    }
    
    // Original mobile/desktop logic
    final appDocDir = await getApplicationDocumentsDirectory();
    final safeName = english.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final filePath = '${appDocDir.path}/offline_list_audio/${listName}_$safeName.mp3';
    print('[LIST AUDIO PLAYBACK] listName: $listName, safeName: $safeName, filePath: $filePath');
    final file = File(filePath);
    if (await file.exists()) {
      final player = AudioPlayer();
      await player.play(DeviceFileSource(file.path));
    } else {
      print('[LIST AUDIO PLAYBACK] File not found: $filePath');
      await playEnglishTTS(english, context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(listName),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      body: translations.isEmpty
          ? Center(child: Text('No hay traducciones en esta lista.'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: translations.map((translation) => _buildTranslationCardList(context, translation, isDarkMode)).toList(),
            ),
    );
  }

  Widget _buildTranslationCardList(BuildContext context, Map<String, dynamic> translation, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Achuar title and text
                const Text(
                  'Achuar:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B5B95),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  translation['achuar'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                // English title and text (below title)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'English:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            translation['english'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 20),
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          final englishText = translation['english'] as String?;
                          if (englishText == null || englishText.isEmpty) return;
                          
                          // Add web check for audio playback
                          if (kIsWeb) {
                            // On web, directly use TTS service
                            await playEnglishTTS(englishText, context: context);
                            return;
                          }
                          
                          // Original mobile/desktop logic
                          final appDocDir = await getApplicationDocumentsDirectory();
                          final safeName = englishText.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
                          final filePath = '${appDocDir.path}/offline_list_audio/${listName}_$safeName.mp3';
                          final file = File(filePath);
                          final connectivity = await Connectivity().checkConnectivity();
                          final isOffline = connectivity == ConnectivityResult.none;
                          if (await file.exists()) {
                            final player = AudioPlayer();
                            await player.play(DeviceFileSource(file.path));
                          } else if (isOffline) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Solo se puede reproducir audio sin conexión para traducciones descargadas.')),
                            );
                          } else {
                            await playEnglishTTS(englishText, context: context);
                          }
                        },
                        tooltip: 'Play English audio',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}