import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpmentorship/services/bio_writer_service.dart';

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

BioWriterService _serviceReturning(String body, {int status = 200}) {
  return BioWriterService(
    apiKey: 'test-key',
    client: MockClient((_) async => http.Response(body, status)),
  );
}

BioWriterService _serviceThatThrows() {
  return BioWriterService(
    apiKey: 'test-key',
    client: MockClient((_) async => throw Exception('network down')),
  );
}

Future<GeneratedBio> _write(
  BioWriterService service, {
  String school = 'School of Informatics & IT',
  String diploma = 'Diploma in Applied Artificial Intelligence',
  String academicYear = 'Year 2',
  List<String> subjects = const ['DAVA', 'Python'],
}) {
  return service.writeBio(
    school: school,
    diploma: diploma,
    academicYear: academicYear,
    subjects: subjects,
  );
}

void main() {
  group('BioWriterService Groq path', () {
    test('returns the model text on a 200', () async {
      final service =
          _serviceReturning(_groqReply('Year 2 AI student, love debugging.'));

      final bio = await _write(service);

      expect(bio.text, 'Year 2 AI student, love debugging.');
      expect(bio.source, BioSource.groq);
    });

    test('strips a wrapping pair of quotes', () async {
      final service =
          _serviceReturning(_groqReply('"Year 2 AI student, love debugging."'));

      final bio = await _write(service);

      expect(bio.text, 'Year 2 AI student, love debugging.');
    });

    test('clamps a reply over 150 characters at a word boundary', () async {
      final long = 'word ' * 60; // 300 chars
      final service = _serviceReturning(_groqReply(long));

      final bio = await _write(service);

      expect(bio.text.length, lessThanOrEqualTo(150));
      // cut on a boundary, so the text never ends mid-word
      expect(bio.text.endsWith('word'), isTrue);
    });
  });

  group('BioWriterService fallback', () {
    test('falls back to the template on a non-200', () async {
      final service = _serviceReturning('nope', status: 500);

      final bio = await _write(service);

      expect(bio.source, BioSource.localTemplate);
      expect(bio.text, contains('Diploma in Applied Artificial Intelligence'));
    });

    test('falls back to the template when the client throws', () async {
      final bio = await _write(_serviceThatThrows());

      expect(bio.source, BioSource.localTemplate);
    });

    test('falls back to the template on a whitespace-only reply', () async {
      final service = _serviceReturning(_groqReply('   '));

      final bio = await _write(service);

      expect(bio.source, BioSource.localTemplate);
    });

    test('an unconfigured key never issues a request', () async {
      var called = false;
      final service = BioWriterService(
        apiKey: 'PASTE_YOUR_KEY_HERE',
        client: MockClient((_) async {
          called = true;
          return http.Response(_groqReply('x'), 200);
        }),
      );

      final bio = await _write(service);

      expect(called, isFalse);
      expect(bio.source, BioSource.localTemplate);
    });
  });

  group('BioWriterService template text', () {
    test('names the subjects when present', () async {
      final bio = await _write(_serviceThatThrows(),
          subjects: const ['DAVA', 'Python']);

      expect(bio.text, contains('Year 2'));
      expect(bio.text, contains('Diploma in Applied Artificial Intelligence'));
      expect(bio.text, contains('DAVA and Python'));
    });

    test('renders a single subject with no conjunction', () async {
      final bio = await _write(_serviceThatThrows(), subjects: const ['DAVA']);

      expect(bio.text, contains('help with DAVA.'));
    });

    test('renders three subjects with commas and a final and', () async {
      final bio = await _write(_serviceThatThrows(),
          subjects: const ['DAVA', 'Python', 'Java']);

      expect(bio.text, contains('DAVA, Python and Java'));
    });

    test('omits the subjects clause and names the school when empty', () async {
      final bio = await _write(_serviceThatThrows(), subjects: const []);

      expect(bio.text, isNot(contains('Looking for help')));
      expect(bio.text, contains('School of Informatics & IT'));
    });

    test('drops the year cleanly when it is empty', () async {
      final bio = await _write(_serviceThatThrows(), academicYear: '');

      expect(bio.text, startsWith('Student in '));
    });

    test('clamps a long diploma plus many subjects', () async {
      final bio = await _write(
        _serviceThatThrows(),
        diploma: 'Diploma in Architectural Technology & Building Services',
        subjects: const ['Statics', 'Structures', 'Surveying', 'Drafting',
            'Estimating'],
      );

      expect(bio.text.length, lessThanOrEqualTo(150));
    });
  });
}
