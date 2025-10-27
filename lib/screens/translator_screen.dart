import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:translator/translator.dart';
import 'package:achuar_ingis/services/sync_service.dart';
import 'package:achuar_ingis/services/tts_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'package:achuar_ingis/theme/app_theme.dart';
import 'package:achuar_ingis/widgets/app_card.dart';
import 'package:achuar_ingis/widgets/app_button.dart';

import 'package:achuar_ingis/widgets/info_banner.dart';
import 'package:achuar_ingis/widgets/section_header.dart';
import 'package:achuar_ingis/services/language_service.dart';
import 'package:achuar_ingis/l10n/app_localizations.dart';

// Extension to provide missing BCP-47 language codes
extension TranslateLanguageExtension on TranslateLanguage {
  String get bcp47Code {
    switch (this) {
      case TranslateLanguage.spanish:
        return 'es';
      case TranslateLanguage.english:
        return 'en';
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
  // Controllers
  final _achuarTextController = TextEditingController();
  final _sourceTextController = TextEditingController();
  final _translatedTextController = TextEditingController();
  OnDeviceTranslator? _onDeviceTranslator;
  late TabController _tabController;
  
  // State variables
  bool _modelsDownloaded = false;
  bool _isDownloading = false;
  bool _isTranslating = false;
  bool _isSubmitting = false;
  bool _isConnected = false;
  bool _isGuestMode = false;
  List<Map<String, dynamic>> _recentTranslations = [];
  List<Map<String, dynamic>> _userLists = [];
  bool _loadingLists = true;
  String? _username;
  String? _downloadingListName;
  double _downloadListProgress = 0.0;
  double _modelDownloadProgress = 0.0;
  StreamSubscription<dynamic>? _connectivitySubscription;
  
  // Constants
  static const int _maxRecentTranslations = 20;
  
  String get _currentUserId => _username ?? '';

  @override
  void initState() {
    super.initState();
    _checkGuestModeAndInitialize();
    _setupTextListeners();
  }
  
  Future<void> _checkGuestModeAndInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    final isGuestMode = prefs.getBool('guest_mode') ?? false;
    
    setState(() {
      _isGuestMode = isGuestMode;
      _tabController = TabController(length: isGuestMode ? 1 : 2, vsync: this);
    });

    // Initialize on-device translator for non-web platforms
    if (!kIsWeb) {
      _onDeviceTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.spanish,
        targetLanguage: TranslateLanguage.english,
      );
      _checkModels();
    }
    
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _restoreModelDownloadState();
    await _initConnectivity();
    await _loadUsernameAndTranslations();
    await _loadUserLists();
  }

  void _setupTextListeners() {
    _achuarTextController.addListener(_onTextChanged);
    _sourceTextController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    if (!kIsWeb && _onDeviceTranslator != null) {
      _onDeviceTranslator!.close();
    }
    _achuarTextController.removeListener(_onTextChanged);
    _sourceTextController.removeListener(_onTextChanged);
    _achuarTextController.dispose();
    _sourceTextController.dispose();
    _translatedTextController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  // Connectivity Management
  Future<void> _initConnectivity() async {
    try {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
      
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
          _updateConnectionStatus(result);
        }
      });
    } catch (e) {
      print('[CONNECTIVITY] Error initializing connectivity: $e');
      if (mounted) {
        setState(() => _isConnected = true);
      }
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    try {
    if (mounted) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
      }
    } catch (e) {
      print('[CONNECTIVITY] Error updating connection status: $e');
    }
  }

  // Data Loading
  Future<void> _loadUsernameAndTranslations() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    
    setState(() {
      _username = username;
    });
    
    if (username != null && username.isNotEmpty) {
      await _fetchRecentTranslations(username);
    }
  }

  Future<void> _fetchRecentTranslations(String username) async {
    
    try {
    final query = await FirebaseFirestore.instance
        .collection('achuar_submission')
        .where('user', isEqualTo: username)
        .orderBy('timestamp', descending: true)
        .limit(_maxRecentTranslations)
        .get();
      
    setState(() {
      _recentTranslations = query.docs.map((doc) {
          final data = doc.data();
        if (data['timestamp'] is Timestamp) {
          data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();
    });
    } catch (e) {
      print('[RECENT] Error fetching recent translations: $e');
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('network')) {
        await _loadRecentTranslationsFromLocal();
      } else {
        _showErrorSnackBar('Error al cargar traducciones recientes');
      }
    }
  }

  Future<void> _loadRecentTranslationsFromLocal() async {
    try {
    final prefs = await SharedPreferences.getInstance();
      final recentJson = prefs.getStringList('recentTranslations') ?? [];
      
      setState(() {
        _recentTranslations = recentJson
            .map((json) => jsonDecode(json) as Map<String, dynamic>)
            .toList();
      });
      
      print('[RECENT] Loaded ${_recentTranslations.length} recent translations from local storage');
    } catch (e) {
      print('[RECENT] Error loading from local storage: $e');
      setState(() {
        _recentTranslations = [];
      });
    }
  }

  Future<void> _saveTranslations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentJson = _recentTranslations
          .map((translation) => jsonEncode(translation))
          .toList();
    
    await prefs.setStringList('recentTranslations', recentJson);
    } catch (e) {
      print('[RECENT] Error saving translations: $e');
    }
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

  // Model Management
  Future<void> _checkModels() async {
    try {
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
    } catch (e) {
      print('[MODELS] Error checking models: $e');
    }
  }

  Future<void> _restoreModelDownloadState() async {
    try {
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
    } catch (e) {
      print('[MODELS] Error restoring download state: $e');
    }
  }

  Future<void> _downloadModels() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      _showErrorSnackBar('Sin conexión. Conéctese a internet para descargar los modelos de traducción.');
      return;
    }

    if (_isDownloading || !mounted) return;

    setState(() {
      _isDownloading = true;
      _modelDownloadProgress = 0.0;
    });

    try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('translator_model_downloading', true);
    await prefs.setDouble('translator_model_download_progress', 0.0);

    final modelManager = OnDeviceTranslatorModelManager();
      
      final l10n = AppLocalizations.of(context);
      _showInfoSnackBar(
        l10n?.downloadingModelsStayOnPage ?? 'Downloading models... Please do not leave this page.',
        duration: const Duration(minutes: 2),
      );

      // Download Spanish model
    await modelManager.downloadModel(TranslateLanguage.spanish.bcp47Code);
      if (mounted) {
        setState(() => _modelDownloadProgress = 0.5);
    await prefs.setDouble('translator_model_download_progress', 0.5);
      }

      // Download English model
    await modelManager.downloadModel(TranslateLanguage.english.bcp47Code);
      if (mounted) {
        setState(() => _modelDownloadProgress = 1.0);
    await prefs.setDouble('translator_model_download_progress', 1.0);
      }

      _showSuccessSnackBar(l10n?.modelsDownloadedSuccessfully ?? 'Models downloaded successfully!');

      if (mounted) {
    setState(() {
      _isDownloading = false;
      _modelDownloadProgress = 0.0;
    });
      }

    await prefs.setBool('translator_model_downloading', false);
    await prefs.setDouble('translator_model_download_progress', 0.0);
      
      await _checkModels();
    } catch (e) {
      print('[MODELS] Error downloading models: $e');
      _showErrorSnackBar('Error al descargar modelos: $e');
      
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _modelDownloadProgress = 0.0;
        });
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

  // Enhanced translation with context and preprocessing
  Future<String> _performTranslation(String sourceText, {bool useContext = true}) async {
    // Preprocess the text
    final processedText = _preprocessText(sourceText);
    
    // Add context for better translation if it's a short phrase
    String contextualText = processedText;
    if (useContext && processedText.split(' ').length <= 3) {
      contextualText = 'Traducir al inglés: $processedText';
    }
    
    String translatedText;
    
    if (kIsWeb) {
      // Web platform - use Google Translator with enhanced settings
      final translator = GoogleTranslator();
      try {
        final translation = await translator.translate(contextualText, from: 'es', to: 'en');
        translatedText = translation.text;
        
        // Clean up context prefix if we added it
        if (useContext && contextualText != processedText) {
          translatedText = translatedText.replaceFirst(RegExp(r'^(Translate to English:\s*|Translate into English:\s*|Traducir al inglés:\s*)', caseSensitive: false), '');
        }
      } catch (e) {
        print('[TRANSLATE] Error with context, trying without: $e');
        // Fallback without context
        final translation = await translator.translate(processedText, from: 'es', to: 'en');
        translatedText = translation.text;
      }
    } else if (_modelsDownloaded && _onDeviceTranslator != null) {
      // Offline models available - use ML Kit translator
      print('[TRANSLATE] Using offline ML Kit translator');
      final translation = await _onDeviceTranslator!.translateText(contextualText);
      translatedText = translation;
      
      // Clean up context prefix if we added it
      if (useContext && contextualText != processedText) {
        translatedText = translatedText.replaceFirst(RegExp(r'^(Translate to English:\s*|Translate into English:\s*|Traducir al inglés:\s*)', caseSensitive: false), '');
      }
    } else if (_modelsDownloaded && _onDeviceTranslator == null) {
      // Models downloaded but translator not initialized (web platform)
      print('[TRANSLATE] Models downloaded but translator not available, using online fallback');
      final translator = GoogleTranslator();
      final translation = await translator.translate(contextualText, from: 'es', to: 'en');
      translatedText = translation.text;
      
      if (useContext && contextualText != processedText) {
        translatedText = translatedText.replaceFirst(RegExp(r'^(Translate to English:\s*|Traducir al inglés:\s*)', caseSensitive: false), '');
      }
    } else if (_isConnected) {
      // Online but no models - use Google Translator
      print('[TRANSLATE] Using online Google Translator');
      final translator = GoogleTranslator();
      final translation = await translator.translate(contextualText, from: 'es', to: 'en');
      translatedText = translation.text;
      
      if (useContext && contextualText != processedText) {
        translatedText = translatedText.replaceFirst(RegExp(r'^(Translate to English:\s*|Traducir al inglés:\s*)', caseSensitive: false), '');
      }
    } else {
      throw Exception('Sin conexión. Descargue los modelos o conéctese a internet.');
    }
    
    // Post-process the translation
    return _postprocessTranslation(translatedText, sourceText: sourceText);
  }

  // Post-processing for translation output
  String _postprocessTranslation(String translation, {String? sourceText}) {
    if (translation.isEmpty) return translation;
    
    String processed = translation.trim();
    
    // Check if the original source was a question
    final isQuestion = sourceText?.trim().endsWith('?') ?? false;
    
    // Remove extra whitespace
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove regex backreference artifacts like $1, $2, $ 1, $ 2, etc. (with or without spaces)
    processed = processed.replaceAll(RegExp(r'\$\s*\d+'), '');
    processed = processed.replaceAll(RegExp(r'\s+'), ' '); // Clean up extra spaces again
    
    // Remove any remaining context phrases (comprehensive cleanup)
    processed = processed.replaceAll(RegExp(r'^(Translate\s+(to|into)\s+English:\s*|Traducir\s+al\s+inglés:\s*)', caseSensitive: false), '');
    processed = processed.replaceAll(RegExp(r'^(Translation:\s*|Traducción:\s*)', caseSensitive: false), '');
    processed = processed.replaceAll(RegExp(r'^(English:\s*|Inglés:\s*)', caseSensitive: false), '');
    
    // Ensure proper capitalization
    if (processed.isNotEmpty) {
      processed = processed[0].toUpperCase() + processed.substring(1);
    }
    
    // Clean up common translation artifacts - FIXED: use non-capturing group and only match if "The " exists
    processed = processed.replaceAll(RegExp(r'^The\s+'), '');
    // Remove any ending punctuation
    processed = processed.replaceAll(RegExp(r'\s*[.!?]\s*$'), '');
    
    // If the original was a question, ensure the translation ends with a question mark
    if (isQuestion && !processed.endsWith('?')) {
      processed += '?';
    }
    
    return processed;
  }

  // Translation
  Future<void> _translateText() async {
    if (_achuarTextController.text.isEmpty || _sourceTextController.text.isEmpty) {
      _showErrorSnackBar('Por favor, ingrese texto en ambos campos.');
      return;
    }

    if (mounted) {
      setState(() {
        _isTranslating = true;
        _translatedTextController.text = '';
      });
    }

    try {
      final sourceText = _sourceTextController.text;
      final translatedText = await _performTranslation(sourceText);

      if (mounted) {
        setState(() {
          _translatedTextController.text = translatedText;
        });
        await _addToRecent(_achuarTextController.text, translatedText);
        await _submitToFirestore();
      }
    } catch (e) {
      print('[TRANSLATE] Error translating text: $e');
      _showErrorSnackBar('Error al traducir: $e');
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  Future<void> _submitToFirestore() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    try {
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
    
      await SyncService().addSubmission(submission);
    } catch (e) {
      print('[SUBMIT] Error submitting to Firestore: $e');
    } finally {
    if (mounted) {
        setState(() => _isSubmitting = false);
    }
  }
  }

  // List Management
  Future<void> _loadUserLists() async {
    setState(() => _loadingLists = true);
    
    if (_currentUserId.isEmpty) {
      setState(() {
        _userLists = [];
        _loadingLists = false;
      });
      return;
    }

    try {
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
    } catch (e) {
      print('[LISTS] Error loading user lists: $e');
      if (e.toString().contains('UNAVAILABLE') || e.toString().contains('network')) {
        await _loadUserListsFromLocal();
      } else {
        setState(() => _loadingLists = false);
        _showErrorSnackBar('Error al cargar las listas');
      }
    }
  }

  Future<void> _loadUserListsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listsJson = prefs.getString('local_user_lists');
      
      if (listsJson != null) {
        final lists = jsonDecode(listsJson) as List;
        setState(() {
          _userLists = lists.cast<Map<String, dynamic>>();
          _loadingLists = false;
        });
        print('[LISTS] Loaded ${_userLists.length} lists from local storage');
      } else {
        setState(() {
          _userLists = [];
          _loadingLists = false;
        });
      }
    } catch (e) {
      print('[LISTS] Error loading from local storage: $e');
      setState(() {
        _userLists = [];
        _loadingLists = false;
      });
    }
  }

  Future<void> _saveList(String listName, List<Map<String, dynamic>> translations) async {
    if (_currentUserId.isEmpty) return;

    print('[LISTS] Saving list: $listName');

    try {
      // Save locally first
      final prefs = await SharedPreferences.getInstance();
      final currentLists = List<Map<String, dynamic>>.from(_userLists);
      
      final existingIndex = currentLists.indexWhere((list) => list['listName'] == listName);
      final listData = {
      'userId': _currentUserId,
      'listName': listName,
      'translations': translations,
      };
      
      if (existingIndex >= 0) {
        // If updating an existing list, clear the download flag 
        // since new translations may not have downloaded audio
        await prefs.setBool('offline_list_${listName}_downloaded', false);
        currentLists[existingIndex] = listData;
      } else {
        currentLists.add(listData);
      }
      
      await prefs.setString('local_user_lists', jsonEncode(currentLists));
      
      // Update UI immediately
      if (mounted) {
        setState(() => _userLists = currentLists);
      }

      // Try to save to Firestore if online
      if (_isConnected) {
        final docId = '${_currentUserId}_$listName';
        await FirebaseFirestore.instance
            .collection('custom_lists')
            .doc(docId)
            .set(listData);
        print('[LISTS] Saved to Firestore: $listName');
      }
    } catch (e) {
      print('[LISTS] Error saving list: $e');
      _showErrorSnackBar('Error al guardar la lista');
    }
  }

  Future<void> _deleteList(String listName) async {
    print('[LISTS] Deleting list: $listName');

    try {
      // Remove from local storage
      final prefs = await SharedPreferences.getInstance();
      final currentLists = List<Map<String, dynamic>>.from(_userLists);
      currentLists.removeWhere((list) => list['listName'] == listName);
      
      await prefs.setString('local_user_lists', jsonEncode(currentLists));
      
      // Update UI immediately
      if (mounted) {
        setState(() => _userLists = currentLists);
      }

      // Try to delete from Firestore if online
      if (_isConnected) {
        final docId = '${_currentUserId}_$listName';
        await FirebaseFirestore.instance
            .collection('custom_lists')
            .doc(docId)
            .delete();
        print('[LISTS] Deleted from Firestore: $listName');
      }

      // Clean up offline files if not on web
      if (!kIsWeb) {
        await _cleanupOfflineFiles(listName);
      }

      _showSuccessSnackBar('Lista "$listName" eliminada.');
    } catch (e) {
      print('[LISTS] Error deleting list: $e');
      _showErrorSnackBar('Error al eliminar la lista');
    }
  }

  Future<void> _cleanupOfflineFiles(String listName) async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDocDir.path}/offline_list_audio');
      
      if (audioDir.existsSync()) {
        final files = audioDir.listSync();
        final safeListName = listName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        
        for (final file in files) {
          if (file is File && file.path.contains(safeListName)) {
            await file.delete();
            print('[LISTS] Deleted audio file: ${file.path}');
          }
        }
      }

      // Clear download flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('offline_list_${listName}_downloaded', false);
    } catch (e) {
      print('[LISTS] Error cleaning up offline files: $e');
    }
  }

  // Download Management
  Future<bool> _isListDownloadedOffline(String listName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isMarkedAsDownloaded = prefs.getBool('offline_list_${listName}_downloaded') ?? false;
      
      if (!isMarkedAsDownloaded || kIsWeb) {
        return false;
      }

      // Validate that files actually exist
      final appDocDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDocDir.path}/offline_list_audio');
      
      if (!audioDir.existsSync()) {
        await prefs.setBool('offline_list_${listName}_downloaded', false);
        return false;
      }

      final safeListName = listName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final files = audioDir.listSync();
      final hasFiles = files.any((file) => 
        file is File && file.path.contains(safeListName)
      );

      if (!hasFiles) {
        await prefs.setBool('offline_list_${listName}_downloaded', false);
        return false;
      }

      return true;
    } catch (e) {
      print('[OFFLINE] Error checking if list is downloaded: $e');
      return false;
    }
  }

  Future<void> _downloadListOffline(String listName, List<Map<String, dynamic>> translations) async {
    if (!_isConnected) {
      _showErrorSnackBar('Sin conexión. Conéctese a internet para descargar la lista.');
      return;
    }

    setState(() {
      _downloadingListName = listName;
      _downloadListProgress = 0.0;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save translations data locally
      await prefs.setString('offline_list_$listName', jsonEncode(translations));

      // On web, just mark as downloaded without downloading audio files
      if (kIsWeb) {
        await prefs.setBool('offline_list_${listName}_downloaded', true);
        _showSuccessSnackBar('Lista guardada para uso offline.');
        return;
      }

      // Download TTS audio for mobile/desktop
      await _downloadListAudio(listName, translations);
      
    } catch (e) {
      print('[DOWNLOAD] Error downloading list: $e');
      _showErrorSnackBar('Error al descargar la lista');
    } finally {
      setState(() {
        _downloadingListName = null;
        _downloadListProgress = 0.0;
      });
    }
  }

  Future<void> _downloadListAudio(String listName, List<Map<String, dynamic>> translations) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${appDocDir.path}/offline_list_audio');
    
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }

    int completed = 0;
    int successfulDownloads = 0;
    final List<String> failedDownloads = [];

    for (final translation in translations) {
      final english = translation['english'] as String?;
      if (english != null && english.isNotEmpty) {
        final safeName = english.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final safeListName = listName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final filePath = '${audioDir.path}/${safeListName}_$safeName.mp3';
        final file = File(filePath);
        
        if (!file.existsSync()) {
          try {
            final path = await downloadAndSaveEnglishTTS(
              english,
              filename: '${safeListName}_$safeName',
              forList: true,
            );
            
            if (path != null) {
              successfulDownloads++;
              print('[DOWNLOAD] Downloaded: $filePath');
            } else {
              failedDownloads.add(english);
            }
          } catch (e) {
            print('[DOWNLOAD] Failed to download $english: $e');
            failedDownloads.add(english);
          }
        } else {
          successfulDownloads++;
        }
      }
      
      completed++;
      setState(() {
        _downloadListProgress = completed / translations.length;
      });
      
      // Yield to UI
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Mark as downloaded if we have at least some successful downloads
    if (successfulDownloads > 0) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('offline_list_${listName}_downloaded', true);
      
      if (failedDownloads.isEmpty) {
        final l10n = AppLocalizations.of(context);
        _showSuccessSnackBar(l10n?.listDownloadedSuccessfully ?? 'List downloaded successfully.');
      } else {
        final l10n = AppLocalizations.of(context);
        _showWarningSnackBar(l10n?.listDownloadedWithErrors(failedDownloads.length) ?? 'List downloaded with ${failedDownloads.length} errors.');
      }
    } else {
      final l10n = AppLocalizations.of(context);
      _showErrorSnackBar(l10n?.couldNotDownloadAnyAudio ?? 'Could not download any audio.');
    }
  }

  // Audio Playback
  Future<void> _playTranslationAudio(String english, {String? listName}) async {
    try {
      // On web, use TTS service directly
      if (kIsWeb) {
        await playEnglishTTS(english, context: context);
        return;
      }

      // Try offline file first
      final appDocDir = await getApplicationDocumentsDirectory();
      final safeName = english.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      
      String filePath;
      if (listName != null) {
        final safeListName = listName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        filePath = '${appDocDir.path}/offline_list_audio/${safeListName}_$safeName.mp3';
      } else {
        filePath = '${appDocDir.path}/offline_list_audio/recents_$safeName.mp3';
      }
      
      final file = File(filePath);
      
      if (await file.exists()) {
        final player = AudioPlayer();
        await player.setVolume(1.0); // Set volume to maximum
        await player.play(DeviceFileSource(file.path));
        return;
      }

      // Fall back to online TTS if connected
      if (_isConnected) {
        await playEnglishTTS(english, context: context);
      } else {
        _showWarningSnackBar(AppLocalizations.of(context)?.audioNotAvailableOfflineShort ?? 'Audio no disponible sin conexión.');
      }
    } catch (e) {
      print('[AUDIO] Error playing audio: $e');
      _showErrorSnackBar('Error al reproducir audio');
    }
  }

  // UI Helpers
  void _clearAll() {
    _achuarTextController.clear();
    _sourceTextController.clear();
    _translatedTextController.clear();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showWarningSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showInfoSnackBar(String message, {Duration? duration}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
          duration: duration ?? const Duration(seconds: 4),
        ),
      );
    }
  }

  // Dialog Management
  Future<void> _addToListDialog(Map<String, dynamic> translation) async {
    String? selectedList;
    String? newListName;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final l10n = AppLocalizations.of(context);
    await _showModernDialog(
      context: context,
      title: l10n?.addToList ?? 'Add to list',
      icon: Icons.playlist_add_rounded,
      iconColor: theme.colorScheme.secondary,
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
              if (_userLists.isNotEmpty) ...[
                Text(l10n?.selectExistingList ?? 'Select an existing list:', 
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
            DropdownButton<String>(
              value: selectedList,
              hint: Text(l10n?.selectList ?? 'Select a list'),
              items: _userLists.map((list) => DropdownMenuItem<String>(
                value: list['listName'],
                child: Text(list['listName']),
              )).toList(),
                  onChanged: (val) {
                    setDialogState(() {
                      selectedList = val;
                      newListName = null;
                    });
                  },
              isExpanded: true,
            ),
          const SizedBox(height: 16),
                Text(l10n?.orCreateNewList ?? 'Or create a new list:', 
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
              ],
          TextField(
            decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.createNewList ?? 'Crear nueva lista...',
              filled: true,
                  fillColor: isDarkMode 
                    ? Colors.white.withOpacity(0.04) 
                    : Colors.grey.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 15,
            ),
                onChanged: (val) {
                  setDialogState(() {
                    newListName = val;
                    selectedList = null;
                  });
                },
              ),
            ],
          );
        },
      ),
      actions: [
        _buildDialogButton(
          text: l10n?.cancel ?? 'Cancel',
                onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        _buildDialogButton(
          text: l10n?.add ?? 'Add',
                onPressed: () async {
            Navigator.pop(context);
            await _handleAddToList(translation, selectedList, newListName);
          },
          isPrimary: true,
        ),
      ],
    );
  }

  Future<void> _handleAddToList(
    Map<String, dynamic> translation, 
    String? selectedList, 
    String? newListName
  ) async {
    try {
      if (newListName != null && newListName.trim().isNotEmpty) {
        final trimmedName = newListName.trim();
        if (_userLists.any((l) => l['listName'] == trimmedName)) {
          final l10n = AppLocalizations.of(context);
          _showErrorSnackBar(l10n?.listNameAlreadyExists ?? 'A list with that name already exists.');
                      return;
                    }
        await _saveList(trimmedName, [translation]);
        final l10n = AppLocalizations.of(context);
        _showSuccessSnackBar(l10n?.listCreated(trimmedName) ?? 'List "$trimmedName" created.');
                  } else if (selectedList != null) {
                    final list = _userLists.firstWhere((l) => l['listName'] == selectedList);
                    final translations = List<Map<String, dynamic>>.from(list['translations']);
        
        if (translations.any((t) => 
          t['achuar'] == translation['achuar'] && t['english'] == translation['english'])) {
          _showErrorSnackBar('Esta traducción ya está en la lista.');
                      return;
                    }
        
                    translations.add(translation);
        await _saveList(selectedList, translations);
        _showSuccessSnackBar('Agregado a "$selectedList".');
      } else {
        _showErrorSnackBar('Por favor selecciona una lista o crea una nueva.');
      }
    } catch (e) {
      print('[DIALOG] Error adding to list: $e');
      _showErrorSnackBar('Error al agregar a la lista.');
    }
  }

  Future<void> _createNewListDialog() async {
    String? newListName;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    
    await _showModernDialog(
      context: context,
      title: l10n?.createNewList ?? 'Crear nueva lista',
      icon: Icons.create_new_folder_rounded,
      iconColor: theme.colorScheme.secondary,
      content: TextField(
        decoration: InputDecoration(
          labelText: l10n?.listName ?? 'Nombre de la lista',
          filled: true,
          fillColor: isDarkMode 
            ? Colors.white.withOpacity(0.04) 
            : Colors.grey.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.colorScheme.secondary, width: 2),
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
        _buildDialogButton(
          text: l10n?.cancel ?? 'Cancel',
                onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        _buildDialogButton(
          text: l10n?.create ?? 'Create',
                onPressed: () async {
                  if (newListName != null && newListName!.trim().isNotEmpty) {
              final trimmedName = newListName!.trim();
              if (_userLists.any((l) => l['listName'] == trimmedName)) {
                final l10n = AppLocalizations.of(context);
                _showErrorSnackBar(l10n?.listNameAlreadyExists ?? 'A list with that name already exists.');
                      return;
                    }
                    Navigator.pop(context);
              await _saveList(trimmedName, []);
              final l10n = AppLocalizations.of(context);
              _showSuccessSnackBar(l10n?.listCreated(trimmedName) ?? 'List "$trimmedName" created.');
            } else {
              final l10n = AppLocalizations.of(context);
              _showErrorSnackBar(l10n?.pleaseEnterListName ?? 'Please enter a name for the list.');
            }
          },
          isPrimary: true,
        ),
      ],
    );
  }

  Future<void> _deleteListDialog(String listName) async {
    final theme = Theme.of(context);
    
    final l10n = AppLocalizations.of(context);
    await _showModernDialog(
      context: context,
      title: l10n?.deleteListTitle ?? 'Delete list',
      icon: Icons.delete_forever_rounded,
      iconColor: Colors.red,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n?.areYouSureDeleteList ?? 'Are you sure you want to delete this list?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            '"$listName"',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Esta acción no se puede deshacer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        _buildDialogButton(
          text: l10n?.cancel ?? 'Cancel',
          onPressed: () => Navigator.pop(context),
          isPrimary: false,
        ),
        _buildDialogButton(
          text: l10n?.delete ?? 'Delete',
          onPressed: () async {
            Navigator.pop(context);
            await _deleteList(listName);
          },
          isPrimary: true,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildDialogButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.secondary;
    
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(left: isPrimary ? 6 : 0),
        child: isPrimary 
          ? ElevatedButton(
              onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              child: Text(text),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: buttonColor,
                side: BorderSide(color: buttonColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
      ),
    );
  }

  void _showInfoDialog() {
    final l10n = AppLocalizations.of(context);
    _showModernDialog(
      context: context,
      title: l10n?.aboutTranslator ?? 'Acerca del Traductor',
      icon: Icons.translate_rounded,
      iconColor: Theme.of(context).colorScheme.secondary,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n?.translatorDescription ?? 'Este es un traductor de Español a Inglés que te ayuda a traducir palabras y frases.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.howYouHelp ?? '¿Cómo nos ayudas?',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n?.helpDescription ?? 'Al agregar la traducción en Achuar, nos estás proporcionando datos valiosos que nos ayudan a construir un traductor directo de Achuar a Inglés.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n?.contributionMessage ?? 'Cada traducción que compartes contribuye a preservar y digitalizar el idioma Achuar. ¡Gracias por tu colaboración!',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _buildDialogButton(
          text: l10n?.understood ?? 'Entendido',
          onPressed: () => Navigator.of(context).pop(),
          isPrimary: true,
        ),
      ],
    );
  }

  Future<void> _showModernDialog({
    required BuildContext context,
    required String title,
    required Widget content,
    required List<Widget> actions,
    IconData? icon,
    Color? iconColor,
  }) async {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    color: (iconColor ?? theme.colorScheme.secondary).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: iconColor ?? theme.colorScheme.secondary,
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
              Row(children: actions),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final canTranslate = kIsWeb
      ? _achuarTextController.text.isNotEmpty && _sourceTextController.text.isNotEmpty
      : (_modelsDownloaded || _isConnected);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: LanguageService(),
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            return Text(l10n?.translatorTitle ?? 'Traductor Español-Achuar');
          },
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: _showInfoDialog,
            tooltip: 'Información sobre el traductor',
          ),
          if (_achuarTextController.text.isNotEmpty || 
              _sourceTextController.text.isNotEmpty || 
              _translatedTextController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              onPressed: _clearAll,
              tooltip: 'Limpiar todo',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.secondary,
          labelColor: theme.colorScheme.secondary,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          indicatorWeight: 3,
          tabs: [
            AnimatedBuilder(
              animation: LanguageService(),
              builder: (context, child) {
                final l10n = AppLocalizations.of(context);
                return Tab(text: l10n?.translator ?? 'Traductor');
              },
            ),
            if (!_isGuestMode)
              AnimatedBuilder(
                animation: LanguageService(),
                builder: (context, child) {
                  final l10n = AppLocalizations.of(context);
                  return Tab(text: l10n?.lists ?? 'Listas');
                },
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTranslatorTab(isDarkMode, canTranslate),
          if (!_isGuestMode)
            _buildListsTab(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildTranslatorTab(bool isDarkMode, bool canTranslate) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: LanguageService(),
              builder: (context, child) {
                final l10n = AppLocalizations.of(context);
                return _buildInputSection(
                  title: 'Achuar',
                  hint: l10n?.enterAchuarText ?? 'Ingrese texto en Achuar...',
                  controller: _achuarTextController,
                  color: AppTheme.primaryColor,
                  theme: theme,
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            AnimatedBuilder(
              animation: LanguageService(),
              builder: (context, child) {
                final l10n = AppLocalizations.of(context);
                return _buildInputSection(
                  title: l10n?.spanish ?? 'Español',
                  hint: l10n?.enterSpanishText ?? 'Ingrese texto en español...',
                  controller: _sourceTextController,
                  color: AppTheme.secondaryColor,
                  theme: theme,
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            _buildTranslateButton(canTranslate),
            const SizedBox(height: AppTheme.spacingMedium),
            AnimatedBuilder(
              animation: LanguageService(),
              builder: (context, child) {
                final l10n = AppLocalizations.of(context);
                return _buildOutputSection(
                  title: l10n?.english ?? 'Inglés',
                  controller: _translatedTextController,
                  color: AppTheme.accentColor,
                  theme: theme,
                  hintText: l10n?.translationWillAppearHere ?? 'La traducción aparecerá aquí...',
                );
              },
            ),
            if (!kIsWeb && !_modelsDownloaded) ...[
              const SizedBox(height: AppTheme.spacingLarge),
              _buildModelDownloadSection(theme),
            ],
            if (_recentTranslations.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingXLarge),
              _buildRecentTranslationsSection(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTranslateButton(bool canTranslate) {
    return AnimatedBuilder(
      animation: LanguageService(),
      builder: (context, child) {
        final l10n = AppLocalizations.of(context);
        return AppButton(
          label: l10n?.translateButton ?? 'Traducir a Inglés',
          onPressed: canTranslate ? _translateText : null,
          isLoading: _isTranslating || _isSubmitting,
          fullWidth: true,
          size: AppButtonSize.large,
          backgroundColor: AppTheme.infoColor,
        );
      },
    );
  }

  Widget _buildModelDownloadSection(ThemeData theme) {
    return InfoBanner(
      title: 'Modelos de traducción offline',
      message: _isDownloading
          ? 'Descargando modelos... ${(_modelDownloadProgress * 100).toInt()}%'
          : 'Descarga los modelos para traducir sin conexión a internet',
      type: InfoBannerType.warning,
      action: _isDownloading
          ? Column(
              children: [
                const SizedBox(height: AppTheme.spacingSmall),
                LinearProgressIndicator(
                  value: _modelDownloadProgress,
                  minHeight: 8,
                  backgroundColor: AppTheme.warningColor.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warningColor),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ],
            )
          : AppButton(
              label: _isConnected ? 'Descargar modelos' : 'Sin conexión',
              icon: Icons.download_rounded,
              onPressed: _isConnected ? _downloadModels : null,
              type: AppButtonType.primary,
              size: AppButtonSize.medium,
              fullWidth: true,
            ),
    );
  }

  Widget _buildRecentTranslationsSection(ThemeData theme) {
    return AnimatedBuilder(
      animation: LanguageService(),
      builder: (context, child) {
        final l10n = AppLocalizations.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: l10n?.recentTranslations ?? 'Traducciones recientes',
              icon: Icons.history_rounded,
            ),
            ..._recentTranslations.map((translation) => 
              _buildTranslationCard(translation, theme)
            ),
          ],
        );
      },
    );
  }

  Widget _buildTranslationCard(Map<String, dynamic> translation, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: AppCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSmall,
                          vertical: AppTheme.spacingXSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          'Achuar',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSmall),
                      Text(
                        translation['achuar'] ?? '',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                _buildActionButton(
                  icon: Icons.playlist_add_rounded,
                  color: theme.colorScheme.secondary,
                  onPressed: () => _addToListDialog(translation),
                  tooltip: 'Agregar a lista',
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSmall,
                          vertical: AppTheme.spacingXSmall,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.infoColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: Text(
                          'English',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppTheme.infoColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSmall),
                      Text(
                        translation['english'] ?? '',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSmall),
                _buildActionButton(
                  icon: Icons.volume_up_rounded,
                  color: AppTheme.infoColor,
                  onPressed: () => _playTranslationAudio(translation['english'] ?? ''),
                  tooltip: 'Reproducir audio',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
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

  Widget _buildListsTab(bool isDarkMode) {
    final theme = Theme.of(context);
    
    if (_loadingLists) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.secondary)
      );
    }

    if (_userLists.isEmpty) {
      return _buildEmptyListsState(isDarkMode);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ..._userLists.map((list) => _buildListCard(list, isDarkMode)),
        const SizedBox(height: 20),
        _buildCreateListButton(),
      ],
    );
  }

  Widget _buildEmptyListsState(bool isDarkMode) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_outlined,
                size: 56,
                color: theme.colorScheme.secondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              'No hay listas creadas',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              'Crea listas personalizadas para organizar\ntus traducciones favoritas',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodySmall?.color,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacingXLarge),
            _buildCreateListButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateListButton() {
    return AppButton(
      label: AppLocalizations.of(context)?.createNewList ?? 'Crear nueva lista',
      icon: Icons.add_rounded,
      onPressed: _createNewListDialog,
      fullWidth: true,
      size: AppButtonSize.large,
      backgroundColor: AppTheme.accentColor,
    );
  }

  Widget _buildListCard(Map<String, dynamic> list, bool isDarkMode) {
    final theme = Theme.of(context);
    final listName = list['listName'] ?? '';
    final translations = list['translations'] as List? ?? [];
    final translationCount = translations.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: FutureBuilder<bool>(
        future: _isListDownloadedOffline(listName),
        builder: (context, snapshot) {
          final isDownloaded = snapshot.data ?? false;
          final isDownloading = _downloadingListName == listName;

          return AppCard(
            onTap: () => _navigateToListDetail(listName, translations, isDarkMode),
            padding: const EdgeInsets.all(AppTheme.spacingMedium),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.secondary.withOpacity(0.8),
                        theme.colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        listName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppTheme.spacingXSmall),
                      Text(
                        '$translationCount ${translationCount == 1 ? 'traducción' : 'traducciones'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildListActions(listName, translations, isDownloaded, isDownloading),
                const SizedBox(width: AppTheme.spacingSmall),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.textTheme.bodySmall?.color,
                  size: 18,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildListActions(
    String listName, 
    List translations, 
    bool isDownloaded, 
    bool isDownloading
  ) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
                        // Hide download/offline features on web
                        if (!kIsWeb) ...[
                          if (isDownloading)
                            Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(6),
                              child: CircularProgressIndicator(
                                value: _downloadListProgress,
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.secondary),
                              ),
                            )
                          else if (isDownloaded)
                        Container(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingSmall, vertical: AppTheme.spacingXSmall),
                          decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 16,
                                    color: AppTheme.successColor,
                                  ),
                  const SizedBox(width: AppTheme.spacingXSmall),
                                  Text(
                    'Offline',
                            style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.successColor,
                              fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
            _buildActionButton(
              icon: Icons.download_rounded,
              color: _isConnected ? theme.colorScheme.secondary : theme.textTheme.bodySmall?.color ?? Colors.grey,
              onPressed: _isConnected 
                ? () => _downloadListOffline(listName, List<Map<String, dynamic>>.from(translations))
                : () => _showWarningSnackBar('Sin conexión'),
              tooltip: _isConnected 
                ? 'Descargar para uso offline'
                : 'Sin conexión',
                            ),
                          const SizedBox(width: AppTheme.spacingSmall),
                        ],
        _buildActionButton(
          icon: Icons.delete_rounded,
          color: AppTheme.errorColor,
          onPressed: () => _deleteListDialog(listName),
          tooltip: 'Eliminar lista',
        ),
      ],
    );
  }

  void _navigateToListDetail(String listName, List translations, bool isDarkMode) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ListTranslationsPage(
          listName: listName,
          translations: List<Map<String, dynamic>>.from(translations),
          isDarkMode: isDarkMode,
          onPlayAudio: _playTranslationAudio,
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required String title,
    required String hint,
    required TextEditingController controller,
    required Color color,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.all(AppTheme.spacingMedium),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                borderSide: BorderSide(
                  color: theme.dividerTheme.color ?? AppTheme.dividerColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
    required ThemeData theme,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppTheme.spacingSmall),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: hintText ?? 'La traducción aparecerá aquí...',
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.all(AppTheme.spacingMedium),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                borderSide: BorderSide(
                  color: theme.dividerTheme.color ?? AppTheme.dividerColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
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
}

// Improved ListTranslationsPage with better styling and functionality
class ListTranslationsPage extends StatelessWidget {
  final String listName;
  final List<Map<String, dynamic>> translations;
  final bool isDarkMode;
  final Function(String, {String? listName}) onPlayAudio;

  const ListTranslationsPage({
    required this.listName,
    required this.translations,
    required this.isDarkMode,
    required this.onPlayAudio,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          listName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
          ),
        ),
      ),
      body: translations.isEmpty
          ? _buildEmptyState(context)
          : _buildTranslationsList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.translate_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lista vacía',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No hay traducciones en esta lista aún.\nAgrega traducciones desde el traductor.',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
            ),
    );
  }

  Widget _buildTranslationsList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: translations.length,
      itemBuilder: (context, index) {
        return _buildTranslationCard(context, translations[index], index);
      },
    );
  }

  Widget _buildTranslationCard(BuildContext context, Map<String, dynamic> translation, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: isDarkMode ? 1 : 2,
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.08),
          child: Padding(
          padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header with index
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF82B366).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF82B366),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              // Achuar text
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text(
                    'Achuar',
                  style: TextStyle(
                      fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B5B95),
                      letterSpacing: 0.5,
                  ),
                ),
                  const SizedBox(height: 6),
                Text(
                  translation['achuar'] ?? '',
                  style: TextStyle(
                    fontSize: 16,
                      fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // English text with audio button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                          'English',
                            style: TextStyle(
                            fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            letterSpacing: 0.5,
                            ),
                          ),
                        const SizedBox(height: 6),
                          Text(
                            translation['english'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                            fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 12),
                    Container(
                    width: 40,
                    height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.volume_up_rounded, size: 20),
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                      onPressed: () {
                          final englishText = translation['english'] as String?;
                        if (englishText != null && englishText.isNotEmpty) {
                          onPlayAudio(englishText, listName: listName);
                        }
                      },
                      tooltip: 'Reproducir audio',
                      ),
                    ),
                  ],
                ),
              ],
          ),
        ),
      ),
    );
  }
}