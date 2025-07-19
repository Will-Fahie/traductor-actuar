import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  _RecentScreenState createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _pendingSubmissions = [];
  List<Map<String, dynamic>> _pendingEdits = [];
  List<String> _pendingDeletes = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];

  bool _isEditMode = false;
  String _userName = '';
  final String _editPassword = 'chicha';

  // For 'Your Submissions'
  Set<String> _localSubmissionIds = {};

  // Add a map to hold optimistic UI updates for the 'reviewed' status.
  final Map<String, bool> _optimisticReviewedStatus = {};

  // For Tabs
  TabController? _tabController;

  // For Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
    _loadPendingActions();
    _loadLocalSubmissionIds();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _loadLocalSubmissionIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('localSubmissionIds') ?? [];
    setState(() {
      _localSubmissionIds = ids.toSet();
    });
  }

  Future<void> _addLocalSubmissionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _localSubmissionIds.add(id);
    await prefs.setStringList(
        'localSubmissionIds', _localSubmissionIds.toList());
    setState(() {});
  }

  Future<void> _removeLocalSubmissionId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    _localSubmissionIds.remove(id);
    await prefs.setStringList(
        'localSubmissionIds', _localSubmissionIds.toList());
    setState(() {});
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    late List<ConnectivityResult> result;
    try {
      result = await Connectivity().checkConnectivity();
    } catch (e) {
      print('Could not check connectivity status: $e');
      return;
    }
    if (!mounted) {
      return;
    }
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    setState(() {
      _connectionStatus = result;
    });
    if (!_connectionStatus.contains(ConnectivityResult.none)) {
      _syncPendingActions();
    }
  }

  Future<void> _loadPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pendingSubmissions =
          (json.decode(prefs.getString('pendingSubmissions') ?? '[]') as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
      _pendingEdits =
          (json.decode(prefs.getString('pendingEdits') ?? '[]') as List)
              .map((item) => item as Map<String, dynamic>)
              .toList();
      _pendingDeletes =
          (prefs.getStringList('pendingDeletes') ?? []).cast<String>().toList();
    });
  }

  Future<void> _savePendingSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pendingSubmissions', json.encode(_pendingSubmissions));
  }

  Future<void> _savePendingEdits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pendingEdits', json.encode(_pendingEdits));
  }

  Future<void> _savePendingDeletes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pendingDeletes', _pendingDeletes);
  }

  Future<void> _syncPendingActions() async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Sync submissions
    for (var sub in _pendingSubmissions) {
      firestore.collection('achuar_submission').add(sub);
    }
    _pendingSubmissions.clear();
    await _savePendingSubmissions();

    // Sync edits
    for (var edit in _pendingEdits) {
      batch.update(firestore.collection('achuar_submission').doc(edit['docId']),
          edit['data'] as Map<String, Object>);
    }
    _pendingEdits.clear();
    await _savePendingEdits();

    // Sync deletes
    for (var docId in _pendingDeletes) {
      batch.delete(firestore.collection('achuar_submission').doc(docId));
    }
    _pendingDeletes.clear();
    await _savePendingDeletes();

    if (batch.toString().isNotEmpty) {
      await batch.commit();
    }
  }

  void _showDeleteDialog(BuildContext context, DocumentSnapshot doc) {
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
                Icons.delete_outline,
                color: Colors.red[400],
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Confirmar Eliminación',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Estás seguro de que deseas eliminar esta contribución?',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              if (_isEditMode) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!_isEditMode || passwordController.text == _editPassword) {
                  if (_connectionStatus.contains(ConnectivityResult.none)) {
                    _pendingDeletes.add(doc.id);
                    await _savePendingDeletes();
                  } else {
                    FirebaseFirestore.instance
                        .collection('achuar_submission')
                        .doc(doc.id)
                        .delete();
                  }
                  await _removeLocalSubmissionId(doc.id);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contraseña incorrecta')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final achuarController = TextEditingController(text: data['achuar']);
    final spanishController = TextEditingController(text: data['spanish']);
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
              const Icon(
                Icons.edit_outlined,
                color: Color(0xFF82B366),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Editar Frase',
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
                  controller: achuarController,
                  decoration: InputDecoration(
                    labelText: 'Achuar',
                    prefixIcon: const Icon(Icons.language),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: spanishController,
                  decoration: InputDecoration(
                    labelText: 'Español',
                    prefixIcon: const Icon(Icons.translate),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final editedData = {
                  'achuar': achuarController.text,
                  'spanish': spanishController.text,
                };

                if (_connectionStatus.contains(ConnectivityResult.none)) {
                  final edit = {'docId': doc.id, 'data': editedData};
                  if (mounted) {
                    setState(() {
                      _pendingEdits.add(edit);
                    });
                  }
                  _savePendingEdits();
                  Navigator.pop(context);
                } else {
                  try {
                    await FirebaseFirestore.instance
                        .collection('achuar_submission')
                        .doc(doc.id)
                        .update(editedData);
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar la edición: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF82B366),
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

  void _showEditModeDialog() {
    final nameController = TextEditingController();
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
              const Icon(
                Icons.admin_panel_settings_outlined,
                color: Color(0xFF6B5B95),
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Modo Edición',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
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
                    _userName = nameController.text;
                  });
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contraseña incorrecta')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5B95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Entrar'),
            ),
          ],
        );
      },
    );
  }
  
  // ✨ FIX: Extracted review update logic into its own method to be passed as a callback.
  Future<void> _handleReviewChanged(DocumentSnapshot doc, bool value) async {
    final data = doc.data() as Map<String, dynamic>;
    final originalValue = _optimisticReviewedStatus[doc.id] ?? data['reviewed'] == true;

    // Optimistically update the UI by calling setState.
    setState(() {
      _optimisticReviewedStatus[doc.id] = value;
    });

    final reviewData = {
      'reviewed': value,
      'reviewed_by': _userName,
    };

    if (_connectionStatus.contains(ConnectivityResult.none)) {
      final edit = {'docId': doc.id, 'data': reviewData};
      _pendingEdits.add(edit);
      await _savePendingEdits();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Cambio de revisión guardado para sincronizar.')),
      );
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('achuar_submission')
            .doc(doc.id)
            .update(reviewData);
      } catch (e) {
        // Revert the UI change on failure.
        setState(() {
          _optimisticReviewedStatus[doc.id] = originalValue;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al actualizar la revisión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Envíos Recientes',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: () {
                if (_isEditMode) {
                  setState(() {
                    _isEditMode = false;
                    _userName = '';
                  });
                } else {
                  _showEditModeDialog();
                }
              },
              icon: Icon(
                _isEditMode ? Icons.edit_off_outlined : Icons.edit_outlined,
                size: 18,
              ),
              label: const Text('Editar'),
              style: TextButton.styleFrom(
                foregroundColor: _isEditMode
                    ? const Color(0xFF6B5B95)
                    : (isDarkMode ? Colors.grey[300] : Colors.grey[600]),
                backgroundColor: _isEditMode
                    ? const Color(0xFF6B5B95).withOpacity(0.1)
                    : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF82B366),
          labelColor: const Color(0xFF82B366),
          unselectedLabelColor: isDarkMode ? Colors.grey[600] : Colors.grey[600],
          tabs: const [
            Tab(text: 'Tus envíos'),
            Tab(text: 'Todos los envíos'),
          ],
        ),
      ),
      body: Column(
        children: [
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
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar frases...',
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
          ),
          Expanded(
            // ✨ FIX: Use the new SubmissionsTabView widget which preserves scroll state.
            child: TabBarView(
              controller: _tabController,
              children: [
                SubmissionsTabView(
                  isLocal: true,
                  isEditMode: _isEditMode,
                  searchQuery: _searchQuery,
                  localSubmissionIds: _localSubmissionIds,
                  optimisticReviewedStatus: _optimisticReviewedStatus,
                  onReviewChanged: _handleReviewChanged,
                  showEditDialog: (doc) => _showEditDialog(context, doc),
                  showDeleteDialog: (doc) => _showDeleteDialog(context, doc),
                ),
                SubmissionsTabView(
                  isLocal: false,
                  isEditMode: _isEditMode,
                  searchQuery: _searchQuery,
                  localSubmissionIds: _localSubmissionIds,
                  optimisticReviewedStatus: _optimisticReviewedStatus,
                  onReviewChanged: _handleReviewChanged,
                  showEditDialog: (doc) => _showEditDialog(context, doc),
                  showDeleteDialog: (doc) => _showDeleteDialog(context, doc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ✨ FIX: Created a new StatefulWidget to hold the list and preserve its state.
class SubmissionsTabView extends StatefulWidget {
  final bool isLocal;
  final bool isEditMode;
  final String searchQuery;
  final Set<String> localSubmissionIds;
  final Map<String, bool> optimisticReviewedStatus;
  final Future<void> Function(DocumentSnapshot doc, bool value) onReviewChanged;
  final void Function(DocumentSnapshot doc) showEditDialog;
  final void Function(DocumentSnapshot doc) showDeleteDialog;

  const SubmissionsTabView({
    super.key,
    required this.isLocal,
    required this.isEditMode,
    required this.searchQuery,
    required this.localSubmissionIds,
    required this.optimisticReviewedStatus,
    required this.onReviewChanged,
    required this.showEditDialog,
    required this.showDeleteDialog,
  });

  @override
  State<SubmissionsTabView> createState() => _SubmissionsTabViewState();
}

class _SubmissionsTabViewState extends State<SubmissionsTabView> with AutomaticKeepAliveClientMixin {
  // ✨ FIX: This tells Flutter to keep this widget's state alive.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    // ✨ FIX: Important call for AutomaticKeepAliveClientMixin.
    super.build(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey<String>(widget.isLocal ? 'local' : 'all'),
      stream: FirebaseFirestore.instance
          .collection('achuar_submission')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
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
                  'Error: ${snapshot.error}',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: const Color(0xFF82B366),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cargando contribuciones...',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        var docs = snapshot.data?.docs ?? [];

        if (widget.isLocal) {
          docs = docs.where((doc) => widget.localSubmissionIds.contains(doc.id)).toList();
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay contribuciones recientes',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'en este dispositivo',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }
        }

        if (widget.searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final achuar = data['achuar']?.toString().toLowerCase() ?? '';
            final spanish = data['spanish']?.toString().toLowerCase() ?? '';
            final query = widget.searchQuery.toLowerCase();
            return achuar.contains(query) || spanish.contains(query);
          }).toList();
        }

        if (docs.isEmpty && widget.searchQuery.isNotEmpty) {
          return Center(
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
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            return _buildListItem(doc);
          },
        );
      },
    );
  }

  Widget _buildListItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final bool isReviewed = widget.optimisticReviewedStatus[doc.id] ?? data['reviewed'] == true;
    final bool isLocal = widget.localSubmissionIds.contains(doc.id);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          Row(
                            children: [
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
                                  'Achuar',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF82B366),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['achuar'] ?? '',
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
                              color: const Color(0xFF88B0D3).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Español',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF88B0D3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['spanish'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.isEditMode || isLocal) ...[
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          if (widget.isEditMode)
                            Checkbox(
                              value: isReviewed,
                              activeColor: const Color(0xFF82B366),
                              onChanged: (value) {
                                if (value != null) {
                                  widget.onReviewChanged(doc, value);
                                }
                              },
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF82B366).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 20,
                                  ),
                                  color: const Color(0xFF82B366),
                                  padding: EdgeInsets.zero,
                                  onPressed: () => widget.showEditDialog(doc),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                  ),
                                  color: Colors.red[400],
                                  padding: EdgeInsets.zero,
                                  onPressed: () => widget.showDeleteDialog(doc),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                if (data['location'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        data['location'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (data['notes'] != null && data['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 16,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['notes'],
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}