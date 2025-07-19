import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:translator/translator.dart';
import 'package:myapp/services/sync_service.dart';

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
  
  bool _isWeb = false;
  bool _modelsDownloaded = false;
  bool _isDownloading = false;
  bool _isTranslating = false;
  bool _isSubmitting = false;
  bool _isConnected = false;

  List<Map<String, String>> _recentTranslations = [];
  List<Map<String, String>> _favoriteTranslations = [];
  
  final int _maxRecentTranslations = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isWeb = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        kIsWeb;

    if (!_isWeb) {
      _onDeviceTranslator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.spanish,
        targetLanguage: TranslateLanguage.english,
      );
      _checkModels();
    }
    
    _initConnectivity();
    _loadTranslations();
  }

  @override
  void dispose() {
    if (!_isWeb) {
      _onDeviceTranslator.close();
    }
    _achuarTextController.dispose();
    _sourceTextController.dispose();
    _translatedTextController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _updateConnectionStatus(connectivityResult);
    Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (mounted) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
    }
  }

  Future<void> _loadTranslations() async {
    final prefs = await SharedPreferences.getInstance();
    final recentJson = prefs.getStringList('recentTranslations') ?? [];
    final favoritesJson = prefs.getStringList('favoriteTranslations') ?? [];
    
    setState(() {
      _recentTranslations = recentJson.map((json) => 
        Map<String, String>.from(jsonDecode(json))
      ).toList();
      
      _favoriteTranslations = favoritesJson.map((json) => 
        Map<String, String>.from(jsonDecode(json))
      ).toList();
    });
  }

  Future<void> _saveTranslations() async {
    final prefs = await SharedPreferences.getInstance();
    
    final recentJson = _recentTranslations.map((translation) => 
      jsonEncode(translation)
    ).toList();
    
    final favoritesJson = _favoriteTranslations.map((translation) => 
      jsonEncode(translation)
    ).toList();
    
    await prefs.setStringList('recentTranslations', recentJson);
    await prefs.setStringList('favoriteTranslations', favoritesJson);
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

  Future<void> _toggleFavorite(Map<String, String> translation) async {
    setState(() {
      final index = _favoriteTranslations.indexWhere((t) => 
        t['achuar'] == translation['achuar'] && t['english'] == translation['english']
      );
      
      if (index >= 0) {
        _favoriteTranslations.removeAt(index);
      } else {
        _favoriteTranslations.add(translation);
      }
    });
    
    await _saveTranslations();
  }

  bool _isFavorite(Map<String, String> translation) {
    return _favoriteTranslations.any((t) => 
      t['achuar'] == translation['achuar'] && t['english'] == translation['english']
    );
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

  Future<void> _downloadModels() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
    });

    final modelManager = OnDeviceTranslatorModelManager();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando modelos...')),
    );

    await modelManager.downloadModel(TranslateLanguage.spanish.bcp47Code);
    await modelManager.downloadModel(TranslateLanguage.english.bcp47Code);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Modelos descargados exitosamente!')),
    );

    setState(() {
      _isDownloading = false;
    });
    
    _checkModels();
  }

  Future<void> _translateText() async {
    if (_achuarTextController.text.isEmpty || _sourceTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingrese texto en ambos campos.')),
      );
      return;
    }

    setState(() {
      _isTranslating = true;
      _translatedTextController.text = '';
    });

    final sourceText = _sourceTextController.text;
    String translatedText;

    try {
      if (_isWeb || (_isConnected && !_modelsDownloaded)) {
        final translator = GoogleTranslator();
        final translation = await translator.translate(sourceText, from: 'es', to: 'en');
        translatedText = translation.text;
      } else if (_modelsDownloaded) {
        translatedText = await _onDeviceTranslator.translateText(sourceText);
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

    final submission = {
      'achuar': _achuarTextController.text,
      'spanish': _sourceTextController.text,
      'source': 'translator',
    };
    
    final wasSavedLocally = await SyncService().addSubmission(submission);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(wasSavedLocally 
          ? 'Guardado localmente. Se enviará cuando haya conexión.'
          : 'Traducción enviada con éxito.'
        )),
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final canTranslate = !_isWeb && (_modelsDownloaded || _isConnected);

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
            Tab(text: 'Favoritos'),
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
                          onPressed: (_isTranslating || _isSubmitting || !canTranslate) ? null : _translateText,
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
                      if (!_isWeb && !_modelsDownloaded) ...[
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
                            children: [
                              Icon(
                                Icons.download_outlined,
                                size: 48,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Modelos sin conexión requeridos',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Descarga los modelos para traducir sin internet',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isDownloading ? null : _downloadModels,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16), // Adjusted padding
                                    backgroundColor: Colors.orange[700],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isDownloading
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
                                            Icon(Icons.download, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'Descargar modelos (~40MB)',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
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
          _favoriteTranslations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_border,
                        size: 64,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay favoritos',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Marca traducciones como favoritas',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: _favoriteTranslations.map((translation) => 
                    _buildTranslationCard(translation, isDarkMode)
                  ).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildTranslationCard(Map<String, String> translation, bool isDarkMode) {
    final isFavorite = _isFavorite(translation);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: isDarkMode ? 2 : 3,
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B5B95).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Achuar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B5B95),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        translation['achuar'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF82B366).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'English',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF82B366),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        translation['english'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : (isDarkMode ? Colors.grey[600] : Colors.grey[500]),
                  ),
                  onPressed: () => _toggleFavorite(translation),
                ),
              ],
            ),
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