import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:myapp/services/tts_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:myapp/widgets/language_toggle.dart';
import 'package:myapp/services/language_service.dart';
import 'package:myapp/l10n/app_localizations.dart';

class GuideCategoriesScreen extends StatefulWidget {
  const GuideCategoriesScreen({super.key});

  @override
  State<GuideCategoriesScreen> createState() => _GuideCategoriesScreenState();
}

class _GuideCategoriesScreenState extends State<GuideCategoriesScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isDownloaded = false;
  bool _isConnected = true;
  bool _hasOutdatedAudio = false;
  StreamSubscription<dynamic>? _connectivitySubscription;
  Timer? _connectivityDebounceTimer;
  
  List<CategoryData> _getCategories(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return [
      CategoryData(
        title: l10n?.birds ?? 'Aves',
        subtitle: l10n?.discoverBirdSpecies ?? 'Descubre las especies de aves',
        icon: Icons.flutter_dash,
        route: '/birds',
        color: const Color(0xFF88B0D3),
        gradientEnd: const Color(0xFF68A0D3),
      ),
      CategoryData(
        title: l10n?.mammals ?? 'Mamíferos',
        subtitle: l10n?.exploreNativeMammals ?? 'Explora los mamíferos nativos',
        icon: Icons.pets,
        route: '/mammals',
        color: const Color(0xFF82B366),
        gradientEnd: const Color(0xFF62A346),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    _restoreDownloadState();
    _initConnectivity();
    _checkForOutdatedAudioOnInit();
  }

  Future<void> _initConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _isConnected = !connectivityResult.contains(ConnectivityResult.none);
        });
      }
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        if (mounted) {
          try {
            // Cancel previous timer to debounce rapid changes
            _connectivityDebounceTimer?.cancel();
            _connectivityDebounceTimer = Timer(const Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _isConnected = !result.contains(ConnectivityResult.none);
                });
                
                // Check for outdated audio when coming back online
                if (!result.contains(ConnectivityResult.none) && _isDownloaded) {
                  _checkForOutdatedAudioOnInit();
                } else if (result.contains(ConnectivityResult.none)) {
                  // Clear outdated audio flag when going offline
                  setState(() {
                    _hasOutdatedAudio = false;
                  });
                }
              }
            });
          } catch (e) {
            print('[CONNECTIVITY] Error updating connection status: $e');
          }
        }
      });
    } catch (e) {
      print('[CONNECTIVITY] Error initializing connectivity: $e');
      if (mounted) {
        setState(() => _isConnected = true);
      }
    }
  }

  Future<void> _checkForOutdatedAudioOnInit() async {
    if (_isDownloaded && _isConnected) {
      try {
        final hasOutdated = await _checkForOutdatedAudio();
        if (mounted) {
          setState(() {
            _hasOutdatedAudio = hasOutdated;
          });
        }
      } catch (e) {
        print('[AUDIO] Error in _checkForOutdatedAudioOnInit: $e');
        if (mounted) {
          setState(() {
            _hasOutdatedAudio = false;
          });
        }
      }
    }
  }

  Future<bool> _checkForOutdatedAudio() async {
    try {
      // Check connectivity first
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        print('[AUDIO] Offline - skipping outdated audio check');
        return false;
      }
      
      final prefs = await SharedPreferences.getInstance();
      final downloadedDataString = prefs.getString('downloaded_animals_data');
      if (downloadedDataString == null) return false;
      
      final downloadedAnimals = jsonDecode(downloadedDataString) as List<dynamic>;
      
      // Get current data from Firestore
      final firestore = FirebaseFirestore.instance;
      final birdsSnapshot = await firestore.collection('animals_birds').get();
      final mammalsSnapshot = await firestore.collection('animals_mammals').get();
      
      final currentBirds = birdsSnapshot.docs.map((doc) => doc.data()).toList();
      final currentMammals = mammalsSnapshot.docs.map((doc) => doc.data()).toList();
      final currentAnimals = [...currentBirds, ...currentMammals];
      
      // Compare English names
      final downloadedNames = downloadedAnimals.map((a) => a['englishName']).toSet();
      final currentNames = currentAnimals.map((a) => a['englishName']).toSet();
      
      // Check if any names have changed
      return !setEquals(downloadedNames, currentNames);
    } catch (e) {
      print('[AUDIO] Error checking for outdated audio: $e');
      return false;
    }
  }

  Future<void> _restoreDownloadState() async {
    final prefs = await SharedPreferences.getInstance();
    final downloaded = prefs.getBool('resources_downloaded') ?? false;
    final isDownloading = prefs.getBool('resources_downloading') ?? false;
    final downloadProgress = prefs.getDouble('resources_download_progress') ?? 0.0;
    if (isDownloading) {
      if (mounted) {
        setState(() {
          _isDownloading = true;
          _downloadProgress = downloadProgress;
          _isDownloaded = downloaded;
        });
        // Automatically resume the download
        // Use a post-frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _downloadResources(context);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isDownloaded = downloaded;
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectivitySubscription?.cancel();
    _connectivityDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: LanguageService(),
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            return Text(
              l10n?.guideResourcesTitle ?? 'Recursos de Guía',
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        elevation: 0,
        actions: const [
          LanguageToggle(),
          SizedBox(width: 16),
        ],
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20),
          children: [
            
            // Category Cards
            AnimatedBuilder(
              animation: LanguageService(),
              builder: (context, child) {
                final categories = _getCategories(context);
                return Column(
                  children: categories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final category = entry.value;
                    return _buildCategoryCard(
                      context,
                      category,
                      isDarkMode,
                    );
                  }).toList(),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Download Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: _buildDownloadSection(context, isDarkMode),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    CategoryData category,
    bool isDarkMode,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Material(
        elevation: isDarkMode ? 2 : 4,
        shadowColor: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, category.route),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              children: [
                // Icon container with gradient
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category.color.withOpacity(0.8),
                        category.gradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: category.color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    category.icon,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Arrow icon
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadSection(BuildContext context, bool isDarkMode) {
    // Hardcode image size to 130MB, text data to 0.5MB, audio to 9.5MB
    final double estimatedTextMB = 0.5;
    final double estimatedImageMB = 130.0;
    final double estimatedAudioMB = 9.5;
    final double estimatedMB = estimatedTextMB + estimatedImageMB + estimatedAudioMB;
    final String sizeEstimate = estimatedMB.toStringAsFixed(1);
    final isOffline = !_isConnected;
    if (kIsWeb) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.cloud_download_rounded,
                  color: Colors.orange[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.offlineMode ?? 'Modo sin conexión',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.downloadTextImagesAudio ?? 'Descargue el texto, imágenes y audio para uso sin conexión',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: LanguageService(),
                      builder: (context, child) {
                        final l10n = AppLocalizations.of(context);
                        return Text(
                          l10n?.downloadMayTakeMinutes ?? 'La descarga puede tomar varios minutos',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 8,
                backgroundColor: Colors.grey.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[700]!),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _downloadProgress < 0.3 
                ? 'Descargando texto... ${(_downloadProgress * 100).toInt()}%'
                : _downloadProgress < 0.65
                  ? 'Descargando imágenes... ${(_downloadProgress * 100).toInt()}%'
                  : 'Descargando audio... ${(_downloadProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Por favor, mantenga la aplicación abierta',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ] else if (_isDownloaded) ...[
            if (_hasOutdatedAudio) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Algunos audios descargados están desactualizados',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _hasOutdatedAudio ? () => _downloadResources(context) : null,
                icon: Icon(_hasOutdatedAudio ? Icons.refresh_rounded : Icons.check_circle, size: 20),
                label: Text(
                  _hasOutdatedAudio ? 'Actualizar audio' : 'Descargado',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasOutdatedAudio ? Colors.orange : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isOffline || _isDownloading ? null : () => _downloadResources(context),
                icon: Icon(Icons.download_rounded, size: 20, color: isOffline ? Colors.grey : Colors.white),
                label: Text(
                  '140 MB',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _downloadResources(BuildContext context) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.doNotLeaveWhileDownloading ?? 'Please do not leave this page while downloading.'),
        duration: const Duration(seconds: 3),
      ),
    );
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });
    await prefs.setBool('resources_downloading', true);
    await prefs.setDouble('resources_download_progress', 0.0);

    try {
      final firestore = FirebaseFirestore.instance;
      final storage = FirebaseStorage.instance;

      // Simulate progress for better UX
      setState(() => _downloadProgress = 0.1);
      await prefs.setDouble('resources_download_progress', 0.1);
      if (!mounted) return;

      // Download birds
      List<Map<String, dynamic>> birdsData = [];
      try {
        final birdsSnapshot = await firestore.collection('animals_birds').get();
        if (!mounted) return;
        birdsData = birdsSnapshot.docs.map((doc) => doc.data()).toList();
        await prefs.setString('offline_birds', jsonEncode(birdsData));
        setState(() => _downloadProgress = 0.3);
        await prefs.setDouble('resources_download_progress', 0.3);
        if (!mounted) return;
      } catch (e) {
        print('[DOWNLOAD] Error downloading birds: $e');
        // Continue with mammals even if birds fail
      }

      // Download mammals
      List<Map<String, dynamic>> mammalsData = [];
      try {
        final mammalsSnapshot = await firestore.collection('animals_mammals').get();
        if (!mounted) return;
        mammalsData = mammalsSnapshot.docs.map((doc) => doc.data()).toList();
        await prefs.setString('offline_mammals', jsonEncode(mammalsData));
      } catch (e) {
        print('[DOWNLOAD] Error downloading mammals: $e');
        // Continue with images even if mammals fail
      }
      setState(() => _downloadProgress = 0.3);
      await prefs.setDouble('resources_download_progress', 0.3);
      if (!mounted) return;

      // Download all images for birds and mammals
      final allAnimals = [...birdsData, ...mammalsData];
      final imageNames = allAnimals.map((a) => a['imageName']).where((name) => name != null && name.toString().isNotEmpty).toSet();
      final appDocDir = !kIsWeb ? await getApplicationDocumentsDirectory() : null;
      final imagesDir = appDocDir != null ? Directory('${appDocDir.path}/animal_images') : null;
      if (imagesDir != null && !imagesDir.existsSync()) {
        imagesDir.createSync(recursive: true);
      }
      int completed = 0;
      for (final imageName in imageNames) {
        final localPath = imagesDir != null ? '${imagesDir.path}/$imageName' : null;
        if (localPath == null) continue; // Skip if appDocDir is null
        final file = File(localPath);
        if (!file.existsSync()) {
          try {
            final ref = storage.ref().child('achuar_animals/$imageName');
            final data = await ref.getData();
            if (data != null) {
              await file.writeAsBytes(data);
            }
          } catch (e) {
            // Ignore individual image download errors
          }
        }
        completed++;
        final progress = 0.3 + 0.35 * (completed / imageNames.length);
        setState(() => _downloadProgress = progress);
        await prefs.setDouble('resources_download_progress', progress);
        if (!mounted) return;
      }

      // Download all animal audio (skip existing files)
      final animalNames = allAnimals.map((a) => a['englishName']).where((name) => name != null && name.toString().isNotEmpty).toSet();
      completed = 0;
      int skippedCount = 0;
      for (final animalName in animalNames) {
        try {
          // Check if audio file already exists
          final dir = await getApplicationDocumentsDirectory();
          final safeName = animalName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          final animalDir = Directory('${dir.path}/offline_animal_audio');
          final filePath = '${animalDir.path}/$safeName.mp3';
          final file = File(filePath);
          
          if (file.existsSync()) {
            print('[DOWNLOAD] Skipping existing audio: $animalName');
            skippedCount++;
          } else {
            print('[DOWNLOAD] Downloading new audio: $animalName');
            await downloadAndSaveEnglishTTS(animalName, forAnimal: true);
          }
        } catch (e) {
          print('[DOWNLOAD] Error downloading audio for $animalName: $e');
          // Continue with other animals even if one fails
        }
        completed++;
        final progress = 0.65 + 0.35 * (completed / animalNames.length);
        setState(() => _downloadProgress = progress);
        await prefs.setDouble('resources_download_progress', progress);
        if (!mounted) return;
      }
      
      if (skippedCount > 0) {
        print('[DOWNLOAD] Skipped $skippedCount existing audio files');
      }

      // Show success message
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(l10n?.resourcesImagesAudioDownloaded ?? 'Resources, images and audio downloaded successfully!')),
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

      // Store download timestamp and animal data for future comparison
      await prefs.setInt('resources_download_timestamp', DateTime.now().millisecondsSinceEpoch);
      await prefs.setString('downloaded_animals_data', jsonEncode(allAnimals));
      
      // Persist download state
      await prefs.setBool('resources_downloaded', true);
      await prefs.setBool('resources_downloading', false);
      await prefs.setDouble('resources_download_progress', 0.0);

      // Reset after a delay
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
        _isDownloaded = true;
        _hasOutdatedAudio = false; // Clear outdated audio flag after successful update
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
      await prefs.setBool('resources_downloading', false);
      await prefs.setDouble('resources_download_progress', 0.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('${AppLocalizations.of(context)?.errorDownloading ?? 'Error downloading'}: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  List<List<String>> _chunkList(List<String> list, int chunkSize) {
    List<List<String>> chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
}

// Data class for categories
class CategoryData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
  final Color gradientEnd;

  const CategoryData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
    required this.gradientEnd,
  });
}