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
  String _selectedLetter = 'A';
  bool _isSearching = false;
  Map<String, List<DictionaryEntry>> _groupedEntries = {};

  @override
  void initState() {
    super.initState();
    _entriesFuture = DictionaryService().loadEntries().then((entries) {
      entries.sort((a, b) => a.english.compareTo(b.english));
      setState(() {
        _allEntries = entries;
        _filteredEntries = entries;
        _groupedEntries = _groupEntriesAlphabetically(entries);
        // Set default letter to first available letter with entries
        if (_groupedEntries.isNotEmpty) {
          _selectedLetter = _groupedEntries.keys.first;
        }
      });
      return entries;
    });
    _searchController.addListener(_filterEntries);
  }
  
  void _filterEntries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _isSearching = query.isNotEmpty;
      if (_isSearching) {
        _filteredEntries = _allEntries.where((entry) {
          return entry.english.toLowerCase().contains(query) ||
                 entry.achuar.toLowerCase().contains(query) ||
                 entry.spanish.toLowerCase().contains(query);
        }).toList();
      } else {
        _filteredEntries = _allEntries;
      }
    });
  }

  Map<String, List<DictionaryEntry>> _groupEntriesAlphabetically(List<DictionaryEntry> entries) {
    final map = <String, List<DictionaryEntry>>{};
    for (final entry in entries) {
      if (entry.english.isNotEmpty) {
        final firstLetter = entry.english[0].toUpperCase();
        if (map[firstLetter] == null) {
          map[firstLetter] = [];
        }
        map[firstLetter]!.add(entry);
      }
    }
    // Sort the map by keys and return as a LinkedHashMap to maintain order
    final sortedKeys = map.keys.toList()..sort();
    final sortedMap = LinkedHashMap<String, List<DictionaryEntry>>();
    for (final key in sortedKeys) {
      sortedMap[key] = map[key]!;
    }
    return sortedMap;
  }

  List<String> _getAllLetters() {
    final allLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
    return allLetters;
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterEntries);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Diccionario',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: FutureBuilder<List<DictionaryEntry>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: isDarkMode ? Colors.white : const Color(0xFF6B5B95),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando diccionario...',
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar el diccionario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasData && _allEntries.isNotEmpty) {
            final allLetters = _getAllLetters();

            return Column(
              children: [
                // Search bar and alphabet navigation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar en inglés, achuar o español...',
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      // Alphabet navigation
                      if (!_isSearching) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: allLetters.length,
                            itemBuilder: (context, index) {
                              final letter = allLetters[index];
                              final isSelected = _selectedLetter == letter;
                              final hasEntries = _groupedEntries.containsKey(letter);
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: hasEntries ? () {
                                    setState(() {
                                      _selectedLetter = letter;
                                    });
                                  } : null,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    width: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF6B5B95)
                                          : hasEntries
                                              ? (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200])
                                              : Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      border: hasEntries && !isSelected
                                          ? null
                                          : !hasEntries
                                              ? Border.all(
                                                  color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                                                  width: 1,
                                                )
                                              : null,
                                    ),
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : hasEntries
                                                ? (isDarkMode ? Colors.white : const Color(0xFF6B5B95))
                                                : (isDarkMode ? Colors.grey[700] : Colors.grey[400]),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Desliza para ver más letras',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Results or dictionary entries
                Expanded(
                  child: _isSearching
                      ? _buildSearchResults(isDarkMode)
                      : _buildLetterList(isDarkMode),
                ),
              ],
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 64,
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No se encontraron entradas',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSearchResults(bool isDarkMode) {
    return Column(
      children: [
        // Results count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
          child: Text(
            '${_filteredEntries.length} resultado${_filteredEntries.length != 1 ? 's' : ''} encontrado${_filteredEntries.length != 1 ? 's' : ''}',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: _filteredEntries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No se encontraron resultados',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _filteredEntries.length,
                  itemBuilder: (context, index) {
                    return _buildEntryCard(_filteredEntries[index], isDarkMode);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLetterList(bool isDarkMode) {
    final letterEntries = _groupedEntries[_selectedLetter] ?? [];
    
    if (letterEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 64,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay palabras que empiecen con "$_selectedLetter"',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Letter header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50],
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF6B5B95),
                      Color(0xFF5A4A83),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _selectedLetter,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${letterEntries.length} palabra${letterEntries.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        // Entries list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: letterEntries.length,
            itemBuilder: (context, index) {
              return _buildEntryCard(letterEntries[index], isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(DictionaryEntry entry, bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 3,
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.english,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _buildLanguageRow(
                'Achuar',
                entry.achuar,
                const Color(0xFF82B366),
                isDarkMode,
              ),
              const SizedBox(height: 4),
              _buildLanguageRow(
                'Español',
                entry.spanish,
                const Color(0xFF88B0D3),
                isDarkMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageRow(String language, String text, Color color, bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            language,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: isDarkMode ? Colors.grey[300] : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}