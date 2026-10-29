# TPMentorship

A Flutter + Firebase Android app that pairs Temasek Polytechnic students with peer mentors. Built for the Mobile App Development module.

## Features
- 20+ screens with Riverpod state management and a layered services architecture
- Firestore-backed session booking, chat, reviews and profiles
- Five Firebase Auth sign-in paths, plus a biometric app lock
- AI mentor matching through Groq-hosted Llama 3.1, with an offline ranking fallback
- NETS sandbox QR payments
- Scheduled local notifications
- 26 unit and widget test files, with an injected HTTP client so the AI and payment paths can be tested offline

## Running it
```bash
flutter pub get
flutter run --dart-define=GROQ_API_KEY=your_groq_key
```
The Groq key is optional. Without it, mentor matching uses the local formula.

## Tests
```bash
flutter test
```
