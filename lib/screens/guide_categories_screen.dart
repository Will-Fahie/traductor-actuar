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
  StreamSubscription<dynamic>? _connectivitySubscription;
  
  final List<CategoryData> _categories = [
    CategoryData(
      title: 'Aves',
      subtitle: 'Descubre las especies de aves',
      icon: Icons.flutter_dash,
      route: '/birds',
      color: const Color(0xFF88B0D3),
      gradientEnd: const Color(0xFF68A0D3),
    ),
    CategoryData(
      title: 'Mamíferos',
      subtitle: 'Explora los mamíferos nativos',
      icon: Icons.pets,
      route: '/mammals',
      color: const Color(0xFF82B366),
      gradientEnd: const Color(0xFF62A346),
    ),
  ];

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Recursos de Guía',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 20),
          children: [
            
            // Category Cards
            ..._categories.asMap().entries.map((entry) {
              final index = entry.key;
              final category = entry.value;
              return _buildCategoryCard(
                context,
                category,
                isDarkMode,
              );
            }).toList(),
            
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
    // Hardcode image size to 130MB, text data to 0.5MB
    final double estimatedTextMB = 0.5;
    final double estimatedImageMB = 130.0;
    final double estimatedMB = estimatedTextMB + estimatedImageMB;
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
                    Text(
                      'Modo sin conexión',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      'Descargue el texto y las imágenes para uso sin conexión',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
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
              'Descargando... ${(_downloadProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ] else if (_isDownloaded) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text(
                  'Descargado',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
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
                icon: Icon(Icons.download_rounded, size: 20, color: isOffline ? Colors.grey : Colors.blue),
                label: Text(
                  '130 MB',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Por favor, no abandone esta página mientras se descarga.'),
        duration: Duration(seconds: 3),
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
      final birdsSnapshot = await firestore.collection('animals_birds').get();
      if (!mounted) return;
      final birdsData = birdsSnapshot.docs.map((doc) => doc.data()).toList();
      await prefs.setString('offline_birds', jsonEncode(birdsData));
      setState(() => _downloadProgress = 0.3);
      await prefs.setDouble('resources_download_progress', 0.3);
      if (!mounted) return;

      // Download mammals
      final mammalsSnapshot = await firestore.collection('animals_mammals').get();
      if (!mounted) return;
      final mammalsData = mammalsSnapshot.docs.map((doc) => doc.data()).toList();
      await prefs.setString('offline_mammals', jsonEncode(mammalsData));
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
        final progress = 0.3 + 0.7 * (completed / imageNames.length);
        setState(() => _downloadProgress = progress);
        await prefs.setDouble('resources_download_progress', progress);
        if (!mounted) return;
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Recursos e imágenes descargados con éxito!'),
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
                Expanded(child: Text('Error al descargar: $e')),
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