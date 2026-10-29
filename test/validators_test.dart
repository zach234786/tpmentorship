import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/utils/validators.dart';

void main() {
  group('Validators.chatMessage', () {
    test('rejects an empty box', () {
      expect(Validators.chatMessage(''), 'Please type a message');
    });

    test('rejects a null value', () {
      expect(Validators.chatMessage(null), 'Please type a message');
    });

    test('rejects a message that is only whitespace', () {
      expect(Validators.chatMessage('     '), 'Please type a message');
    });

    test('rejects a message longer than the limit', () {
      final tooLong = 'a' * (Validators.maxChatMessageLength + 1);
      expect(
        Validators.chatMessage(tooLong),
        'Message cannot be longer than '
        '${Validators.maxChatMessageLength} characters',
      );
    });

    test('accepts a normal message', () {
      expect(Validators.chatMessage('Hello, can we meet on Monday?'), null);
    });

    test('accepts a message exactly at the limit', () {
      final atLimit = 'a' * Validators.maxChatMessageLength;
      expect(Validators.chatMessage(atLimit), null);
    });
  });
}
