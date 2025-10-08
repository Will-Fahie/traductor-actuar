import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'tts_web_helper_stub.dart'
    if (dart.library.html) 'tts_web_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Get API key from environment variables
String get googleApiKey => dotenv.env['GOOGLE_TTS_API_KEY'] ?? 'YOUR_GOOGLE_API_KEY';
FlutterTts? _webTts;
bool _webTtsConfigured = false;

Future<void> playEnglishTTS(String text, {BuildContext? context, bool checkAnimalAudio = false}) async {
  print('[TTS] Starting TTS for text: "$text"');
  print('[TTS] kIsWeb: $kIsWeb');
  print('[TTS] Google API Key: ${googleApiKey.substring(0, 10)}...');
  
  if (kIsWeb) {
    try {
      print('[TTS] Using web TTS service');
      // Use Google TTS API for better quality on web
      final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleApiKey');
      print('[TTS] Making request to: $url');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': 'en-MX', 'ssmlGender': 'MALE'},
          'audioConfig': {
            'audioEncoding': 'MP3',
            'volumeGainDb': 12.0, // Increase volume by 12dB
            'speakingRate': 0.9, // Slightly slower for better clarity
          },
        }),
      );
      
      print('[TTS] Response status: ${response.statusCode}');
      print('[TTS] Response body: ${response.body.substring(0, 200)}...');
      
      if (response.statusCode == 200) {
        final audioContent = jsonDecode(response.body)['audioContent'];
        final bytes = base64Decode(audioContent);
        print('[TTS] Audio bytes length: ${bytes.length}');
        
        // Play using web helper
        playWebAudio(bytes, () {
          print('[TTS] Web audio playback completed');
        });
      } else {
        print('[TTS] Failed to get TTS audio: ${response.body}');
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al reproducir audio: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('[TTS] Web TTS Exception: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No se pudo reproducir el audio en la web.'),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
    return;
  }
  
  final connectivity = await Connectivity().checkConnectivity();
  print('[TTS] Connectivity: $connectivity');
  
  // Check for offline animal audio first
  if (checkAnimalAudio && !kIsWeb) {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safeName = text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final animalDir = Directory('${dir.path}/offline_animal_audio');
      final filePath = '${animalDir.path}/$safeName.mp3';
      final file = File(filePath);
      
      if (file.existsSync()) {
        print('[TTS] Playing offline animal audio: $filePath');
        final player = AudioPlayer();
        await player.setVolume(1.5);
        await player.play(DeviceFileSource(filePath));
        await player.onPlayerComplete.first;
        return;
      }
    } catch (e) {
      print('[TTS] Error playing offline animal audio: $e');
    }
  }
  
  // Enhanced offline detection
  if (connectivity == ConnectivityResult.none || connectivity.contains(ConnectivityResult.none)) {
    print('[TTS] Device is offline - connectivity: $connectivity');
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)?.audioNotAvailableOffline ?? 'Audio no disponible sin conexión. Descargue la lección cuando esté en línea para guardar el audio para uso offline.',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      print('[TTS] Not connected to the internet.');
    }
    return;
  }
  
  try {
    if (googleApiKey == 'YOUR_GOOGLE_API_KEY') {
      print("[TTS] Error: Google API key is not set.");
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: API key no configurada'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    print('[TTS] Making TTS request for: "$text"');
    final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleApiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': text},
        'voice': {'languageCode': 'en-MX', 'ssmlGender': 'MALE'},
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    );
    
    print('[TTS] Response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final audioContent = jsonDecode(response.body)['audioContent'];
      final bytes = base64Decode(audioContent);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_audio.mp3');
      await file.writeAsBytes(bytes);
      print('[TTS] Audio file saved to: ${file.path}');
      
      final player = AudioPlayer();
              await player.setVolume(1.5); // Set volume to maximum
      await player.play(DeviceFileSource(file.path));
      print('[TTS] Audio playback started with volume: 1.0');
      
      player.onPlayerComplete.listen((event) {
        print('[TTS] Audio playback completed');
        file.delete();
      });
    } else {
      print('[TTS] Failed to get TTS audio: ${response.body}');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reproducir audio: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } catch (e) {
    print('[TTS] Exception: $e');
    if (context != null) {
      // Check if it's a network-related error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('socketexception') || 
          errorString.contains('clientexception') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('no address associated with hostname')) {
        // Network error - show user-friendly offline message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_off, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.audioNotAvailableOffline ?? 'Audio no disponible sin conexión. Descargue la lección cuando esté en línea para guardar el audio para uso offline.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.blue[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } else {
        // Other errors - show generic error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No se pudo reproducir el audio en este momento.'),
                ),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}

Future<String?> downloadAndSaveEnglishTTS(String text, {String? filename, bool forLesson = false, bool forList = false, bool forAnimal = false, BuildContext? context}) async {
  if (kIsWeb) {
    try {
      // Use Google TTS API for better quality on web
      final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleApiKey');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': 'en-MX', 'ssmlGender': 'MALE'},
          'audioConfig': {'audioEncoding': 'MP3'},
        }),
      );
      
      if (response.statusCode == 200) {
        final audioContent = jsonDecode(response.body)['audioContent'];
        final bytes = base64Decode(audioContent);
        
        // Play using web helper
        playWebAudio(bytes, () {});
        
        return null; // No file path on web
      } else {
        print('Failed to get TTS audio: ${response.body}');
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo reproducir el audio.')),
          );
        }
        return null;
      }
    } catch (e) {
      print('[TTS] Web TTS Exception: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el audio en la web.')),
        );
      }
      return null;
    }
  }
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity == ConnectivityResult.none) {
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sin conexión. Descargue el audio para usarlo sin conexión.')),
      );
    } else {
      print('[TTS] Not connected to the internet.');
    }
    return null;
  }
  try {
    if (googleApiKey == 'YOUR_GOOGLE_API_KEY') {
      print("Error: Google API key is not set.");
      return null;
    }
    final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleApiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': text},
        'voice': {'languageCode': 'en-MX', 'ssmlGender': 'MALE'},
                  'audioConfig': {
            'audioEncoding': 'MP3',
            'volumeGainDb': 12.0, // Increase volume by 12dB
            'speakingRate': 0.9, // Slightly slower for better clarity
          },
      }),
    );
    if (response.statusCode == 200) {
      final audioContent = jsonDecode(response.body)['audioContent'];
      final bytes = base64Decode(audioContent);
      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final safeName = (filename ?? text).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        String filePath;
        if (forList) {
          final listDir = Directory('${dir.path}/offline_list_audio');
          if (!listDir.existsSync()) listDir.createSync(recursive: true);
          filePath = '${listDir.path}/$safeName.mp3';
        } else if (forLesson) {
          final lessonDir = Directory('${dir.path}/offline_lesson_audio');
          if (!lessonDir.existsSync()) lessonDir.createSync(recursive: true);
          filePath = '${lessonDir.path}/$safeName.mp3';
        } else if (forAnimal) {
          final animalDir = Directory('${dir.path}/offline_animal_audio');
          if (!animalDir.existsSync()) animalDir.createSync(recursive: true);
          filePath = '${animalDir.path}/$safeName.mp3';
        } else {
          filePath = '${dir.path}/tts_$safeName.mp3';
        }
        print('[TTS] Writing audio file to: $filePath');
        try {
          final file = File(filePath);
          await file.writeAsBytes(bytes);
          return file.path;
        } catch (e) {
          print('[TTS] Error writing file: $e');
          if (context != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo guardar el audio.')),
            );
          }
          return null;
        }
      }
      return null; // No file path on web
    } else {
      print('Failed to download TTS audio: ${response.body}');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo descargar el audio.')),
        );
      }
      return null;
    }
  } catch (e) {
    print('[TTS] Exception: $e');
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo descargar el audio.')),
      );
    }
    return null;
  }
}

Future<bool> isAnimalAudioDownloaded(String animalName) async {
  if (kIsWeb) return false;
  
  try {
    final dir = await getApplicationDocumentsDirectory();
    final safeName = animalName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final animalDir = Directory('${dir.path}/offline_animal_audio');
    final filePath = '${animalDir.path}/$safeName.mp3';
    final file = File(filePath);
    return file.existsSync();
  } catch (e) {
    print('[TTS] Error checking animal audio: $e');
    return false;
  }
}

Future<List<String>> downloadLessonTTS(List<String> phrases) async {
  if (kIsWeb) {
    // On web, just play the TTS for each phrase, do not save files
    for (final phrase in phrases) {
      await downloadAndSaveEnglishTTS(phrase);
    }
    return [];
  }
  List<String> paths = [];
  for (final phrase in phrases) {
    final path = await downloadAndSaveEnglishTTS(phrase, forLesson: true);
    if (path != null) paths.add(path);
  }
  return paths;
}

Future<List<String>> downloadCustomLessonTTS(List<String> phrases, {BuildContext? context}) async {
  if (kIsWeb) {
    for (final phrase in phrases) {
      await downloadAndSaveEnglishTTS(phrase, context: context);
    }
    return [];
  }
  List<String> paths = [];
  if (!kIsWeb) {
    final dir = await getApplicationDocumentsDirectory();
    final lessonDir = Directory('${dir.path}/offline_lesson_audio');
    if (!lessonDir.existsSync()) lessonDir.createSync(recursive: true);
    for (final phrase in phrases) {
      final safeName = phrase.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final filePath = '${lessonDir.path}/$safeName.mp3';
      print('[TTS] Attempting to save custom lesson audio: $filePath');
      final path = await downloadAndSaveEnglishTTS(phrase, filename: safeName, forLesson: true, context: context);
      if (path != null && path != filePath) {
        try {
          final file = File(path);
          await file.copy(filePath);
          print('[TTS] Copied file to: $filePath');
          paths.add(filePath);
        } catch (e) {
          print('[TTS] Error copying file: $e');
        }
      } else if (path != null) {
        paths.add(path);
      }
    }
  }
  return paths;
}