// lib/services/tts_web_helper.dart
// Only for web!
import 'dart:html' as html;

void playWebAudio(List<int> bytes, void Function() onComplete) {
  try {
    print('[WEB TTS] Creating blob with ${bytes.length} bytes');
    final blob = html.Blob([bytes], 'audio/mpeg');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);
    print('[WEB TTS] Created blob URL: $blobUrl');
    
    final audio = html.AudioElement(blobUrl);
    
    audio.onEnded.listen((event) {
      print('[WEB TTS] Audio playback ended');
      html.Url.revokeObjectUrl(blobUrl);
      onComplete();
    });
    
    audio.onError.listen((event) {
      print('[WEB TTS] Audio playback error: $event');
      html.Url.revokeObjectUrl(blobUrl);
      onComplete();
    });
    
    print('[WEB TTS] Starting audio playback');
    audio.play().catchError((error) {
      print('[WEB TTS] Error starting playback: $error');
      html.Url.revokeObjectUrl(blobUrl);
      onComplete();
    });
    
  } catch (e) {
    print('[WEB TTS] Exception in playWebAudio: $e');
    onComplete();
  }
} 