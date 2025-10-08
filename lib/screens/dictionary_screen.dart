import 'package:flutter/material.dart';
import 'package:myapp/services/dictionary_service.dart';
import 'dart:collection';
import 'package:myapp/theme/app_theme.dart';
import 'package:myapp/widgets/app_card.dart';
import 'package:myapp/widgets/app_text_field.dart';
import 'package:myapp/widgets/language_toggle.dart';
import 'package:myapp/widgets/section_header.dart';
import 'package:myapp/services/language_service.dart';
import 'package:myapp/l10n/app_localizations.dart';

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: AnimatedBuilder(
          animation: LanguageService(),
          builder: (context, child) {
            final l10n = AppLocalizations.of(context);
            return Text(l10n?.dictionary ?? 'Diccionario');
          },
        ),
        elevation: 0,

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
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppTheme.spacingMedium),
                  Text(
                    AppLocalizations.of(context)?.loading ?? 'Cargando diccionario...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Text(
                      AppLocalizations.of(context)?.error != null 
                        ? '${AppLocalizations.of(context)?.error} al cargar el ${AppLocalizations.of(context)?.dictionary?.toLowerCase()}'
                        : 'Error al cargar el diccionario',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
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
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
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
                      AppTextField(
                        controller: _searchController,
                        hintText: AppLocalizations.of(context)?.searchInDictionary ?? 'Buscar en inglés, achuar o español...',
                        prefixIcon: Icons.search_rounded,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                      ),
                      // Alphabet navigation
                      if (!_isSearching) ...[
                        const SizedBox(height: AppTheme.spacingMedium),
                        SizedBox(
                          height: 44,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: allLetters.length,
                            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXSmall),
                            itemBuilder: (context, index) {
                              final letter = allLetters[index];
                              final isSelected = _selectedLetter == letter;
                              final hasEntries = _groupedEntries.containsKey(letter);
                              
                              return Padding(
                                padding: const EdgeInsets.only(right: AppTheme.spacingSmall),
                                child: Material(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : hasEntries
                                          ? theme.colorScheme.surface
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                  child: InkWell(
                                    onTap: hasEntries ? () {
                                      setState(() {
                                        _selectedLetter = letter;
                                      });
                                    } : null,
                                    borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                    child: Container(
                                      width: 44,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                                        border: !hasEntries
                                            ? Border.all(
                                                color: theme.dividerTheme.color ?? AppTheme.dividerColor,
                                                width: 1,
                                              )
                                            : isSelected
                                                ? null
                                                : Border.all(
                                                    color: theme.dividerTheme.color ?? AppTheme.dividerColor,
                                                    width: 1,
                                                  ),
                                      ),
                                      child: Text(
                                        letter,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          color: isSelected
                                              ? Colors.white
                                              : hasEntries
                                                  ? theme.colorScheme.primary
                                                  : theme.textTheme.bodySmall?.color,
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSmall),
                        Center(
                          child: Text(
                            AppLocalizations.of(context)?.swipeToSeeMore ?? 'Desliza para ver más letras',
                            style: theme.textTheme.bodySmall?.copyWith(
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
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXLarge),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.book_outlined,
                        size: 48,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingLarge),
                    Text(
                      'No se encontraron entradas',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSmall),
                    Text(
                      AppLocalizations.of(context)?.dictionaryEmpty ?? 'El diccionario está vacío',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSearchResults(bool isDarkMode) {
    final theme = Theme.of(context);
    return Column(
      children: [
        // Results count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingMedium,
            vertical: AppTheme.spacingMedium,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.primary.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Text(
            '${_filteredEntries.length} resultado${_filteredEntries.length != 1 ? 's' : ''} encontrado${_filteredEntries.length != 1 ? 's' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
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
                        Icons.search_off_rounded,
                        size: 64,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(height: AppTheme.spacingMedium),
                      Text(
                        'No se encontraron resultados',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacingMedium),
                  itemCount: _filteredEntries.length,
                  itemBuilder: (context, index) {
                    return _buildEntryCard(_filteredEntries[index], theme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLetterList(bool isDarkMode) {
    final letterEntries = _groupedEntries[_selectedLetter] ?? [];
    final theme = Theme.of(context);
    
    if (letterEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _selectedLetter,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),
            Text(
              AppLocalizations.of(context)?.words != null 
                ? 'No hay ${AppLocalizations.of(context)?.words?.toLowerCase()} que empiecen con "$_selectedLetter"'
                : 'No hay palabras que empiecen con "$_selectedLetter"',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMedium),
      itemCount: letterEntries.length,
      itemBuilder: (context, index) {
        return _buildEntryCard(letterEntries[index], theme);
      },
    );
  }

  Widget _buildEntryCard(DictionaryEntry entry, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSmall),
      child: AppCard(
        padding: const EdgeInsets.all(AppTheme.spacingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.english,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            _buildLanguageRow(
              'Achuar',
              entry.achuar,
              AppTheme.accentColor,
              theme,
            ),
            const SizedBox(height: AppTheme.spacingXSmall),
            _buildLanguageRow(
              'Español',
              entry.spanish,
              AppTheme.secondaryColor,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRow(String language, String text, Color color, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSmall,
            vertical: AppTheme.spacingXSmall,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Text(
            language,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacingSmall),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}