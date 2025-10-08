# Google Cloud Translation API Implementation Guide

## Overview
This guide outlines how to replace the current unofficial `translator` package with the official Google Cloud Translation API for more consistent and accurate translations.

## Current vs. Proposed Implementation

### Current Implementation Issues:
- Uses unofficial `translator` package
- Inconsistent results compared to Google Translate web
- Limited configuration options
- No control over translation models

### Benefits of Official API:
- ✅ Same translation quality as Google Translate web
- ✅ Advanced configuration options
- ✅ Better reliability and support
- ✅ Access to latest translation models
- ✅ Enhanced context understanding

## Implementation Steps

### 1. Dependencies Update

Add to `pubspec.yaml`:
```yaml
dependencies:
  googleapis: ^13.0.0
  googleapis_auth: ^1.4.1
  http: ^1.1.0
  
  # Remove the current translator package
  # translator: ^0.1.7  # REMOVE THIS
```

### 2. API Key Setup

#### Option A: Service Account (Recommended for Production)
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the Cloud Translation API
4. Create a Service Account Key
5. Download the JSON key file

#### Option B: API Key (Simpler for Development)
1. Go to Google Cloud Console → APIs & Credentials
2. Create API Key
3. Restrict to Cloud Translation API

### 3. Environment Configuration

Add to `env.json`:
```json
{
  "GOOGLE_CLOUD_PROJECT_ID": "your-project-id",
  "GOOGLE_CLOUD_API_KEY": "your-api-key",
  "GOOGLE_APPLICATION_CREDENTIALS": "path/to/service-account.json"
}
```

### 4. Translation Service Implementation

Create `lib/services/google_cloud_translation_service.dart`:

```dart
import 'package:googleapis/translate/v3.dart' as translate;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GoogleCloudTranslationService {
  static const List<String> _scopes = [translate.TranslateApi.cloudPlatformScope];
  late translate.TranslateApi _translateApi;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final projectId = dotenv.env['GOOGLE_CLOUD_PROJECT_ID'];
      final apiKey = dotenv.env['GOOGLE_CLOUD_API_KEY'];
      
      if (apiKey != null && apiKey.isNotEmpty) {
        // Use API Key method (simpler)
        final client = http.Client();
        _translateApi = translate.TranslateApi(client);
        _initialized = true;
      } else {
        // Use Service Account (more secure)
        final credentials = await obtainAccessCredentialsViaServiceAccount(
          ServiceAccountCredentials.fromJson(
            // Load from service account JSON
          ),
          _scopes,
          http.Client(),
        );
        
        final client = authenticatedClient(http.Client(), credentials);
        _translateApi = translate.TranslateApi(client);
        _initialized = true;
      }
    } catch (e) {
      print('Failed to initialize Google Cloud Translation: $e');
      throw Exception('Translation service initialization failed');
    }
  }

  Future<String> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? context,
    bool enhanced = true,
  }) async {
    await initialize();

    try {
      final projectId = dotenv.env['GOOGLE_CLOUD_PROJECT_ID'];
      final parent = 'projects/$projectId/locations/global';

      final request = translate.TranslateTextRequest();
      request.contents = [text];
      request.sourceLanguageCode = sourceLanguage;
      request.targetLanguageCode = targetLanguage;
      request.parent = parent;

      if (enhanced) {
        // Use advanced translation model
        request.model = 'projects/$projectId/locations/global/models/nmt';
      }

      if (context != null && context.isNotEmpty) {
        // Add glossary or context if needed
        request.glossaryConfig = translate.TranslateTextGlossaryConfig();
      }

      final response = await _translateApi.projects.locations.translateText(
        request,
        parent,
      );

      if (response.translations?.isNotEmpty == true) {
        return response.translations!.first.translatedText ?? text;
      } else {
        throw Exception('No translation received');
      }
    } catch (e) {
      print('Translation error: $e');
      throw Exception('Translation failed: $e');
    }
  }

  Future<List<String>> translateBatch({
    required List<String> texts,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    await initialize();

    try {
      final projectId = dotenv.env['GOOGLE_CLOUD_PROJECT_ID'];
      final parent = 'projects/$projectId/locations/global';

      final request = translate.TranslateTextRequest();
      request.contents = texts;
      request.sourceLanguageCode = sourceLanguage;
      request.targetLanguageCode = targetLanguage;
      request.parent = parent;

      final response = await _translateApi.projects.locations.translateText(
        request,
        parent,
      );

      return response.translations?.map((t) => t.translatedText ?? '').toList() ?? [];
    } catch (e) {
      print('Batch translation error: $e');
      throw Exception('Batch translation failed: $e');
    }
  }

  Future<String> detectLanguage(String text) async {
    await initialize();

    try {
      final projectId = dotenv.env['GOOGLE_CLOUD_PROJECT_ID'];
      final parent = 'projects/$projectId/locations/global';

      final request = translate.DetectLanguageRequest();
      request.content = text;
      request.parent = parent;

      final response = await _translateApi.projects.locations.detectLanguage(
        request,
        parent,
      );

      return response.languages?.first.languageCode ?? 'unknown';
    } catch (e) {
      print('Language detection error: $e');
      return 'unknown';
    }
  }
}
```

### 5. Update Translation Logic

Replace translation calls in `translator_screen.dart`:

```dart
// Replace the existing _performTranslation method
Future<String> _performTranslation(String sourceText, {bool useContext = true}) async {
  final processedText = _preprocessText(sourceText);
  
  try {
    if (kIsWeb || _isConnected) {
      // Use Google Cloud Translation API
      final translationService = GoogleCloudTranslationService();
      
      final translatedText = await translationService.translateText(
        text: processedText,
        sourceLanguage: 'es',
        targetLanguage: 'en',
        context: useContext ? 'Educational translation for language learning' : null,
        enhanced: true,
      );
      
      return _postprocessTranslation(translatedText);
    } else if (_modelsDownloaded && _onDeviceTranslator != null) {
      // Fallback to offline ML Kit
      final translation = await _onDeviceTranslator!.translateText(processedText);
      return _postprocessTranslation(translation);
    } else {
      throw Exception('Sin conexión. Descargue los modelos o conéctese a internet.');
    }
  } catch (e) {
    print('[TRANSLATE] Google Cloud API error: $e');
    
    // Fallback to existing translator package
    final translator = GoogleTranslator();
    final translation = await translator.translate(processedText, from: 'es', to: 'en');
    return _postprocessTranslation(translation.text);
  }
}
```

## Cost Considerations

### Google Cloud Translation Pricing (2024):
- **Free Tier**: 500,000 characters/month
- **After Free Tier**: $20 per 1M characters
- **Advanced Features**: Additional costs for glossaries, models

### Cost Optimization:
1. **Caching**: Store translations locally
2. **Batch Processing**: Group multiple translations
3. **Smart Fallbacks**: Use offline models when possible
4. **User Limits**: Implement daily/monthly limits

## Security Best Practices

1. **API Key Protection**: Never commit keys to version control
2. **Key Restrictions**: Limit API key to specific IPs/domains
3. **Service Accounts**: Use least-privilege principle
4. **Environment Variables**: Store credentials securely

## Testing Strategy

1. **Unit Tests**: Test translation service methods
2. **Integration Tests**: Test with actual API calls
3. **Fallback Tests**: Ensure graceful degradation
4. **Performance Tests**: Monitor response times

## Migration Plan

### Phase 1: Parallel Implementation
- Keep existing translator package
- Add Google Cloud Translation alongside
- A/B test translation quality

### Phase 2: Primary Switch
- Make Google Cloud Translation primary
- Keep existing as fallback
- Monitor error rates and quality

### Phase 3: Full Migration
- Remove old translator package
- Full Google Cloud Translation implementation
- Optimize for performance and cost

## Quality Improvements Expected

1. **Consistency**: Same results as Google Translate web
2. **Context Awareness**: Better handling of specialized terms
3. **Regional Variants**: Proper Spanish dialect handling
4. **Technical Terms**: Better translation of educational content
5. **Batch Processing**: Efficient handling of multiple translations

## Implementation Timeline

- **Week 1**: API setup and service creation
- **Week 2**: Integration with existing screens
- **Week 3**: Testing and fallback implementation
- **Week 4**: Production deployment and monitoring

Would you like me to proceed with implementing any specific part of this plan?
