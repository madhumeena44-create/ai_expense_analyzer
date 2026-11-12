# ai_expense_analyzer

A Flutter expense analyzer with an AI chat assistant.

## Gemini API key

The chat assistant reads its key from the `GEMINI_API_KEY` Dart compile-time
environment value. For local development, run the app with:

```shell
flutter run --dart-define=GEMINI_API_KEY=YOUR_API_KEY
```

Do not commit real API keys. Dart compile-time values are included in the
client application, so they can be extracted; use a backend to protect the key
in production.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
