// everything needed to call Groq, in one place so the two services that
// use it (AiMatchingService, BioWriterService) cannot drift apart - and so
// rotating the key is a one-line change in one file
class GroqConfig {
  // no key is committed - pass your free Groq key (https://console.groq.com)
  // in at run time; without one the app uses its offline matching fallback:
  //   flutter run --dart-define=GROQ_API_KEY=your_key_here
  static const String apiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  // Groq's OpenAI-compatible chat completions API
  static const String endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  // small and fast, which suits both the ranking and the bio prompt
  static const String model = 'llama-3.1-8b-instant';

  // the placeholder text is a non-empty string, so without the startsWith
  // check the app would think an unset key was a real one
  static bool get isConfigured =>
      apiKey.isNotEmpty && !apiKey.startsWith('PASTE_');
}
