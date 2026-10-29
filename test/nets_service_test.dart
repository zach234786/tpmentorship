import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tpmentorship/services/nets_service.dart';

// a 1x1 transparent png - the smallest thing that is genuinely decodable,
// so the test proves we base64-decode rather than just pass bytes through
const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

NETSService _serviceReturning(String body, {int status = 200}) {
  return NETSService(
    apiKey: 'test-key',
    projectId: 'test-project',
    client: MockClient((_) async => http.Response(body, status)),
  );
}

void main() {
  group('NETSService.isConfigured', () {
    test('is false when the api key is blank', () {
      final service = NETSService(apiKey: '', projectId: 'p');
      expect(service.isConfigured, isFalse);
    });

    test('is false when the project id is blank', () {
      final service = NETSService(apiKey: 'k', projectId: '');
      expect(service.isConfigured, isFalse);
    });

    test('is true when both are set', () {
      final service = NETSService(apiKey: 'k', projectId: 'p');
      expect(service.isConfigured, isTrue);
    });

    test('is false when the api key is still the pasted placeholder', () {
      // a fresh checkout has this exact string in place of a real key - it
      // must not be mistaken for one, or the app would call NETS, get an
      // HTTP error back, and report that instead of "No NETS API key set"
      final service = NETSService(
        apiKey: 'PASTE_YOUR_NETS_API_KEY_HERE',
        projectId: 'p',
      );
      expect(service.isConfigured, isFalse);
    });

    test('is false when the project id is still the pasted placeholder', () {
      final service = NETSService(
        apiKey: 'k',
        projectId: 'PASTE_YOUR_NETS_PROJECT_ID_HERE',
      );
      expect(service.isConfigured, isFalse);
    });
  });

  group('NETSService.requestQr', () {
    test('decodes the qr code and keeps the retrieval ref', () async {
      final service = _serviceReturning(jsonEncode({
        'status': 'success',
        'result': {
          'data': {
            'txn_nets_qr_id': 828,
            'txn_retrieval_ref': '168j183f3ln',
            'amt_in_dollars': 3,
            'qr_code': _pngBase64,
            'network_status': 1,
            'txn_status': 1,
            'response_code': '00',
          }
        }
      }));

      final qr = await service.requestQr(2.99);

      expect(qr.txnRef, '168j183f3ln');
      expect(qr.image, base64Decode(_pngBase64));
    });

    test('sends the credentials as headers and the amount in the body',
        () async {
      late http.Request sent;
      final service = NETSService(
        apiKey: 'my-key',
        projectId: 'my-project',
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'result': {
                'data': {
                  'txn_retrieval_ref': 'r1',
                  'qr_code': _pngBase64,
                }
              }
            }),
            200,
          );
        }),
      );

      await service.requestQr(2.99);

      expect(sent.headers['api-key'], 'my-key');
      expect(sent.headers['project-id'], 'my-project');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['amt_in_dollars'], 2.99);
      expect(body['notify_mobile'], 0);
      expect(body['txn_id'], 'sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b');
    });

    test('throws NetsUnavailable on a non-200', () async {
      final service = _serviceReturning('nope', status: 503);
      expect(
        () => service.requestQr(2.99),
        throwsA(isA<NetsUnavailable>()),
      );
    });

    test('throws NetsUnavailable when NETS reports a non-success status',
        () async {
      final service = _serviceReturning(jsonEncode({'status': 'error'}));
      expect(
        () => service.requestQr(2.99),
        throwsA(isA<NetsUnavailable>()),
      );
    });

    test('throws NetsUnavailable when the qr code is missing', () async {
      final service = _serviceReturning(jsonEncode({
        'status': 'success',
        'result': {
          'data': {'txn_retrieval_ref': 'r1'}
        }
      }));
      expect(
        () => service.requestQr(2.99),
        throwsA(isA<NetsUnavailable>()),
      );
    });

    test('throws NetsUnavailable rather than a FormatException on junk',
        () async {
      final service = _serviceReturning('<html>gateway timeout</html>');
      expect(
        () => service.requestQr(2.99),
        throwsA(isA<NetsUnavailable>()),
      );
    });

    test('throws NetsUnavailable rather than a TypeError when result is not '
        'a map', () async {
      final service = _serviceReturning(jsonEncode({
        'status': 'success',
        'result': 'rate limited',
      }));
      expect(
        () => service.requestQr(2.99),
        throwsA(isA<NetsUnavailable>()),
      );
    });

    test(
        'throws NetsUnavailable rather than a TypeError when the qr code is '
        'not a string', () async {
      final service = _serviceReturning(jsonEncode({
        'status': 'success',
        'result': {
          'data': {
            'txn_retrieval_ref': 'r1',
            'qr_code': 12345,
          }
        }
      }));
      expect(
        () => service.requestQr(2.99),
        throwsA(isA<NetsUnavailable>()),
      );
    });
  });

  group('NETSService.queryPayment', () {
    test('reads response code 00 as paid', () async {
      final service = _serviceReturning(jsonEncode({
        'status': 'success',
        'result': {
          'data': {
            'txn_retrieval_ref': 'c66rif1mb5',
            'response_code': '00',
            'txn_status': 1,
          }
        }
      }));

      expect(await service.queryPayment('c66rif1mb5'), NetsPaymentResult.paid);
    });

    test('reads any other response code as not paid', () async {
      final service = _serviceReturning(jsonEncode({
        'status': 'success',
        'result': {
          'data': {
            'txn_retrieval_ref': 'c66rif1mb5',
            'response_code': '09',
            'txn_status': 2,
          }
        }
      }));

      expect(
          await service.queryPayment('c66rif1mb5'), NetsPaymentResult.notPaid);
    });

    test('reads an empty response code as still pending', () async {
      // this is exactly what the live sandbox returns while the user is
      // still paying: response_code "" and txn_status 0. reading it as
      // "not paid" would fail a payment that is simply not finished yet
      final service = _serviceReturning(jsonEncode({
        'status': 'success',
        'result': {
          'data': {
            'txn_retrieval_ref': 'c66rif1mb5',
            'response_code': '',
            'txn_status': 0,
          }
        }
      }));

      expect(
          await service.queryPayment('c66rif1mb5'), NetsPaymentResult.pending);
    });

    test('reports pending rather than not-paid when the query fails',
        () async {
      // "we could not ask" is not "they did not pay" - during polling that
      // difference decides between waiting and wrongly failing a payment
      final service = _serviceReturning('gateway down', status: 500);
      expect(
          await service.queryPayment('c66rif1mb5'), NetsPaymentResult.pending);
    });

    test('does not set the timeout flag by default', () async {
      // frontend_timeout_status: 1 VOIDS a live transaction server-side -
      // verified against the sandbox, where a pending txn went from
      // response_code "" to a permanent "09" purely from this flag. so the
      // ordinary poll must send 0, or polling would cancel the payment it
      // is polling for
      late http.Request sent;
      final service = NETSService(
        apiKey: 'k',
        projectId: 'p',
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'result': {
                'data': {'response_code': ''}
              }
            }),
            200,
          );
        }),
      );

      await service.queryPayment('abc123');

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['txn_retrieval_ref'], 'abc123');
      expect(body['frontend_timeout_status'], 0);
    });

    test('sets the timeout flag only when the countdown has expired',
        () async {
      late http.Request sent;
      final service = NETSService(
        apiKey: 'k',
        projectId: 'p',
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({
              'status': 'success',
              'result': {
                'data': {'response_code': '09'}
              }
            }),
            200,
          );
        }),
      );

      await service.queryPayment('abc123', frontendTimedOut: true);

      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['frontend_timeout_status'], 1);
    });
  });

  group('NETSService.netsTxnId', () {
    test('is the registered sandbox merchant, not a generated id', () {
      // the third segment is looked up as a merchant. a generated uuid
      // names a merchant that does not exist, and the sandbox answers
      // 404 'entity_merchant Record not found' - which is what shipped
      expect(
        NETSService.netsTxnId,
        'sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b',
      );
    });

    test('is the same on every payment', () async {
      // NETS identifies the transaction by the txn_retrieval_ref it mints
      // itself, so this value is merchant configuration and must not vary
      final ids = <String>[];
      final service = NETSService(
        apiKey: 'k',
        projectId: 'p',
        client: MockClient((request) async {
          ids.add((jsonDecode(request.body) as Map)['txn_id'] as String);
          return http.Response(
            jsonEncode({
              'status': 'success',
              'result': {
                'data': {'txn_retrieval_ref': 'r1', 'qr_code': _pngBase64}
              }
            }),
            200,
          );
        }),
      );

      await service.requestQr(2.99);
      await service.requestQr(2.99);

      expect(ids, ['sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b',
        'sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b']);
    });
  });

  group('NETSService.terminalWebhookHints', () {
    test('does not treat a scan as terminal - the user has not paid yet', () {
      const scanned = 'qr code scanned';
      expect(
        NETSService.terminalWebhookHints.any(scanned.contains),
        isFalse,
      );
    });

    test('treats a timeout as terminal', () {
      const timedOut = 'timeout occurred';
      expect(
        NETSService.terminalWebhookHints.any(timedOut.contains),
        isTrue,
      );
    });
  });
}
