import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/services/notification_service.dart';

void main() {
  group('ChatNotificationPayload', () {
    test('round-trips a uid and name through encode/decode', () {
      const payload = ChatNotificationPayload(
        senderUid: 'uid123',
        senderName: 'Alex Tan',
      );

      final decoded = ChatNotificationPayload.decode(payload.encode());

      expect(decoded, isNotNull);
      expect(decoded!.senderUid, 'uid123');
      expect(decoded.senderName, 'Alex Tan');
    });

    test('survives a name containing json and delimiter characters', () {
      // the reason the payload is json and not "uid|name"
      const payload = ChatNotificationPayload(
        senderUid: 'uid123',
        senderName: 'Al|ex "The Pipe" {Tan}',
      );

      final decoded = ChatNotificationPayload.decode(payload.encode());

      expect(decoded!.senderName, 'Al|ex "The Pipe" {Tan}');
    });

    test('decodes to null for anything that is not one of ours', () {
      // a session reminder carries no payload at all
      expect(ChatNotificationPayload.decode(null), isNull);
      expect(ChatNotificationPayload.decode(''), isNull);
      // malformed input must not throw
      expect(ChatNotificationPayload.decode('not json'), isNull);
      expect(ChatNotificationPayload.decode('["uid","name"]'), isNull);
      expect(ChatNotificationPayload.decode('{"name":"Alex"}'), isNull);
      expect(ChatNotificationPayload.decode('{"uid":"","name":"Alex"}'), isNull);
      expect(ChatNotificationPayload.decode('{"uid":7,"name":"Alex"}'), isNull);
    });
  });
}
