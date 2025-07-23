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

const String googleApiKey = 'AIzaSyCIWtCOazyf_2ZIJsy0-3clhm1K-eH-EWk'; // TODO: Replace with a secure method to store API key
FlutterTts? _webTts;
bool _webTtsConfigured = false;

Future<void> playEnglishTTS(String text, {BuildContext? context}) async {
  if (kIsWeb) {
    try {
      _webTts ??= FlutterTts();
      if (!_webTtsConfigured) {
        await _webTts!.setLanguage('en-US');
        await _webTts!.setPitch(1.0);
        await _webTts!.setSpeechRate(0.9);
        _webTtsConfigured = true;
      }
      await _webTts!.speak(text);
    } catch (e) {
      print('[TTS] Web TTS Exception: $e');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el audio en la web.')),
        );
      }
    }
    return;
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
    return;
  }
  try {
    if (googleApiKey == 'YOUR_GOOGLE_API_KEY') {
      print("Error: Google API key is not set.");
      return;
    }
    final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize?key=$googleApiKey');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'input': {'text': text},
        'voice': {'languageCode': 'en-US', 'ssmlGender': 'NEUTRAL'},
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    );
    if (response.statusCode == 200) {
      final audioContent = jsonDecode(response.body)['audioContent'];
      final bytes = base64Decode(audioContent);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tts_audio.mp3');
      await file.writeAsBytes(bytes);
      final player = AudioPlayer();
      await player.play(DeviceFileSource(file.path));
      player.onPlayerComplete.listen((event) {
        file.delete();
      });
    } else {
      print('Failed to get TTS audio: ${response.body}');
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el audio.')),
        );
      }
    }
  } catch (e) {
    print('[TTS] Exception: $e');
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reproducir el audio.')),
      );
    }
  }
}

Future<String?> downloadAndSaveEnglishTTS(String text, {String? filename, bool forLesson = false, BuildContext? context}) async {
  if (kIsWeb) {
    try {
      _webTts ??= FlutterTts();
      if (!_webTtsConfigured) {
        await _webTts!.setLanguage('en-US');
        await _webTts!.setPitch(1.0);
        await _webTts!.setSpeechRate(0.9);
        _webTtsConfigured = true;
      }
      await _webTts!.speak(text);
      return null; // No file path on web
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
        'voice': {'languageCode': 'en-US', 'ssmlGender': 'NEUTRAL'},
        'audioConfig': {'audioEncoding': 'MP3'},
      }),
    );
    if (response.statusCode == 200) {
      final audioContent = jsonDecode(response.body)['audioContent'];
      final bytes = base64Decode(audioContent);
      final dir = await getApplicationDocumentsDirectory();
      final safeName = (filename ?? text).replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      String filePath;
      if (forLesson) {
        final lessonDir = Directory('${dir.path}/offline_lesson_audio');
        if (!lessonDir.existsSync()) lessonDir.createSync(recursive: true);
        filePath = '${lessonDir.path}/$safeName.mp3';
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
  return paths;
}