import 'package:flutter/material.dart';
import 'package:myapp/services/dictionary_service.dart';
import 'dart:collection';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  _DictionaryScreenState createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  late Future<List<DictionaryEntry>> _entriesFuture;
  List<DictionaryEntry> _allEntries = [];
  List<DictionaryEntry> _filteredEntries = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entriesFuture = DictionaryService().loadEntries().then((entries) {
      // Sort entries by English word for initial display
      entries.sort((a, b) => a.english.compareTo(b.english));
      setState(() {
        _allEntries = entries;
        _filteredEntries = entries;
      });
      return entries;
    });
    _searchController.addListener(_filterEntries);
  }
  
  void _filterEntries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredEntries = _allEntries.where((entry) {
        return entry.english.toLowerCase().contains(query) ||
               entry.achuar.toLowerCase().contains(query) ||
               entry.spanish.toLowerCase().contains(query);
      }).toList();
    });
  }

  Map<String, List<DictionaryEntry>> _groupEntriesAlphabetically(List<DictionaryEntry> entries) {
    final map = SplayTreeMap<String, List<DictionaryEntry>>();
    for (final entry in entries) {
      if (entry.english.isNotEmpty) {
        final firstLetter = entry.english[0].toUpperCase();
        if (map[firstLetter] == null) {
          map[firstLetter] = [];
        }
        map[firstLetter]!.add(entry);
      }
    }
    return map;
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterEntries);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diccionario'),
      ),
      body: FutureBuilder<List<DictionaryEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            final groupedEntries = _groupEntriesAlphabetically(_filteredEntries);
            final sortedKeys = groupedEntries.keys.toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar en el diccionario...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade200,
                    ),
                  ),
                ),
                Expanded(
                  child: DefaultTabController(
                    length: sortedKeys.length,
                    child: Column(
                      children: [
                        TabBar(
                          isScrollable: true,
                          tabs: sortedKeys.map((letter) => Tab(text: letter)).toList(),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: sortedKeys.map((letter) {
                              final letterEntries = groupedEntries[letter]!;
                              return ListView.separated(
                                padding: const EdgeInsets.all(16.0),
                                itemCount: letterEntries.length,
                                separatorBuilder: (context, index) => const Divider(height: 24),
                                itemBuilder: (context, index) {
                                  final entry = letterEntries[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.english, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Text.rich(
                                          TextSpan(
                                            style: Theme.of(context).textTheme.bodyLarge,
                                            children: [
                                              const TextSpan(text: 'Achuar: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                              TextSpan(text: entry.achuar),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text.rich(
                                          TextSpan(
                                            style: Theme.of(context).textTheme.bodyLarge,
                                            children: [
                                              const TextSpan(text: 'Español: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                              TextSpan(text: entry.spanish),
                                            ],
                                          ),
                                        ),
                                      ],
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
                ),
              ],
            );
          } else {
            return const Center(child: Text('No se encontraron entradas.'));
          }
        },
      ),
    );
  }
}
