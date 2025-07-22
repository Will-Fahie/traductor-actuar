import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:myapp/theme/app_theme.dart';

class AnimalListScreen extends StatefulWidget {
  final String collectionName;
  final String title;

  const AnimalListScreen({super.key, required this.collectionName, required this.title});

  @override
  _AnimalListScreenState createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Future<List<Map<String, dynamic>>>? _offlineData;

  @override
  void initState() {
    super.initState();
    _offlineData = _loadOfflineData();
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _offlineData,
      builder: (context, offlineSnapshot) {
        if (offlineSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));
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
      stream: _firestore.collection(widget.collectionName).orderBy('mainName').snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(appBar: AppBar(title: Text(widget.title)), body: Center(child: Text('Error al cargar los datos', style: Theme.of(context).textTheme.titleMedium)));
        }

        if (!snapshot.hasData) {
          return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));
        }

        final querySnapshot = snapshot.data!;
        final allAnimals = querySnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        
        return _buildUI(context, allAnimals, false, isFromCache: querySnapshot.metadata.isFromCache);
      },
    );
  }

  Widget _buildUI(BuildContext context, List<Map<String, dynamic>> animals, bool isOffline, {bool isFromCache = false}) {
    final groupedAnimals = groupAnimalsAlphabetically(animals);
    final sortedKeys = groupedAnimals.keys.toList()..sort();

    return DefaultTabController(
      length: sortedKeys.isEmpty ? 1 : sortedKeys.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF121212) : const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      tooltip: 'Volver',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        showSearch(
                          context: context,
                          delegate: AnimalSearchDelegate(allAnimals: animals, collectionName: widget.collectionName)
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (isOffline)
                _buildStatusBanner(context, 'Datos sin conexión', Icons.download_done, Colors.green),
              if (isFromCache && !isOffline)
                _buildStatusBanner(context, 'Modo sin conexión', Icons.wifi_off, Theme.of(context).colorScheme.error),
              if (sortedKeys.isEmpty)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        isOffline ? "No se encontraron datos sin conexión." : "Conéctate a internet para descargar la lista.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: DefaultTabController(
                    length: sortedKeys.length,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabs: sortedKeys.map((letter) => Tab(text: letter)).toList(),
                          labelColor: Theme.of(context).primaryColor,
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Theme.of(context).primaryColor,
                        ),
                        Expanded(
                          child: TabBarView(
                            children: sortedKeys.map((letter) {
                              final letterAnimals = groupedAnimals[letter]!;
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 20.0),
                                itemCount: letterAnimals.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: AnimalCard(animalData: letterAnimals[index], collectionName: widget.collectionName, docId: letterAnimals[index]['id'] ?? ''),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusBanner(BuildContext context, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      width: double.infinity,
      color: color,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> groupAnimalsAlphabetically(List<Map<String, dynamic>> animals) {
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

  AnimalSearchDelegate({required this.allAnimals, required this.collectionName});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return AppTheme.theme.copyWith(
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
        icon: const Icon(Icons.clear),
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
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
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
      return const Center(child: Text('No se encontraron resultados.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: AnimalCard(animalData: searchResults[index], collectionName: collectionName, docId: searchResults[index]['id']),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}

class AnimalCard extends StatelessWidget {
  final Map<String, dynamic> animalData;
  final String collectionName;
  final String docId;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AnimalCard({super.key, required this.animalData, required this.collectionName, required this.docId});

  @override
  Widget build(BuildContext context) {
    final mainName = animalData['mainName'] ?? 'N/A';
    final englishName = animalData['englishName'] ?? 'N/A';
    final spanishName = animalData['spanishName'] ?? 'N/A';
    final imageName = animalData['imageName'] as String?;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final badgeColor = collectionName.contains('bird')
        ? const Color(0xFF88B0D3)
        : collectionName.contains('mammal')
            ? const Color(0xFF82B366)
            : Theme.of(context).primaryColor.withOpacity(0.8);
    return Material(
      elevation: isDarkMode ? 2 : 4,
      borderRadius: BorderRadius.circular(16),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: (imageName != null && imageName.isNotEmpty)
            ? () => _showImageDialog(context, imageName)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animal details (no icon)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inglés: $englishName',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Español: $spanishName',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons with labels
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image, color: Colors.blueGrey),
                        tooltip: 'Ver imagen',
                        onPressed: (imageName != null && imageName.isNotEmpty)
                            ? () => _showImageDialog(context, imageName)
                            : null,
                      ),
                      const SizedBox(width: 2),
                      Text('Ver imagen', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        tooltip: 'Editar',
                        onPressed: () => _showEditDialog(context, docId, animalData),
                      ),
                      const SizedBox(width: 2),
                      Text('Editar', style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageRow(BuildContext context, String language, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$language:', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
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

  void _showImageDialog(BuildContext context, String imageName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: FutureBuilder<String>(
            future: _getImageUrl(imageName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('Imagen no encontrada.');
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(snapshot.data!)
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, String docId, Map<String, dynamic> animal) {
    final TextEditingController mainNameController = TextEditingController(text: animal['mainName']);
    final TextEditingController englishNameController = TextEditingController(text: animal['englishName']);
    final TextEditingController spanishNameController = TextEditingController(text: animal['spanishName']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Editar Nombres'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: mainNameController, decoration: const InputDecoration(labelText: 'Nombre Achuar')),
                const SizedBox(height: 8),
                TextField(controller: englishNameController, decoration: const InputDecoration(labelText: 'Nombre en Inglés')),
                const SizedBox(height: 8),
                TextField(controller: spanishNameController, decoration: const InputDecoration(labelText: 'Nombre en Español')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateAnimal(docId, mainNameController.text, englishNameController.text, spanishNameController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _updateAnimal(String docId, String mainName, String englishName, String spanishName) {
    _firestore.collection(collectionName).doc(docId).update({
      'mainName': mainName,
      'englishName': englishName,
      'spanishName': spanishName,
    });
  }
}
