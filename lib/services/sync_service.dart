import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  final _pendingSubmissionsController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get pendingSubmissionsStream => _pendingSubmissionsController.stream;

  static const String _deviceIdKey = 'deviceId';
  String? _deviceId;

  Future<void> initialize() async {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    final connectivityResult = await Connectivity().checkConnectivity();
    if (!connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint('Device is online. Syncing pending data.');
      await syncPendingData();
    } else {
      debugPrint('Device is offline.');
    }
    await loadPendingSubmissions();
  }

  void dispose() {
    _connectivitySubscription.cancel();
    _pendingSubmissionsController.close();
  }

  Future<String> getDeviceId() async {
    if (_deviceId != null) {
      return _deviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      if (kIsWeb) {
        deviceId = const Uuid().v4();
      } else {
        final deviceInfo = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceId = androidInfo.id;
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor;
        } else {
          deviceId = const Uuid().v4();
        }
      }
      await prefs.setString(_deviceIdKey, deviceId!);
    }
    
    _deviceId = deviceId;
    return _deviceId!;
  }

  Future<bool> isOffline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.none);
  }

  void _onConnectivityChanged(List<ConnectivityResult> result) {
    if (!result.contains(ConnectivityResult.none)) {
      debugPrint('Device is online. Syncing pending data.');
      syncPendingData();
    } else {
      debugPrint('Device is offline.');
    }
  }

  Future<bool> addSubmission(Map<String, dynamic> submission) async {
    bool isOfflineNow = await isOffline();
    final submissionWithTimestamp = Map<String, dynamic>.from(submission);

    // Add username from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username != null && username.isNotEmpty) {
      submissionWithTimestamp['user'] = username;
    }

    if (isOfflineNow) {
      submissionWithTimestamp['timestamp'] = 'FieldValue.serverTimestamp()';
      await _saveSubmissionLocally(submissionWithTimestamp);
      return true;
    } else {
      try {
        submissionWithTimestamp['timestamp'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('achuar_submission').add(submissionWithTimestamp);
        return false; // Submitted online
      } catch (e) {
        debugPrint('Online submission failed, saving locally: $e');
        submissionWithTimestamp['timestamp'] = 'FieldValue.serverTimestamp()';
        await _saveSubmissionLocally(submissionWithTimestamp);
        return true; // Fallback to saving locally
      }
    }
  }

  Future<void> _saveSubmissionLocally(Map<String, dynamic> submission) async {
    final prefs = await SharedPreferences.getInstance();
    final submissionsValue = prefs.get('pendingSubmissions');
    
    List<String> pending = [];
    
    // Handle different storage formats
    if (submissionsValue == null) {
      // No existing data
    } else if (submissionsValue is List<String>) {
      pending = List<String>.from(submissionsValue);
    } else if (submissionsValue is String) {
      // Data was stored as JSON string, convert to list
      try {
        final decoded = json.decode(submissionsValue);
        if (decoded is List) {
          pending = decoded.map((item) => jsonEncode(item)).toList();
        }
      } catch (e) {
        debugPrint('Error decoding existing submissions: $e');
      }
    } else if (submissionsValue is List) {
      // Handle generic List type
      pending = submissionsValue.map((item) => 
        item is String ? item : jsonEncode(item)
      ).toList();
    }
    
    pending.add(jsonEncode(submission));
    await prefs.setStringList('pendingSubmissions', pending);
    await loadPendingSubmissions();
  }

  Future<void> loadPendingSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final submissionsValue = prefs.get('pendingSubmissions');

    List<Map<String, dynamic>> pendingSubmissions = [];
    
    try {
      if (submissionsValue == null) {
        // No submissions stored
      } else if (submissionsValue is String) {
        try {
          final decoded = json.decode(submissionsValue);
          if (decoded is List) {
            pendingSubmissions = decoded.map((item) {
              if (item is Map<String, dynamic>) {
                return item;
              } else if (item is Map) {
                return Map<String, dynamic>.from(item);
              } else {
                debugPrint('Unexpected item type in decoded submissions: ${item.runtimeType}');
                return <String, dynamic>{};
              }
            }).toList();
          }
        } catch (e) {
          debugPrint('Error decoding submissions string: $e');
        }
      } else if (submissionsValue is List<String>) {
        pendingSubmissions = submissionsValue.map((s) {
          try {
            final decoded = jsonDecode(s);
            if (decoded is Map<String, dynamic>) {
              return decoded;
            } else if (decoded is Map) {
              return Map<String, dynamic>.from(decoded);
            } else {
              debugPrint('Unexpected decoded type: ${decoded.runtimeType}');
              return <String, dynamic>{};
            }
          } catch (e) {
            debugPrint('Error decoding submission: $e');
            return <String, dynamic>{};
          }
        }).where((item) => item.isNotEmpty).toList();
      } else if (submissionsValue is List) {
        // Handle other list types
        pendingSubmissions = submissionsValue.map((item) {
          if (item is Map<String, dynamic>) {
            return item;
          } else if (item is Map) {
            return Map<String, dynamic>.from(item);
          } else if (item is String) {
            try {
              final decoded = jsonDecode(item);
              if (decoded is Map<String, dynamic>) {
                return decoded;
              } else if (decoded is Map) {
                return Map<String, dynamic>.from(decoded);
              }
            } catch (e) {
              debugPrint('Error decoding list item: $e');
            }
          }
          debugPrint('Unexpected list item type: ${item.runtimeType}');
          return <String, dynamic>{};
        }).where((item) => item.isNotEmpty).cast<Map<String, dynamic>>().toList();
      } else {
        debugPrint('Unexpected submissions value type: ${submissionsValue.runtimeType}');
      }
    } catch (e) {
      debugPrint('Error loading pending submissions: $e');
      pendingSubmissions = [];
    }
    
    _pendingSubmissionsController.add(pendingSubmissions);
  }

  Future<void> syncPendingData() async {
    await _syncPendingSubmissions();
    await _syncPendingEdits();
    await loadPendingSubmissions();
  }

  Future<void> _syncPendingSubmissions() async {
    final prefs = await SharedPreferences.getInstance();
    final submissionsValue = prefs.get('pendingSubmissions');

    List<Map<String, dynamic>> pendingSubmissions = [];
    if (submissionsValue is String) {
      final decoded = json.decode(submissionsValue);
      if (decoded is List) {
        pendingSubmissions = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } else if (submissionsValue is List<String>) {
      pendingSubmissions = submissionsValue.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    }

    if (pendingSubmissions.isEmpty) {
      return;
    }

    debugPrint('Syncing ${pendingSubmissions.length} pending submissions.');

    final collection = FirebaseFirestore.instance.collection('achuar_submission');
    final List<Map<String, dynamic>> successfullySynced = [];

    for (var submission in pendingSubmissions) {
      try {
        final submissionData = Map<String, dynamic>.from(submission);
        if (submissionData['timestamp'] == 'FieldValue.serverTimestamp()') {
            submissionData['timestamp'] = FieldValue.serverTimestamp();
        }

        await collection.add(submissionData);
        successfullySynced.add(submission);
      } catch (e) {
        debugPrint('Error syncing submission: $e');
        break;
      }
    }

    if (successfullySynced.isNotEmpty) {
      final updatedPendingSubmissions = List<Map<String, dynamic>>.from(pendingSubmissions);
      successfullySynced.forEach((syncedItem) {
        updatedPendingSubmissions.removeWhere((pendingItem) => 
            pendingItem['achuar'] == syncedItem['achuar'] && 
            pendingItem['spanish'] == syncedItem['spanish']);
      });

      final List<String> remainingSubmissions = updatedPendingSubmissions.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList('pendingSubmissions', remainingSubmissions);
      debugPrint('${successfullySynced.length} submissions synced successfully.');
    }
  }

  Future<void> _syncPendingEdits() async {
    final prefs = await SharedPreferences.getInstance();
    final editsValue = prefs.get('pendingEdits');

    List<Map<String, dynamic>> pendingEdits = [];
    if (editsValue is String) {
        final decoded = json.decode(editsValue);
        if (decoded is List) {
            pendingEdits = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        }
    } else if (editsValue is List<String>) {
        pendingEdits = editsValue.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    }


    if (pendingEdits.isEmpty) {
      return;
    }

    debugPrint('Syncing ${pendingEdits.length} pending edits.');

    final List<Map<String, dynamic>> successfullySynced = [];

    for (var edit in pendingEdits) {
      try {
        final docId = edit['docId'];
        final data = Map<String, dynamic>.from(edit['data']);
        
        if (data['last_edited'] == 'FieldValue.serverTimestamp()') {
            data['last_edited'] = FieldValue.serverTimestamp();
        }

        await FirebaseFirestore.instance.collection('achuar_dictionary_proposals').doc(docId).update(data);
        successfullySynced.add(edit);
      } catch (e) {
        debugPrint('Error syncing edit: $e');
        break;
      }
    }

    if (successfullySynced.isNotEmpty) {
      final updatedPendingEdits = List<Map<String, dynamic>>.from(pendingEdits);
      successfullySynced.forEach((syncedItem) {
        updatedPendingEdits.removeWhere((pendingItem) => pendingItem['docId'] == syncedItem['docId']);
      });
      final List<String> remainingEdits = updatedPendingEdits.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList('pendingEdits', remainingEdits);
      debugPrint('${successfullySynced.length} edits synced successfully.');
    }
  }
}
