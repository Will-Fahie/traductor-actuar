import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:achuar_ingis/theme/app_theme.dart';
import 'package:achuar_ingis/services/tts_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:achuar_ingis/widgets/language_toggle.dart';
import 'package:achuar_ingis/services/language_service.dart';
import 'package:achuar_ingis/l10n/app_localizations.dart';

class AnimalListScreen extends StatefulWidget {
  final String collectionName;
  final String title;

  const AnimalListScreen({
    super.key,
    required this.collectionName,
    required this.title,
  });

  @override
  State<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AnimationController? _animationController;
  Future<List<Map<String, dynamic>>>? _offlineData;
  bool _isConnected = true;
  StreamSubscription<dynamic>? _connectivitySubscription;
  
  // Edit mode functionality
  bool _isEditMode = false;
  final String _editPassword = 'chicha';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController?.forward();
    _offlineData = _loadOfflineData();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = !connectivityResult.contains(ConnectivityResult.none);
    });
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (mounted) {
        setState(() {
          _isConnected = !result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _connectivitySubscription?.cancel();
    // Cancel any pending operations
    _offlineData = null;
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadOfflineData() async {
    final prefs = await SharedPreferences.getInstance();
    final offlineDataString = prefs.getString('offline_${widget.collectionName}');
    if (offlineDataString != null) {
      final List<dynamic> decodedData = jsonDecode(offlineDataString);
      return decodedData.cast<Map<String, dynamic>>();
    }
    return [];
  }

  void _showEditModeDialog() {
    final passwordController = TextEditingController();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: AppTheme.primaryColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: LanguageService(),
                builder: (context, child) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.editModeTitle ?? 'Modo de Edición',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  );
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: LanguageService(),
                builder: (context, child) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.enterPasswordEdit ?? 'Ingresa la contraseña para activar el modo de edición:',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                onSubmitted: (value) {
                  if (value == _editPassword) {
                    setState(() {
                      _isEditMode = true;
                    });
                    Navigator.pop(context);
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n?.editModeActivated ?? 'Edit mode activated'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } else {
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n?.incorrectPassword ?? 'Incorrect password'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text == _editPassword) {
                  setState(() {
                    _isEditMode = true;
                  });
                  Navigator.pop(context);
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.editModeActivated ?? 'Edit mode activated'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } else {
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.incorrectPassword ?? 'Incorrect password'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white, // Explicitly set text color to white
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Activar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(Map<String, dynamic> animalData) {
    final nameController = TextEditingController(text: animalData['mainName'] ?? '');
    final achuarController = TextEditingController(text: animalData['achuar'] ?? '');
    final spanishController = TextEditingController(text: animalData['spanish'] ?? '');
    final englishController = TextEditingController(text: animalData['english'] ?? '');
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.edit_outlined,
                color: AppTheme.accentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Editar Animal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre Principal',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: achuarController,
                  decoration: const InputDecoration(
                    labelText: 'Achuar',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: spanishController,
                  decoration: const InputDecoration(
                    labelText: 'Español',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: englishController,
                  decoration: const InputDecoration(
                    labelText: 'English',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final editedData = {
                  'mainName': nameController.text,
                  'achuar': achuarController.text,
                  'spanish': spanishController.text,
                  'english': englishController.text,
                };

                try {
                  await _firestore
                      .collection(widget.collectionName)
                      .doc(animalData['id'])
                      .update(editedData);
                  Navigator.pop(context);
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.animalUpdatedSuccessfully ?? 'Animal updated successfully'),
                      backgroundColor: AppTheme.successColor,
                    ),
                  );
                } catch (e) {
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n?.errorSaving ?? 'Error saving'}: $e'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _offlineData,
      builder: (context, offlineSnapshot) {
        if (!mounted) return const SizedBox.shrink();
        if (offlineSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (offlineSnapshot.hasData && offlineSnapshot.data!.isNotEmpty) {
          return _buildUI(context, offlineSnapshot.data!, true);
        } else {
          return _buildOnlineUI();
        }
      },
    );
  }

  Widget _buildOnlineUI() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection(widget.collectionName)
          .orderBy('mainName')
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (!mounted) return const SizedBox.shrink();
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar los datos',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final querySnapshot = snapshot.data!;
        final allAnimals = querySnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        return _buildUI(
          context,
          allAnimals,
          false,
          isFromCache: querySnapshot.metadata.isFromCache,
        );
      },
    );
  }

  Widget _buildUI(
    BuildContext context,
    List<Map<String, dynamic>> animals,
    bool isOffline, {
    bool isFromCache = false,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final groupedAnimals = groupAnimalsAlphabetically(animals);
    final sortedKeys = groupedAnimals.keys.toList()..sort();
    final isOffline = !_isConnected;

    return DefaultTabController(
      length: sortedKeys.isEmpty ? 1 : sortedKeys.length,
      child: Scaffold(
        backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          elevation: 0,
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: TextButton.icon(
                onPressed: () {
                  if (_isEditMode) {
                    setState(() {
                      _isEditMode = false;
                    });
                  } else {
                    _showEditModeDialog();
                  }
                },
                icon: Icon(
                  _isEditMode ? Icons.edit_off : Icons.edit,
                  size: 18,
                ),
                label: Text(
                  'Editar',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _isEditMode 
                      ? Colors.white
                      : (isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                  backgroundColor: _isEditMode
                      ? AppTheme.primaryColor
                      : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200]),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: AnimalSearchDelegate(
                    allAnimals: animals,
                    collectionName: widget.collectionName,
                  ),
                );
              },
            ),
          ],
          bottom: sortedKeys.isEmpty
              ? null
              : TabBar(
                  isScrollable: true,
                  tabs: sortedKeys.map((letter) => Tab(text: letter)).toList(),
                  labelColor: _getCollectionColor(),
                  unselectedLabelColor: isDarkMode ? Colors.grey[600] : Colors.grey[600],
                  indicatorColor: _getCollectionColor(),
                  indicatorWeight: 3,
                ),
        ),
        body: Column(
          children: [
            if (isOffline)
              _buildStatusBanner(
                context,
                'Datos sin conexión',
                Icons.download_done_rounded,
                Colors.green,
              ),
            if (isFromCache && !isOffline)
              _buildStatusBanner(
                context,
                'Modo sin conexión',
                Icons.wifi_off_rounded,
                Colors.orange,
              ),
            if (sortedKeys.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOffline ? Icons.cloud_off_rounded : Icons.wifi_off_rounded,
                          size: 80,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isOffline
                              ? "No se encontraron datos sin conexión"
                              : "Conéctate a internet para descargar la lista",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOffline
                              ? "Descarga los recursos cuando tengas conexión"
                              : "Los datos se guardarán automáticamente",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: TabBarView(
                  children: sortedKeys.map((letter) {
                    final letterAnimals = groupedAnimals[letter]!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(20.0),
                      itemCount: letterAnimals.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: AnimalCard(
                            animalData: letterAnimals[index],
                            collectionName: widget.collectionName,
                            docId: letterAnimals[index]['id'] ?? '',
                            isEditMode: _isEditMode,
                            onEdit: _showEditDialog,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getCollectionColor() {
    if (widget.collectionName.contains('bird')) {
      return const Color(0xFF88B0D3);
    } else if (widget.collectionName.contains('mammal')) {
      return const Color(0xFF82B366);
    }
    return Theme.of(context).primaryColor;
  }

  Widget _buildStatusBanner(
    BuildContext context,
    String text,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> groupAnimalsAlphabetically(
      List<Map<String, dynamic>> animals) {
    final map = SplayTreeMap<String, List<Map<String, dynamic>>>();
    for (final animal in animals) {
      final mainName = animal['mainName'] as String?;
      if (mainName != null && mainName.isNotEmpty) {
        final firstLetter = mainName[0].toUpperCase();
        if (map[firstLetter] == null) {
          map[firstLetter] = [];
        }
        map[firstLetter]!.add(animal);
      }
    }
    return map;
  }
}

class AnimalSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> allAnimals;
  final String collectionName;

  AnimalSearchDelegate({
    required this.allAnimals,
    required this.collectionName,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, dynamic>> searchResults = allAnimals.where((animal) {
      final mainName = animal['mainName']?.toString().toLowerCase() ?? '';
      final englishName = animal['englishName']?.toString().toLowerCase() ?? '';
      final spanishName = animal['spanishName']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      return mainName.contains(searchQuery) ||
          englishName.contains(searchQuery) ||
          spanishName.contains(searchQuery);
    }).toList();

    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No se encontraron resultados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Intenta con otros términos de búsqueda',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      child: ListView.builder(
        padding: const EdgeInsets.all(20.0),
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: AnimalCard(
              animalData: searchResults[index],
              collectionName: collectionName,
              docId: searchResults[index]['id'],
              isEditMode: false, // Edit mode not available in search
              onEdit: null,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}

class AnimalCard extends StatefulWidget {
  final Map<String, dynamic> animalData;
  final String collectionName;
  final String docId;
  final bool isEditMode;
  final Function(Map<String, dynamic>)? onEdit;

  const AnimalCard({
    super.key,
    required this.animalData,
    required this.collectionName,
    required this.docId,
    required this.isEditMode,
    this.onEdit,
  });

  @override
  State<AnimalCard> createState() => _AnimalCardState();
}

class _AnimalCardState extends State<AnimalCard> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isPlayingAudio = false;
  bool _hasPendingEdit = false;

  StreamSubscription<dynamic>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkPendingEdit();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && mounted) {
        _syncPendingAnimalEdits();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPendingEdit() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pendingAnimalEdits') ?? [];
    if (mounted) {
      setState(() {
        _hasPendingEdit = pending.any((e) {
          final map = jsonDecode(e) as Map<String, dynamic>;
          return map['docId'] == widget.docId && map['collectionName'] == widget.collectionName;
        });
      });
    }
  }

  Future<bool> _isOffline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.none;
  }

  @override
  Widget build(BuildContext context) {
    final mainName = widget.animalData['mainName'] ?? 'N/A';
    final englishName = widget.animalData['englishName'] ?? 'N/A';
    final spanishName = widget.animalData['spanishName'] ?? 'N/A';
    final imageName = widget.animalData['imageName'] as String?;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final badgeColor = widget.collectionName.contains('bird')
        ? const Color(0xFF88B0D3)
        : widget.collectionName.contains('mammal')
            ? const Color(0xFF82B366)
            : Theme.of(context).primaryColor;

    return Material(
      elevation: isDarkMode ? 2 : 4,
      borderRadius: BorderRadius.circular(16),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shadowColor: Colors.black.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (imageName != null && imageName.isNotEmpty)
            ? () => _showImageDialog(context, imageName)
            : null,
        child: Container(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row with main name and action buttons
              if (_hasPendingEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync, color: Colors.orange, size: 16),
                        const SizedBox(width: 6),
                        Text(AppLocalizations.of(context)?.editPendingSync ?? 'Edit pending sync', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main name
                  Expanded(
                    child: Text(
                      mainName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  // Action buttons
                  Row(
                    children: [
                      if (imageName != null && imageName.isNotEmpty) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.image_rounded, size: 18),
                            color: Colors.blue,
                            padding: EdgeInsets.zero,
                            tooltip: 'Ver imagen',
                            onPressed: () => _showImageDialog(context, imageName),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.isEditMode && widget.onEdit != null) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            color: AppTheme.accentColor,
                            padding: EdgeInsets.zero,
                            tooltip: 'Editar',
                            onPressed: () => widget.onEdit!(widget.animalData),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Language translations - full width
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTranslationRow(
                            context,
                            'English',
                            englishName,
                            Icons.language_rounded,
                            Colors.blue,
                          ),
                        ),
                        if (englishName.isNotEmpty && englishName != 'N/A')
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _isPlayingAudio
                                  ? Colors.blue
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isPlayingAudio
                                    ? Icons.pause_rounded
                                    : Icons.volume_up_rounded,
                                size: 16,
                              ),
                              color: _isPlayingAudio
                                  ? Colors.white
                                  : Colors.blue,
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                if (!mounted) return;
                                setState(() {
                                  _isPlayingAudio = true;
                                });
                                bool playedLocal = false;
                                if (englishName.isNotEmpty && englishName != 'N/A') {
                                  await playEnglishTTS(englishName, checkAnimalAudio: true);
                                }
                                if (mounted) {
                                  setState(() {
                                    _isPlayingAudio = false;
                                  });
                                }
                              },
                              tooltip: 'Play English audio',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _buildTranslationRow(
                      context,
                      'Español',
                      spanishName,
                      Icons.translate_rounded,
                      Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationRow(
    BuildContext context,
    String language,
    String translation,
    IconData icon,
    Color color,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          '$language:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            translation,
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Future<String> _getImageUrl(String imageName) async {
    final imagePath = 'achuar_animals/$imageName';
    try {
      final ref = _storage.ref().child(imagePath);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error getting image URL for $imageName: $e');
      return '';
    }
  }

  void _showImageDialog(BuildContext context, String imageName) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String? localPath;
    try {
      final appDocDir = !kIsWeb ? await getApplicationDocumentsDirectory() : null;
      if (appDocDir != null) {
        final file = File('${appDocDir.path}/animal_images/$imageName');
        if (file.existsSync()) {
          localPath = file.path;
        }
      }
    } catch (_) {}
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image_rounded,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.animalData['mainName'] ?? 'Imagen',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Image
                Container(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: localPath != null
                      ? Image.file(File(localPath), fit: BoxFit.contain)
                      : FutureBuilder<String>(
                          future: _getImageUrl(imageName),
                          builder: (context, snapshot) {
                            if (!mounted) return const SizedBox.shrink();
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const SizedBox(
                                height: 200,
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                              return Container(
                                height: 200,
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_rounded,
                                      size: 64,
                                      color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Imagen no encontrada',
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              child: Image.network(
                                snapshot.data!,
                                fit: BoxFit.contain,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> animal) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController mainNameController = TextEditingController(text: animal['mainName']);
    final TextEditingController englishNameController = TextEditingController(text: animal['englishName']);
    final TextEditingController spanishNameController = TextEditingController(text: animal['spanishName']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Editar Nombres',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildEditTextField(
                  controller: mainNameController,
                  label: 'Nombre Achuar',
                  icon: Icons.pets_rounded,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                _buildEditTextField(
                  controller: englishNameController,
                  label: 'Nombre en Inglés',
                  icon: Icons.language_rounded,
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 16),
                _buildEditTextField(
                  controller: spanishNameController,
                  label: 'Nombre en Español',
                  icon: Icons.translate_rounded,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Close dialog immediately
                Navigator.of(context).pop();
                
                // Update animal in background
                await _updateAnimal(
                  docId,
                  mainNameController.text,
                  englishNameController.text,
                  spanishNameController.text,
                );
                
                // Show success message
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      final l10n = AppLocalizations.of(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 12),
                              Text(l10n?.changesSavedSuccessfully ?? 'Changes saved successfully'),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDarkMode,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.1),
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
          borderSide: const BorderSide(
            color: Colors.orange,
            width: 2,
          ),
        ),
      ),
    );
  }

  Future<void> _updateAnimal(String docId, String mainName, String englishName, String spanishName) async {
    if (await _isOffline()) {
      // Save edit locally
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pendingAnimalEdits') ?? [];
      final edit = jsonEncode({
        'docId': docId,
        'collectionName': widget.collectionName,
        'data': {
          'mainName': mainName,
          'englishName': englishName,
          'spanishName': spanishName,
        },
      });
      pending.add(edit);
      await prefs.setStringList('pendingAnimalEdits', pending);
      // Update offline data
      final offlineKey = 'offline_${widget.collectionName}';
      final offlineString = prefs.getString(offlineKey);
      if (offlineString != null) {
        List<dynamic> offlineList = jsonDecode(offlineString);
        for (var animal in offlineList) {
          if (animal['id'] == docId) {
            animal['mainName'] = mainName;
            animal['englishName'] = englishName;
            animal['spanishName'] = spanishName;
          }
        }
        await prefs.setString(offlineKey, jsonEncode(offlineList));
      }
      if (mounted) {
        setState(() { _hasPendingEdit = true; });
      }
    } else {
      // Online: update Firestore
      await _firestore.collection(widget.collectionName).doc(docId).update({
        'mainName': mainName,
        'englishName': englishName,
        'spanishName': spanishName,
      });
      if (mounted) {
        setState(() { _hasPendingEdit = false; });
      }
    }
  }

  Future<void> _syncPendingAnimalEdits() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getStringList('pendingAnimalEdits') ?? [];
    if (pending.isEmpty) return;
    List<String> stillPending = [];
    for (final editStr in pending) {
      final edit = jsonDecode(editStr) as Map<String, dynamic>;
      try {
        await FirebaseFirestore.instance
          .collection(edit['collectionName'])
          .doc(edit['docId'])
          .update(Map<String, dynamic>.from(edit['data']));
      } catch (e) {
        stillPending.add(editStr); // If fails, keep in queue
      }
    }
    await prefs.setStringList('pendingAnimalEdits', stillPending);
    if (mounted) setState(() { _hasPendingEdit = stillPending.any((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return map['docId'] == widget.docId && map['collectionName'] == widget.collectionName;
    }); });
  }
}