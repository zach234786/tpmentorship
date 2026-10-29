import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/constants/tp_schools.dart';

void main() {
  group('tpSchools', () {
    test('has all six Temasek Polytechnic schools', () {
      expect(tpSchools.keys, containsAll([
        'School of Applied Science',
        'School of Business',
        'School of Design',
        'School of Engineering',
        'School of Humanities & Social Sciences',
        'School of Informatics & IT',
      ]));
    });

    test('School of Informatics & IT lists Diploma in Applied Artificial Intelligence', () {
      expect(
        tpSchools['School of Informatics & IT'],
        contains('Diploma in Applied Artificial Intelligence'),
      );
    });
  });

  group('isCommonProgramme', () {
    test('true for a Common Programme name', () {
      expect(isCommonProgramme('Common ICT Programme'), isTrue);
    });

    test('false for a specialised diploma name', () {
      expect(isCommonProgramme('Diploma in Marketing'), isFalse);
    });
  });

  group('diplomasFor', () {
    test('Year 1 includes the Common Programme', () {
      final diplomas = diplomasFor('School of Informatics & IT', 'Year 1');
      expect(diplomas, contains('Common ICT Programme'));
    });

    test('Year 2 excludes the Common Programme', () {
      final diplomas = diplomasFor('School of Informatics & IT', 'Year 2');
      expect(diplomas, isNot(contains('Common ICT Programme')));
      expect(diplomas, contains('Diploma in Information Technology'));
    });

    test('Year 3 excludes the Common Programme', () {
      final diplomas = diplomasFor('School of Engineering', 'Year 3');
      expect(diplomas, isNot(contains('Common Engineering Programme')));
    });

    test('a school with no Common Programme is unaffected by year', () {
      final year1 =
          diplomasFor('School of Humanities & Social Sciences', 'Year 1');
      final year2 =
          diplomasFor('School of Humanities & Social Sciences', 'Year 2');
      expect(year1, year2);
      expect(year1, isNot(anyElement(isCommonProgramme)));
    });

    test('an unknown school returns an empty list', () {
      expect(diplomasFor('School of Nowhere', 'Year 1'), isEmpty);
    });
  });

  group('schoolFor', () {
    test('finds the school for an exact diploma name', () {
      expect(
        schoolFor('Diploma in Applied Artificial Intelligence'),
        'School of Informatics & IT',
      );
    });

    test('matches case-insensitively and trims whitespace', () {
      expect(
        schoolFor('  diploma in marketing  '),
        'School of Business',
      );
    });

    test('returns null for a name that matches nothing', () {
      expect(schoolFor('Diploma in Underwater Basket Weaving'), isNull);
    });
  });
}
