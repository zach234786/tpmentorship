import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpmentorship/models/mentor.dart';
import 'package:tpmentorship/models/user_profile.dart';
import 'package:tpmentorship/services/ai_matching_service.dart';

Mentor _mentor({
  required String id,
  required String name,
  required double rating,
  List<String> subjects = const [],
  bool isOnline = false,
}) {
  return Mentor(
    id: id,
    name: name,
    specialization: 'Development',
    rating: rating,
    reviewCount: 10,
    isOnline: isOnline,
    subjects: subjects,
  );
}

UserProfile _student({List<String> subjects = const []}) {
  return UserProfile(
    uid: 'student-1',
    fullName: 'Test Student',
    createdAt: DateTime(2026, 1, 1),
    subjects: subjects,
  );
}

// wraps text the way Groq does: choices -> message -> content
String _groqReply(String content) {
  return jsonEncode({
    'choices': [
      {
        'message': {'content': content}
      }
    ]
  });
}

// the JSON object we ask the model to produce
String _matchesJson(List<Map<String, Object>> matches) {
  return jsonEncode({'matches': matches});
}

AiMatchingService _serviceReturning(String body, {int status = 200}) {
  return AiMatchingService(
    apiKey: 'test-key',
    client: MockClient((_) async => http.Response(body, status)),
  );
}

void main() {
  group('AiMatchingService without an API key', () {
    final service = AiMatchingService(apiKey: '');

    test('reports that the Groq key is not configured', () {
      expect(service.isGroqConfigured, isFalse);
    });

    test('labels its results as the offline fallback ranking', () async {
      final matches = await service.rankMentors(
        profile: _student(subjects: ['DAVA']),
        mentors: [_mentor(id: '1', name: 'Damian', rating: 4.5)],
      );

      expect(matches.first.source, MatchSource.localFallback);
    });

    test('ranks a mentor who teaches the needed subject above a higher '
        'rated mentor who does not', () async {
      final matches = await service.rankMentors(
        profile: _student(subjects: ['DAVA']),
        mentors: [
          _mentor(id: 'no-match', name: 'Higher Rated', rating: 5.0),
          _mentor(
            id: 'match',
            name: 'Subject Match',
            rating: 4.0,
            subjects: ['DAVA'],
          ),
        ],
      );

      expect(matches.first.mentor.id, 'match');
    });

    test('returns an empty list when there are no mentors', () async {
      final matches = await service.rankMentors(
        profile: _student(),
        mentors: [],
      );

      expect(matches, isEmpty);
    });
  });

  group('AiMatchingService with an API key', () {
    test('reports that the Groq key is configured', () {
      final service = AiMatchingService(apiKey: 'test-key-123');
      expect(service.isGroqConfigured, isTrue);
    });
  });

  group('AiMatchingService with a pasted placeholder key', () {
    test('reports that the Groq key is not configured', () {
      // a fresh checkout has this exact string in place of a real key -
      // it must not be mistaken for one, or the app would call Groq, get
      // a 401, and silently fall back instead of just using the offline
      // formula from the start
      final service = AiMatchingService(apiKey: 'PASTE_YOUR_GROQ_KEY_HERE');
      expect(service.isGroqConfigured, isFalse);
    });
  });

  group('AiMatchingService ranking through Groq', () {
    test('uses the order Groq returned, not the local formula', () async {
      // the local formula would put the subject match first; this proves
      // the ranking on screen really is the model's and not ours
      final service = _serviceReturning(_groqReply(_matchesJson([
        {'id': 'no-match', 'score': 95, 'reason': 'Great all-rounder'},
        {'id': 'match', 'score': 70, 'reason': 'Teaches DAVA'},
      ])));

      final matches = await service.rankMentors(
        profile: _student(subjects: ['DAVA']),
        mentors: [
          _mentor(id: 'match', name: 'Subject Match', rating: 4.0,
              subjects: ['DAVA']),
          _mentor(id: 'no-match', name: 'Other', rating: 4.0),
        ],
      );

      expect(matches.map((m) => m.mentor.id), ['no-match', 'match']);
      expect(matches.first.score, 95);
      expect(matches.first.reason, 'Great all-rounder');
      expect(matches.first.source, MatchSource.groq);
    });

    test('sends the key as a bearer token with the model and the prompt',
        () async {
      late http.Request sent;
      final service = AiMatchingService(
        apiKey: 'my-groq-key',
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            _groqReply(_matchesJson([
              {'id': '1', 'score': 80, 'reason': 'ok'}
            ])),
            200,
          );
        }),
      );

      await service.rankMentors(
        profile: _student(subjects: ['DAVA']),
        mentors: [_mentor(id: '1', name: 'Damian', rating: 4.5)],
      );

      expect(sent.headers['Authorization'], 'Bearer my-groq-key');
      expect(sent.url.toString(), isNot(contains('my-groq-key')));
      // the key belongs in the header, never in the URL where it would be
      // logged by proxies and servers along the way

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['model'], 'llama-3.1-8b-instant');
      final messages = body['messages'] as List;
      expect(messages.single['role'], 'user');
      expect(messages.single['content'], contains('Damian'));
      expect(messages.single['content'].toString().toLowerCase(),
          contains('json'));
      // Groq rejects response_format unless the prompt mentions json
    });

    test('parses a reply the model wrapped in a markdown fence', () async {
      final inner = _matchesJson([
        {'id': '1', 'score': 88, 'reason': 'Strong match'}
      ]);
      final service = _serviceReturning(_groqReply('```json\n$inner\n```'));

      final matches = await service.rankMentors(
        profile: _student(),
        mentors: [_mentor(id: '1', name: 'Damian', rating: 4.5)],
      );

      expect(matches.single.score, 88);
      expect(matches.single.source, MatchSource.groq);
    });

    test('skips mentor ids the model invented', () async {
      final service = _serviceReturning(_groqReply(_matchesJson([
        {'id': 'does-not-exist', 'score': 99, 'reason': 'Made up'},
        {'id': '1', 'score': 80, 'reason': 'Real'},
      ])));

      final matches = await service.rankMentors(
        profile: _student(),
        mentors: [_mentor(id: '1', name: 'Damian', rating: 4.5)],
      );

      expect(matches.single.mentor.id, '1');
    });

    test('falls back to the offline ranking when Groq returns an error',
        () async {
      final service = _serviceReturning('rate limit exceeded', status: 429);

      final matches = await service.rankMentors(
        profile: _student(subjects: ['DAVA']),
        mentors: [_mentor(id: '1', name: 'Damian', rating: 4.5)],
      );

      expect(matches.single.source, MatchSource.localFallback);
    });

    test('falls back to the offline ranking when the reply is not JSON',
        () async {
      final service = _serviceReturning(_groqReply('Sorry, I cannot do that.'));

      final matches = await service.rankMentors(
        profile: _student(subjects: ['DAVA']),
        mentors: [_mentor(id: '1', name: 'Damian', rating: 4.5)],
      );

      expect(matches.single.source, MatchSource.localFallback);
    });

    test('falls back to the offline ranking when no id matches a mentor',
        () async {
      // an empty result would otherwise leave the screen with nothing
      final service = _serviceReturning(_groqReply(_matchesJson([
        {'id': 'ghost', 'score': 99, 'reason': 'Made up'}
      ])));

      final matches = await service.rankMentors(
        profile: _student(subjects: ['DAVA']),
        mentors: [_mentor(id: '1', name: 'Damian', rating: 4.5)],
      );

      expect(matches.single.source, MatchSource.localFallback);
    });
  });
}
