import 'dart:convert';
// for turning JSON text into dart objects and back
import 'package:http/http.dart' as http;
// for calling the Groq web API
import 'package:tpmentorship/constants/groq_config.dart';
// the shared Groq key, endpoint and model

enum BioSource {
// where a bio actually came from. the UI reports this so you can tell
// whether the Groq call worked or whether it quietly fell back to the
// offline template (important during the live demo)
  groq,
  localTemplate,
}

class GeneratedBio {
// one drafted bio and where it came from
  const GeneratedBio({required this.text, required this.source});
  final String text;
  final BioSource source;
}

class BioWriterService {
// drafts a short profile bio from the facts the student has already
// entered (school, diploma, year, subjects)
//
// how it works:
// 1. if a Groq API key is set, those facts go to a Llama model hosted by
//    Groq, which writes a short first-person bio
// 2. if there is no key, or the call fails (no internet, quota hit), a
//    local sentence template is used instead - so the button always does
//    something, even during a live demo with no network

  BioWriterService({String? apiKey, http.Client? client})
      : apiKey = apiKey ?? GroqConfig.apiKey,
        _client = client ?? http.Client();

  // the key this instance actually uses. defaults to the shared const;
  // tests pass their own so they never depend on a real key being set
  final String apiKey;

  // injectable so tests can drive the live path with a MockClient instead
  // of reaching the network
  final http.Client _client;

  // the bio box is capped at 150 characters, so anything longer has to be
  // trimmed before it reaches the field
  static const int _maxLength = 150;

  // true when a key is available. same startsWith guard as
  // AiMatchingService: the placeholder is a non-empty string, so without
  // it the app would call Groq, get a 401, and fall back silently
  bool get isGroqConfigured =>
      apiKey.isNotEmpty && !apiKey.startsWith('PASTE_');

  // main entry point - never throws, so the button always gets a bio back
  Future<GeneratedBio> writeBio({
    required String school,
    required String diploma,
    required String academicYear,
    required List<String> subjects,
  }) async {
    if (!isGroqConfigured) {
      return _template(school, diploma, academicYear, subjects);
    }
    try {
      return await _groqBio(school, diploma, academicYear, subjects);
    } catch (_) {
      // API failed (offline, quota, bad response) - fall back so the
      // button never leaves the user with nothing
      return _template(school, diploma, academicYear, subjects);
    }
  }

  // ---------- option 1: ask Groq to write the bio ----------

  Future<GeneratedBio> _groqBio(String school, String diploma,
      String academicYear, List<String> subjects) async {
    // 140 rather than 150 leaves headroom so the clamp rarely fires.
    // the "do not invent facts" rule is load-bearing: other students read
    // these bios, so a model adding a fake achievement would be putting a
    // fabrication in a real person's profile
    final prompt = '''
Write a short first-person bio for a polytechnic student's peer-mentoring
profile.

Student:
- school: $school
- diploma: $diploma
- year: ${academicYear.isEmpty ? 'unknown' : academicYear}
- wants help with: ${subjects.isEmpty ? 'not specified' : subjects.join(', ')}

Rules:
- First person, friendly, natural.
- Under 140 characters.
- No quotes, no hashtags, no emoji.
- Do not invent facts - no grades, CCAs, jobs, or hobbies.
- Reply with ONLY the bio text.
''';

    final response = await _client
        .post(
          Uri.parse(GroqConfig.endpoint),
          headers: {
            'Content-Type': 'application/json',
            // the key travels in a header rather than the query string, so
            // it does not get written into server logs and proxy caches
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': GroqConfig.model,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 15));
    // give up after 15s rather than leaving the button spinning forever

    if (response.statusCode != 200) {
      throw Exception('Groq API error ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = (body['choices'][0]['message']['content'] as String).trim();

    final text = _clamp(_stripQuotes(raw));
    if (text.isEmpty) throw Exception('Groq returned an empty bio');
    // an empty bio is worse than the template, so treat it as a failure

    return GeneratedBio(text: text, source: BioSource.groq);
  }

  // models like to wrap the reply in quotes even when told not to. only a
  // matched pair is stripped, so a bio that legitimately contains a quote
  // is left alone
  static String _stripQuotes(String text) {
    if (text.length < 2) return text;
    final first = text[0];
    final last = text[text.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return text.substring(1, text.length - 1).trim();
    }
    return text;
  }

  // cut at the last word boundary under the limit, so a trimmed bio ends
  // on a whole word rather than mid-syllable
  static String _clamp(String text) {
    if (text.length <= _maxLength) return text;
    final cut = text.substring(0, _maxLength);
    final lastSpace = cut.lastIndexOf(' ');
    return (lastSpace <= 0 ? cut : cut.substring(0, lastSpace)).trimRight();
  }

  // ---------- option 2: local sentence template (the fallback) ----------

  GeneratedBio _template(String school, String diploma, String academicYear,
      List<String> subjects) {
    // "Year 2 student in X" / "Student in X" when the year is not set yet
    final opening = academicYear.isEmpty
        ? 'Student in $diploma'
        : '$academicYear student in $diploma';

    final text = subjects.isEmpty
        // no subjects picked yet - name the school so the bio still says
        // something beyond the course
        ? '$opening at $school.'
        : '$opening. Looking for help with ${_humanList(subjects)}.';

    return GeneratedBio(text: _clamp(text), source: BioSource.localTemplate);
  }

  // "A", "A and B", "A, B and C" - so the sentence reads like prose
  // rather than a comma separated list
  static String _humanList(List<String> items) {
    if (items.length == 1) return items.first;
    final head = items.sublist(0, items.length - 1).join(', ');
    return '$head and ${items.last}';
  }
}
