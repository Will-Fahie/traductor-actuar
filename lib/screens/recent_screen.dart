import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/services/sync_service.dart';
import 'package:myapp/services/language_service.dart';
import 'package:myapp/l10n/app_localizations.dart';

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
  List<Map<String, dynamic>> _pendingDeletesData = []; // Store full data for deletes
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  List<ConnectivityResult> _connectionStatus = [ConnectivityResult.none];

  bool _isEditMode = false;
  final String _editPassword = 'chicha';

  String? _deviceId;

  final Map<String, bool> _optimisticReviewedStatus = {};

  TabController? _tabController;

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
    _loadDeviceId();
    _loadOptimisticReviewedStatus();
    _loadEditModeState();
    _checkAndSyncOnInit();
    
    // Listen for changes from SyncService
    SyncService().pendingSubmissionsStream.listen((submissions) {
      if (mounted) {
        setState(() {
          _pendingSubmissions = submissions;
        });
        print('Updated from SyncService: ${submissions.length} pending submissions');
      }
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  Future<void> _checkAndSyncOnInit() async {
    // Wait a bit for connectivity to be checked
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted && !_connectionStatus.contains(ConnectivityResult.none)) {
      // If we're online and have pending items, sync them
      await _loadPendingActions();
      await _loadOptimisticReviewedStatus();
      if (_pendingSubmissions.isNotEmpty || _pendingEdits.isNotEmpty || _pendingDeletes.isNotEmpty) {
        print('Found pending items on init while online, syncing...');
        await _syncPendingActions();
      }
    }
  }

  Future<void> _loadDeviceId() async {
    final deviceId = await SyncService().getDeviceId();
    if (mounted) {
      setState(() {
        _deviceId = deviceId;
      });
    }
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

  void _updateConnectionStatus(List<ConnectivityResult> result) async {
    if (mounted) {
      setState(() {
        _connectionStatus = result;
      });
      if (!_connectionStatus.contains(ConnectivityResult.none)) {
        // Reload pending data first to ensure we have the latest
        await _loadPendingActions();
        await _loadOptimisticReviewedStatus();
        // Then sync if there's anything to sync
        await _syncPendingActions();
      }
    }
  }

  Future<void> _loadPendingActions() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        // Load submissions - handle both List<String> and JSON string formats
        final submissionsValue = prefs.get('pendingSubmissions');
        if (submissionsValue is List<String>) {
          // SyncService format
          _pendingSubmissions = submissionsValue.map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (e) {
              print('Error decoding submission: $e');
              return <String, dynamic>{};
            }
          }).where((item) => item.isNotEmpty).toList();
        } else if (submissionsValue is String) {
          // Old format
          try {
            _pendingSubmissions = (json.decode(submissionsValue) as List)
                .map((item) => item as Map<String, dynamic>)
                .toList();
          } catch (e) {
            print('Error loading submissions: $e');
            _pendingSubmissions = [];
          }
        } else {
          _pendingSubmissions = [];
        }
        
        // Load edits - handle both formats
        final editsValue = prefs.get('pendingEdits');
        if (editsValue is List<String>) {
          _pendingEdits = editsValue.map((s) {
            try {
              return jsonDecode(s) as Map<String, dynamic>;
            } catch (e) {
              print('Error decoding edit: $e');
              return <String, dynamic>{};
            }
          }).where((item) => item.isNotEmpty).toList();
        } else if (editsValue is String) {
          try {
            _pendingEdits = (json.decode(editsValue) as List)
                .map((item) => item as Map<String, dynamic>)
                .toList();
          } catch (e) {
            print('Error loading edits: $e');
            _pendingEdits = [];
          }
        } else {
          _pendingEdits = [];
        }
        
        _pendingDeletes =
            (prefs.getStringList('pendingDeletes') ?? []).cast<String>().toList();
        
        // Load delete data
        final deleteDataValue = prefs.getString('pendingDeletesData');
        if (deleteDataValue != null) {
          try {
            _pendingDeletesData = (json.decode(deleteDataValue) as List)
                .map((item) => item as Map<String, dynamic>)
                .toList();
          } catch (e) {
            print('Error loading delete data: $e');
            _pendingDeletesData = [];
          }
        } else {
          _pendingDeletesData = [];
        }
      });
      
      print('Loaded pending: ${_pendingSubmissions.length} submissions, ${_pendingEdits.length} edits, ${_pendingDeletes.length} deletes');
    }
  }

  Future<void> _loadOptimisticReviewedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final statusJson = prefs.getString('optimisticReviewedStatus') ?? '{}';
    final statusMap = json.decode(statusJson) as Map<String, dynamic>;
    if (mounted) {
      setState(() {
        _optimisticReviewedStatus.clear();
        statusMap.forEach((key, value) {
          _optimisticReviewedStatus[key] = value as bool;
        });
      });
    }
  }

  Future<void> _saveOptimisticReviewedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('optimisticReviewedStatus', json.encode(_optimisticReviewedStatus));
  }

  Future<void> _loadEditModeState() async {
    final prefs = await SharedPreferences.getInstance();
    final editMode = prefs.getBool('isEditMode') ?? false;
    if (mounted) {
      setState(() {
        _isEditMode = editMode;
      });
    }
  }

  Future<void> _saveEditModeState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isEditMode', _isEditMode);
  }


  Future<void> _syncPendingActions() async {
    if (_pendingSubmissions.isEmpty && _pendingEdits.isEmpty && _pendingDeletes.isEmpty) {
      return;
    }

    print('Starting sync: ${_pendingSubmissions.length} submissions, ${_pendingEdits.length} edits, ${_pendingDeletes.length} deletes');

    try {
      final firestore = FirebaseFirestore.instance;

      // Add new submissions (one at a time to ensure they're added)
      for (var sub in _pendingSubmissions) {
        await firestore.collection('achuar_submission').add(sub);
        print('Synced submission: ${sub['achuar']}');
      }
      
      // Apply edits using batch
      if (_pendingEdits.isNotEmpty || _pendingDeletes.isNotEmpty) {
        final batch = firestore.batch();
        
        for (var edit in _pendingEdits) {
          // Convert Map<String, dynamic> to Map<String, Object>
          final editData = edit['data'] as Map<String, dynamic>;
          final updateData = Map<String, Object>.from(editData);
          
          batch.update(
            firestore.collection('achuar_submission').doc(edit['docId']),
            updateData,
          );
          print('Synced edit for: ${edit['docId']}');
        }

        // Delete entries
        for (var docId in _pendingDeletes) {
          batch.delete(firestore.collection('achuar_submission').doc(docId));
          print('Synced delete for: $docId');
        }
        
        // Commit all batched operations
        await batch.commit();
      }

      // Clear all pending data after successful sync
      _pendingSubmissions.clear();
      _pendingEdits.clear();
      _pendingDeletes.clear();
      _pendingDeletesData.clear();
      _optimisticReviewedStatus.clear();
      
      // Save the cleared state - use empty list format that matches SyncService
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pendingSubmissions', []);
      await prefs.setStringList('pendingEdits', []);
      await prefs.setStringList('pendingDeletes', []);
      await prefs.setString('pendingDeletesData', '[]');
      await prefs.setString('optimisticReviewedStatus', '{}');
      
      // Notify SyncService to reload
      await SyncService().loadPendingSubmissions();

      print('Sync completed successfully');

      if (mounted) {
        setState(() {
          // Trigger UI refresh
        });
        
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n?.syncedSuccessfully ?? 'Sincronizado correctamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error syncing pending actions: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n?.errorSyncing ?? 'Error al sincronizar'}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog(BuildContext context, DocumentSnapshot doc) {
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
              AnimatedBuilder(
                animation: LanguageService(),
                builder: (context, child) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.deleteEntry ?? 'Eliminar entrada',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  );
                },
              ),
            ],
          ),
          content: AnimatedBuilder(
            animation: LanguageService(),
            builder: (context, child) {
              final l10n = AppLocalizations.of(context);
              return Text(
                l10n?.deleteConfirmation ?? '¿Estás seguro de que deseas eliminar esta entrada? Esta acción no se puede deshacer.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                final isOffline = _connectionStatus.contains(ConnectivityResult.none);
                
                if (isOffline) {
                  // Offline: Add to pending deletes with full data
                  final data = doc.data() as Map<String, dynamic>;
                  setState(() {
                    _pendingDeletes.add(doc.id);
                    _pendingDeletesData.add({
                      'docId': doc.id,
                      'achuar': data['achuar'],
                      'spanish': data['spanish'],
                      'location': data['location'],
                      'timestamp': data['timestamp']?.toString(),
                    });
                  });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setStringList('pendingDeletes', _pendingDeletes);
                  await prefs.setString('pendingDeletesData', json.encode(_pendingDeletesData));
                  
                  final l10n = AppLocalizations.of(context);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n?.savedLocally ?? 'Saved locally'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } else {
                  // Online: Delete directly from Firestore
                  try {
                    await FirebaseFirestore.instance
                        .collection('achuar_submission')
                        .doc(doc.id)
                        .delete();
                    
                    final l10n = AppLocalizations.of(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n?.entryDeleted ?? 'Entry deleted'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    final l10n = AppLocalizations.of(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${l10n?.errorDeletingEntryPrefix ?? 'Error deleting entry'}: $e')),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
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
              AnimatedBuilder(
                animation: LanguageService(),
                builder: (context, child) {
                  final l10n = AppLocalizations.of(context);
                  return Text(
                    l10n?.editPhrase ?? 'Editar Frase',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  );
                },
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
                    labelText: AppLocalizations.of(context)?.achuarPhrase ?? 'Achuar',
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
                    labelText: AppLocalizations.of(context)?.spanishPhrase ?? 'Español',
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
                AppLocalizations.of(context)?.cancel ?? 'Cancelar',
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
                  final edit = {
                    'docId': doc.id,
                    'data': editedData,
                    'actionType': 'edit',
                    'achuar': achuarController.text,
                    'spanish': spanishController.text,
                    'original_achuar': data['achuar'],
                    'original_spanish': data['spanish'],
                  };
                  if (mounted) {
                    setState(() {
                      _pendingEdits.add(edit);
                    });
                  }
                  final prefs = await SharedPreferences.getInstance();
                  final editsList = _pendingEdits.map((item) => json.encode(item)).toList();
                  await prefs.setStringList('pendingEdits', editsList);
                  Navigator.pop(context);
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.savedLocally ?? 'Saved locally'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  try {
                    await FirebaseFirestore.instance
                        .collection('achuar_submission')
                        .doc(doc.id)
                        .update(editedData);
                    Navigator.pop(context);
                } catch (e) {
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${l10n?.errorSavingEdit ?? 'Error saving edit'}: $e')),
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
              child: Text(AppLocalizations.of(context)?.save ?? 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showEditModeDialog() {
    final TextEditingController passwordController = TextEditingController();
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
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.password ?? 'Contraseña',
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
                AppLocalizations.of(context)?.cancel ?? 'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password == _editPassword) {
                  setState(() {
                    _isEditMode = true;
                  });
                  await _saveEditModeState();
                  Navigator.pop(context);
                } else {
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n?.incorrectPassword ?? 'Incorrect password')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5B95),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)?.enter ?? 'Enter',
                style: const TextStyle(
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
  
  Future<void> _handleReviewChanged(DocumentSnapshot doc, bool value) async {
    final data = doc.data() as Map<String, dynamic>;
    final originalValue = _optimisticReviewedStatus[doc.id] ?? data['reviewed'] == true;

    setState(() {
      _optimisticReviewedStatus[doc.id] = value;
    });
    await _saveOptimisticReviewedStatus();

    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? '';
    final reviewData = {
      'reviewed': value,
      'reviewed_by': username,
    };

    if (_connectionStatus.contains(ConnectivityResult.none)) {
      final edit = {
        'docId': doc.id, 
        'data': reviewData,
        'actionType': 'review',
        'achuar': data['achuar'],
        'spanish': data['spanish'],
      };
      _pendingEdits.add(edit);
      final prefs = await SharedPreferences.getInstance();
      final editsList = _pendingEdits.map((item) => json.encode(item)).toList();
      await prefs.setStringList('pendingEdits', editsList);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.revisionChangeSaved ?? 'Cambio de revisión guardado para sincronizar.'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      try {
        await FirebaseFirestore.instance
            .collection('achuar_submission')
            .doc(doc.id)
            .update(reviewData);
        
        // Successfully updated online - remove from optimistic status
        setState(() {
          _optimisticReviewedStatus.remove(doc.id);
        });
        await _saveOptimisticReviewedStatus();
      } catch (e) {
        setState(() {
          _optimisticReviewedStatus[doc.id] = originalValue;
        });
        await _saveOptimisticReviewedStatus();
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${l10n?.errorUpdatingRevision ?? 'Error updating revision'}: $e')),
        );
      }
    }
  }

  void _showEditPendingSubmissionDialog(int index, Map<String, dynamic> submission) {
    final achuarController = TextEditingController(text: submission['achuar']);
    final spanishController = TextEditingController(text: submission['spanish']);
    final notesController = TextEditingController(text: submission['notes'] ?? '');
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
                AppLocalizations.of(context)?.editPhrase ?? 'Editar Frase',
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
                    labelText: AppLocalizations.of(context)?.achuarPhrase ?? 'Achuar',
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
                    labelText: AppLocalizations.of(context)?.spanishPhrase ?? 'Español',
                    prefixIcon: const Icon(Icons.translate),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)?.additionalNotes ?? 'Notas adicionales',
                    prefixIcon: const Icon(Icons.note),
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
                AppLocalizations.of(context)?.cancel ?? 'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Update the pending submission
                final updatedSubmission = Map<String, dynamic>.from(submission);
                updatedSubmission['achuar'] = achuarController.text;
                updatedSubmission['spanish'] = spanishController.text;
                updatedSubmission['notes'] = notesController.text;

                setState(() {
                  _pendingSubmissions[index] = updatedSubmission;
                });

                // Save to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                final submissionsList = _pendingSubmissions.map((item) => json.encode(item)).toList();
                await prefs.setStringList('pendingSubmissions', submissionsList);
                
                // Notify SyncService
                await SyncService().loadPendingSubmissions();

                Navigator.pop(context);
                
                final l10n = AppLocalizations.of(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.entryUpdated ?? 'Entrada actualizada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF82B366),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppLocalizations.of(context)?.save ?? 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showDeletePendingSubmissionDialog(int index, Map<String, dynamic> submission) {
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
                AppLocalizations.of(context)?.deleteEntry ?? 'Eliminar entrada',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            AppLocalizations.of(context)?.deleteConfirmation ?? '¿Estás seguro de que deseas eliminar esta entrada? Esta acción no se puede deshacer.',
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancelar',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Remove from pending submissions
                setState(() {
                  _pendingSubmissions.removeAt(index);
                });

                // Save to SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                final submissionsList = _pendingSubmissions.map((item) => json.encode(item)).toList();
                await prefs.setStringList('pendingSubmissions', submissionsList);
                
                // Notify SyncService
                await SyncService().loadPendingSubmissions();
                
                final l10n = AppLocalizations.of(context);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.entryDeleted ?? 'Entrada eliminada'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
            ),
          ],
        );
      },
    );
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
              l10n?.recentContributionsTitle ?? 'Envíos Recientes',
              style: const TextStyle(fontWeight: FontWeight.w600),
            );
          },
        ),
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        actions: [
          // Manual sync/refresh button
          if (_pendingSubmissions.isNotEmpty || _pendingEdits.isNotEmpty || _pendingDeletes.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.sync,
                color: _connectionStatus.contains(ConnectivityResult.none)
                    ? Colors.orange
                    : const Color(0xFF82B366),
              ),
              onPressed: () async {
                if (!_connectionStatus.contains(ConnectivityResult.none)) {
                  await _loadPendingActions();
                  await _loadOptimisticReviewedStatus();
                  await _syncPendingActions();
                } else {
                  final l10n = AppLocalizations.of(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.syncWhenOnline ?? 'Se sincronizará cuando esté en línea'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
              tooltip: AppLocalizations.of(context)?.refresh ?? 'Refrescar',
            ),
          AnimatedBuilder(
            animation: LanguageService(),
            builder: (context, child) {
              final l10n = AppLocalizations.of(context);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: TextButton.icon(
                  onPressed: () async {
                    if (_isEditMode) {
                      setState(() {
                        _isEditMode = false;
                      });
                      await _saveEditModeState();
                    } else {
                      _showEditModeDialog();
                    }
                  },
                  icon: Icon(
                    _isEditMode ? Icons.edit_off : Icons.edit,
                    size: 18,
                  ),
                  label: Text(
                    l10n?.editEntry ?? 'Editar',
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
                        ? const Color(0xFF6B5B95)
                        : (isDarkMode ? const Color(0xFF2C2C2C) : Colors.grey[200]),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF82B366),
          labelColor: const Color(0xFF82B366),
          unselectedLabelColor: isDarkMode ? Colors.grey[600] : Colors.grey[600],
          tabs: [
            Tab(text: AppLocalizations.of(context)?.yourSubmissions ?? 'Tus envíos'),
            Tab(text: AppLocalizations.of(context)?.allSubmissions ?? 'Todos los envíos'),
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
                hintText: AppLocalizations.of(context)?.searchPhrases ?? 'Buscar frases...',
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
            child: TabBarView(
              controller: _tabController,
              children: [
                if (_deviceId != null)
                  SubmissionsTabView(
                    isLocal: true,
                    deviceId: _deviceId!,
                    isEditMode: _isEditMode,
                    searchQuery: _searchQuery,
                    optimisticReviewedStatus: _optimisticReviewedStatus,
                    pendingDeletes: _pendingDeletes,
                    pendingEdits: _pendingEdits,
                    pendingSubmissions: _pendingSubmissions,
                    onReviewChanged: _handleReviewChanged,
                    showEditDialog: (doc) => _showEditDialog(context, doc),
                    showDeleteDialog: (doc) => _showDeleteDialog(context, doc),
                    showEditPendingSubmissionDialog: _showEditPendingSubmissionDialog,
                    showDeletePendingSubmissionDialog: _showDeletePendingSubmissionDialog,
                  ),
                if (_deviceId == null)
                  const Center(child: CircularProgressIndicator()),
                SubmissionsTabView(
                  isLocal: false,
                  deviceId: '',
                  isEditMode: _isEditMode,
                  searchQuery: _searchQuery,
                  optimisticReviewedStatus: _optimisticReviewedStatus,
                  pendingDeletes: _pendingDeletes,
                  pendingEdits: _pendingEdits,
                  pendingSubmissions: _pendingSubmissions,
                  onReviewChanged: _handleReviewChanged,
                  showEditDialog: (doc) => _showEditDialog(context, doc),
                  showDeleteDialog: (doc) => _showDeleteDialog(context, doc),
                  showEditPendingSubmissionDialog: _showEditPendingSubmissionDialog,
                  showDeletePendingSubmissionDialog: _showDeletePendingSubmissionDialog,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SubmissionsTabView extends StatefulWidget {
  final bool isLocal;
  final String deviceId;
  final bool isEditMode;
  final String searchQuery;
  final Map<String, bool> optimisticReviewedStatus;
  final List<String> pendingDeletes;
  final List<Map<String, dynamic>> pendingEdits;
  final List<Map<String, dynamic>> pendingSubmissions;
  final Future<void> Function(DocumentSnapshot doc, bool value) onReviewChanged;
  final void Function(DocumentSnapshot doc) showEditDialog;
  final void Function(DocumentSnapshot doc) showDeleteDialog;
  final void Function(int index, Map<String, dynamic> submission) showEditPendingSubmissionDialog;
  final void Function(int index, Map<String, dynamic> submission) showDeletePendingSubmissionDialog;

  const SubmissionsTabView({
    super.key,
    required this.isLocal,
    required this.deviceId,
    required this.isEditMode,
    required this.searchQuery,
    required this.optimisticReviewedStatus,
    required this.pendingDeletes,
    required this.pendingEdits,
    required this.pendingSubmissions,
    required this.onReviewChanged,
    required this.showEditDialog,
    required this.showDeleteDialog,
    required this.showEditPendingSubmissionDialog,
    required this.showDeletePendingSubmissionDialog,
  });

  @override
  State<SubmissionsTabView> createState() => _SubmissionsTabViewState();
}

class _SubmissionsTabViewState extends State<SubmissionsTabView> with AutomaticKeepAliveClientMixin {
  String? _username;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_username == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey<String>(widget.isLocal ? 'local_${widget.deviceId}' : 'all'),
      stream: widget.isLocal
          ? FirebaseFirestore.instance
              .collection('achuar_submission')
              .where('user', isEqualTo: _username)
              .orderBy('timestamp', descending: true)
              .snapshots()
          : FirebaseFirestore.instance
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

        // Filter out items that are pending deletion
        docs = docs.where((doc) => !widget.pendingDeletes.contains(doc.id)).toList();

        if (widget.isLocal) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['user'] == _username;
          }).toList();
        }

        if (docs.isEmpty && widget.isLocal) {
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

        // Filter pending submissions based on tab
        final filteredPendingSubmissions = widget.isLocal
            ? widget.pendingSubmissions.where((submission) {
                return submission['deviceId'] == widget.deviceId;
              }).toList()
            : widget.pendingSubmissions;
        
        // Apply search filter to pending submissions
        final searchFilteredPending = widget.searchQuery.isNotEmpty
            ? filteredPendingSubmissions.where((submission) {
                final achuar = submission['achuar']?.toString().toLowerCase() ?? '';
                final spanish = submission['spanish']?.toString().toLowerCase() ?? '';
                final query = widget.searchQuery.toLowerCase();
                return achuar.contains(query) || spanish.contains(query);
              }).toList()
            : filteredPendingSubmissions;
        
        // Combine pending submissions with Firestore docs
        final totalItemCount = searchFilteredPending.length + docs.length;
        
        return ListView.builder(
          key: PageStorageKey<String>(widget.isLocal ? 'local_list_${widget.deviceId}' : 'all_list'),
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          itemCount: totalItemCount,
          itemBuilder: (context, index) {
            // Show pending submissions first
            if (index < searchFilteredPending.length) {
              return _buildPendingSubmissionItem(searchFilteredPending[index]);
            }
            // Then show Firestore docs
            final docIndex = index - searchFilteredPending.length;
            final doc = docs[docIndex];
            return _buildListItem(doc);
          },
        );
      },
    );
  }

  Widget _buildPendingSubmissionItem(Map<String, dynamic> submission) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Find the index for edit/delete operations
    final submissionIndex = widget.pendingSubmissions.indexOf(submission);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 3,
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Could show details or expand
          },
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.sync,
                                      size: 12,
                                      color: Colors.orange[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalizations.of(context)?.pending ?? 'Pendiente',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            submission['achuar'] ?? '',
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
                            submission['spanish'] ?? '',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      children: [
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
                                onPressed: () => widget.showEditPendingSubmissionDialog(submissionIndex, submission),
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
                                onPressed: () => widget.showDeletePendingSubmissionDialog(submissionIndex, submission),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                if (submission['location'] != null && submission['location'].toString().isNotEmpty) ...[
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
                        submission['location'],
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
                if (submission['notes'] != null && submission['notes'].toString().isNotEmpty) ...[
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
                          submission['notes'],
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

  Widget _buildListItem(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    
    // Apply pending edits optimistically
    final pendingEdit = widget.pendingEdits.firstWhere(
      (edit) => edit['docId'] == doc.id,
      orElse: () => {},
    );
    
    if (pendingEdit.isNotEmpty && pendingEdit['data'] != null) {
      // Merge the pending edit data with the original data
      data = Map<String, dynamic>.from(data);
      final editData = pendingEdit['data'] as Map<String, dynamic>;
      data.addAll(editData);
    }
    
    final bool isReviewed = widget.optimisticReviewedStatus[doc.id] ?? data['reviewed'] == true;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Check if there's a pending review change (optimistic value differs from Firestore value)
    final hasReviewChange = widget.optimisticReviewedStatus.containsKey(doc.id) && 
                            widget.optimisticReviewedStatus[doc.id] != (data['reviewed'] == true);
    
    // Show a badge if there are ANY pending changes (edits, reviews, deletes)
    final hasPendingChanges = pendingEdit.isNotEmpty || widget.pendingDeletes.contains(doc.id) || hasReviewChange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        elevation: isDarkMode ? 2 : 3,
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Could show details or expand
          },
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
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
                              if (hasPendingChanges)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sync,
                                        size: 12,
                                        color: Colors.orange[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context)?.pending ?? 'Pendiente',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (isReviewed)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 12,
                                        color: Colors.green[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        AppLocalizations.of(context)?.reviewed ?? 'Revisado',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
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
                    if (widget.isEditMode || (data['user'] != null && data['user'] == _username)) ...[
                      const SizedBox(width: 8),
                      Column(
                        children: [
                          if (widget.isEditMode) ...[
                            Checkbox(
                              value: isReviewed,
                              activeColor: const Color(0xFF82B366),
                              onChanged: (value) async {
                                await widget.onReviewChanged(doc, value ?? false);
                              },
                            ),
                            const SizedBox(height: 8),
                          ],
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
                if (data['location'] != null && data['location'].toString().isNotEmpty) ...[
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