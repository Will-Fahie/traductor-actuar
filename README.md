# Traductor Achuar

## Setup

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Add your Firebase config files:
   - `android/app/google-services.json`
   - `ios/Runner/GoogleService-Info.plist`

3. Add `env.json` with your API keys:
   ```json
   {
     "GOOGLE_TTS_API_KEY": "your-key-here"
   }
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Features

- Dictionary lookup
- Text translation
- Custom lessons
- Teaching resources
- Offline translation support
