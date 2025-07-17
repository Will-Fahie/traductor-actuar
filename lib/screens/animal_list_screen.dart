import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:collection';

class AnimalListScreen extends StatefulWidget {
  final String collectionName;
  final String title;

  const AnimalListScreen({super.key, required this.collectionName, required this.title});

  @override
  _AnimalListScreenState createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
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
        final allAnimals = querySnapshot.docs;
        final isOffline = querySnapshot.metadata.isFromCache;
        final groupedAnimals = groupAnimalsAlphabetically(allAnimals);
        final sortedKeys = groupedAnimals.keys.toList()..sort();

        return DefaultTabController(
          length: sortedKeys.isEmpty ? 1 : sortedKeys.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    showSearch(
                      context: context, 
                      delegate: AnimalSearchDelegate(allAnimals: allAnimals, collectionName: widget.collectionName)
                    );
                  },
                ),
              ],
              bottom: sortedKeys.isEmpty ? null : TabBar(
                isScrollable: true,
                tabs: sortedKeys.map((letter) => Tab(text: letter)).toList(),
              ),
            ),
            body: Column(
              children: [
                if (isOffline)
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    width: double.infinity,
                    color: Theme.of(context).colorScheme.error,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Theme.of(context).colorScheme.onError, size: 16),
                        const SizedBox(width: 8),
                        Text('Modo sin conexión', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onError, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (sortedKeys.isEmpty && !isOffline)
                  const Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("No se encontraron datos.", style: TextStyle(fontSize: 18)),
                  ))
                else if (sortedKeys.isEmpty && isOffline)
                   const Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("Conéctate a internet para descargar la lista.", textAlign: TextAlign.center, style: TextStyle(fontSize: 18)),
                  ))
                else
                  Expanded(
                    child: TabBarView(
                      children: sortedKeys.map((letter) {
                        final letterAnimals = groupedAnimals[letter]!;
                        return ListView.separated(
                          padding: const EdgeInsets.all(12.0),
                          itemCount: letterAnimals.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return AnimalCard(animalDoc: letterAnimals[index], collectionName: widget.collectionName);
                          },
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<QueryDocumentSnapshot>> groupAnimalsAlphabetically(List<QueryDocumentSnapshot> animals) {
    final map = SplayTreeMap<String, List<QueryDocumentSnapshot>>();
    for (final animal in animals) {
      final mainName = (animal.data() as Map<String, dynamic>)['mainName'] as String?;
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
  final List<QueryDocumentSnapshot> allAnimals;
  final String collectionName;

  AnimalSearchDelegate({required this.allAnimals, required this.collectionName});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: theme.appBarTheme.foregroundColor?.withOpacity(0.8)),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: theme.appBarTheme.foregroundColor,
          fontSize: 20
        ),
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
    final List<QueryDocumentSnapshot> searchResults = allAnimals.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final mainName = data['mainName']?.toString().toLowerCase() ?? '';
      final englishName = data['englishName']?.toString().toLowerCase() ?? '';
      final spanishName = data['spanishName']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      return mainName.contains(searchQuery) ||
             englishName.contains(searchQuery) ||
             spanishName.contains(searchQuery);
    }).toList();

    if (searchResults.isEmpty) {
      return const Center(
        child: Text('No se encontraron resultados.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12.0),
      itemCount: searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return AnimalCard(animalDoc: searchResults[index], collectionName: collectionName);
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Show results in real-time as the user types
    return buildResults(context);
  }
}


class AnimalCard extends StatelessWidget {
  final QueryDocumentSnapshot animalDoc;
  final String collectionName;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AnimalCard({super.key, required this.animalDoc, required this.collectionName});

  @override
  Widget build(BuildContext context) {
    final animalData = animalDoc.data() as Map<String, dynamic>;
    final docId = animalDoc.id;
    final mainName = animalData['mainName'] ?? 'N/A';
    final englishName = animalData['englishName'] ?? 'N/A';
    final spanishName = animalData['spanishName'] ?? 'N/A';
    final imageName = animalData['imageName'] as String?;
    final bool hasPendingWrites = animalDoc.metadata.hasPendingWrites;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mainName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            const SizedBox(height: 12),
            _buildLanguageRow(context, Icons.language, 'Achuar', mainName),
            const Divider(),
            _buildLanguageRow(context, Icons.translate, 'Inglés', englishName),
            const Divider(),
            _buildLanguageRow(context, Icons.public, 'Español', spanishName),
            const SizedBox(height: 16),
              if (hasPendingWrites)
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: const Icon(Icons.sync),
                  label: const Text('Cambio pendiente'),
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            if (hasPendingWrites) const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                  TextButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 20),
                  label: const Text('Ver Imagen'),
                  onPressed: (imageName != null && imageName.isNotEmpty) ? () => _showImageDialog(context, imageName) : null,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                  onPressed: () => _showEditDialog(context, docId, animalData),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRow(BuildContext context, IconData icon, String language, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
          const SizedBox(width: 12),
          Text('$language:', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).textTheme.bodyMedium?.color)),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: TextStyle(fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color))),
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
          title: const Text('Imagen del Animal'),
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
