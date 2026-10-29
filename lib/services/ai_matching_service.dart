import 'dart:convert';
// for turning JSON text into dart objects and back
import 'package:http/http.dart' as http;
// for calling the Groq web API
import 'package:tpmentorship/constants/groq_config.dart';
// the shared Groq key, endpoint and model
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/models/user_profile.dart';
// the data types

enum MatchSource {
// where a ranking actually came from. the UI shows this so you can tell
// at a glance whether the Groq call worked or whether it quietly fell
// back to the offline formula (important during the live demo)
  groq,
  localFallback,
}

class MentorMatch {
// one AI recommendation: a mentor, how well they fit (0-100)
// and a short explanation of why
  final Mentor mentor;
  final int score;
  final String reason;
  final MatchSource source;

  MentorMatch({
    required this.mentor,
    required this.score,
    required this.reason,
    required this.source,
  });
}

class AiMatchingService {
// the applied AI feature: recommends the best mentors for this student
//
// how it works:
// 1. if a Groq API key is set, the student's profile and the mentor list
//    are sent to a Llama model hosted by Groq, which ranks the mentors
//    and writes a short reason for each match
// 2. if there is no key, or the API call fails (no internet, quota hit),
//    a local scoring formula ranks them instead - so the feature
//    always works, even during a live demo with no network

  // the shared key - see lib/constants/groq_config.dart
  static const String groqApiKey = GroqConfig.apiKey;

  // the key this instance actually uses. defaults to the const above;
  // tests pass their own so they never depend on a real key being set
  final String apiKey;

  // injectable so tests can drive the live ranking path with a MockClient
  // instead of reaching the network
  final http.Client _client;

  AiMatchingService({String? apiKey, http.Client? client})
      : apiKey = apiKey ?? groqApiKey,
        _client = client ?? http.Client();

  // true when a key is available, so the UI can say whether the live
  // Groq ranking or the offline formula is being used
  //
  // the startsWith check matters: the placeholder text is a non-empty
  // string, so without it the app would think it had a real key, call
  // Groq, get a 401, and fall back silently - the banner would then read
  // "Offline ranking", which looks like a broken key rather than an
  // absent one
  bool get isGroqConfigured =>
      apiKey.isNotEmpty && !apiKey.startsWith('PASTE_');

  // the model and endpoint used for ranking - see GroqConfig
  static const String _model = GroqConfig.model;
  static const String _endpoint = GroqConfig.endpoint;

  // main entry point - returns mentors ranked best first
  Future<List<MentorMatch>> rankMentors({
    required UserProfile profile,
    required List<Mentor> mentors,
  }) async {
    if (mentors.isEmpty) return [];

    if (!isGroqConfigured) {
      // no key pasted in yet - use the local formula
      return _localRank(profile, mentors);
    }
    try {
      return await _groqRank(profile, mentors);
    } catch (_) {
      // API failed (offline, quota, bad response) - fall back so the
      // recommendations never break
      return _localRank(profile, mentors);
    }
  }

  // ---------- option 1: ask Groq to rank the mentors ----------

  Future<List<MentorMatch>> _groqRank(
      UserProfile profile, List<Mentor> mentors) async {
    // describe each mentor in a compact way the model can read
    final mentorList = mentors
        .map((m) => '- id: ${m.id}, name: ${m.name}, '
            'specialization: ${m.specialization}, '
            'subjects: ${m.subjects.join("/")}, rating: ${m.rating}, '
            'online: ${m.isOnline}')
        .join('\n');

    // the instructions we send to the model
    final prompt = '''
You match polytechnic students with peer mentors.

Student:
- course: ${profile.course.isEmpty ? 'unknown' : profile.course}
- year: ${profile.academicYear.isEmpty ? 'unknown' : profile.academicYear}
- needs help with these subjects: ${profile.subjects.isEmpty ? 'not specified' : profile.subjects.join(', ')}

Mentors:
$mentorList

Rank ALL the mentors from best to worst fit for this student.
Reply with ONLY this json object, no other text:
{"matches": [{"id": "<mentor id>", "score": <0-100 how good the fit is>, "reason": "<one short friendly sentence why>"}]}
''';

    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            // the key travels in a header rather than the query string, so
            // it does not get written into server logs and proxy caches
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'user', 'content': prompt},
            ],
            // ask the model to reply in strict JSON so parsing is reliable.
            // groq only honours this when the prompt itself mentions json,
            // which the prompt above does
            'response_format': {'type': 'json_object'},
          }),
        )
        .timeout(const Duration(seconds: 15));
    // give up after 15s rather than leaving the screen loading forever

    if (response.statusCode != 200) {
      throw Exception('Groq API error ${response.statusCode}');
    }

    // dig the model's text reply out of the response structure
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    var text = (body['choices'][0]['message']['content'] as String).trim();

    // models sometimes wrap json in a markdown fence even when told not to
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();

    // the reply text is itself JSON (the ranked list we asked for)
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    final ranked = decoded['matches'] as List<dynamic>;

    // match each ranked id back to its Mentor object
    final byId = {for (final m in mentors) m.id: m};
    final matches = <MentorMatch>[];
    for (final item in ranked) {
      final mentor = byId[item['id']];
      if (mentor == null) continue;
      // skip ids the model made up (models sometimes do that)
      matches.add(MentorMatch(
        mentor: mentor,
        score: ((item['score'] ?? 0) as num).toInt().clamp(0, 100),
        reason: (item['reason'] ?? '') as String,
        source: MatchSource.groq,
      ));
    }

    if (matches.isEmpty) throw Exception('Groq returned no usable matches');
    return matches;
  }

  // ---------- option 2: local scoring formula (the fallback) ----------

  List<MentorMatch> _localRank(UserProfile profile, List<Mentor> mentors) {
    final matches = mentors.map((mentor) {
      // count how many of the student's subjects this mentor teaches
      final shared = mentor.subjects
          .where((s) => profile.subjects.contains(s))
          .toList();

      // the score formula:
      //   subject overlap matters most (up to 50 points)
      //   then rating (up to 40 points: 5.0 stars = 40)
      //   being online now is a small bonus (10 points)
      double score = 0;
      if (profile.subjects.isNotEmpty) {
        score += 50 * shared.length / profile.subjects.length;
      }
      score += mentor.rating * 8;
      if (mentor.isOnline) score += 10;

      // build a human readable reason from the same facts
      String reason;
      if (shared.isNotEmpty) {
        reason = 'Teaches ${shared.join(" and ")} which you need help with, '
            'rated ${mentor.rating}/5';
      } else if (profile.subjects.isEmpty) {
        reason = 'Highly rated ${mentor.specialization} mentor '
            '(${mentor.rating}/5) - set your subjects for better matches';
      } else {
        reason = 'No direct subject match, but strong in '
            '${mentor.specialization} (${mentor.rating}/5)';
      }

      return MentorMatch(
        mentor: mentor,
        score: score.round().clamp(0, 100),
        reason: reason,
        source: MatchSource.localFallback,
      );
    }).toList();

    // highest score first
    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }
}
