import 'dart:convert';
// for turning JSON text into dart objects and back
import 'dart:typed_data';
// Uint8List, the decoded QR image bytes
import 'package:http/http.dart' as http;
// for calling the NETS sandbox web API

// the decoded result of a successful RequestAPI call
class NetsQr {
  final Uint8List image;
  // the QR itself, already base64-decoded and ready for Image.memory
  final String txnRef;
  // txn_retrieval_ref - identifies this transaction to the webhook and
  // the query API, so it has to be kept for the rest of the flow

  const NetsQr({required this.image, required this.txnRef});
}

// where a transaction has got to according to the query API. three-way
// rather than a bool because "still paying" and "did not pay" are
// different answers: the app polls while the QR is up, and treating a
// pending transaction as a failure would fail every payment the instant
// the QR appeared
enum NetsPaymentResult {
  paid,
  // response_code 00 - the only outcome that unlocks premium
  pending,
  // the user has not finished paying yet, or we could not reach NETS to
  // ask. both mean "keep waiting", never "they did not pay"
  notPaid,
  // NETS gave a definite non-00 answer: declined, or voided by timeout
}

// thrown when the sandbox cannot give us a QR code. the reason is written
// for the user, not for a log - it ends up on screen under the banner
class NetsUnavailable implements Exception {
  final String reason;
  const NetsUnavailable(this.reason);

  @override
  String toString() => 'NetsUnavailable: $reason';
}

class NETSService {
// talks to the Sandbox NETS-OPENAPIPAAS gateway
//
// three endpoints, in the order the payment uses them:
// 1. requestQr()     - ask for a QR code
// 2. webhookStream() - live updates while the user pays (SSE)
// 3. checkPayment()  - the authoritative yes/no at the end
//
// nothing here knows about Riverpod or Flutter, so it can be unit
// tested with a MockClient and no network

  // paste your NETS sandbox credentials here
  // (https://developers.openapipass.org - see SETUP_PART3.md)
  // leave as the placeholders and the premium screen falls back to demo mode
  //
  // they can also be passed in at run time without editing this file:
  //   flutter run --dart-define=NETS_API_KEY=... \
  //               --dart-define=NETS_PROJECT_ID=...
  //
  // these two are the only per-student values. netsTxnId below is shared and
  // should be left alone - see the comment on it
  static const String netsApiKey = String.fromEnvironment(
    'NETS_API_KEY',
    defaultValue: '61jF996wpnJINimuu9Mc',
  );
  static const String netsProjectId = String.fromEnvironment(
    'NETS_PROJECT_ID',
    defaultValue: '2a0e993c-66a1-4c2c-ab39-c4ec0adcea1f',
  );

  // the merchant being paid. despite the name, txn_id does NOT identify a
  // transaction - NETS mints that itself and hands it back as
  // txn_retrieval_ref, so two calls with this same value get two different
  // refs. the third segment is a registered sandbox merchant, which makes
  // this fixed configuration rather than something to generate per payment
  //
  // sending a freshly generated uuid here is what the Week 13 lab's example
  // looks like it is doing, but the merchant does not exist and the sandbox
  // answers HTTP 404 'entity_merchant Record not found'. the deck marks only
  // api-key and project-id as values to replace; this one is used verbatim,
  // and it is shared by every student rather than issued per project
  static const String netsTxnId = String.fromEnvironment(
    'NETS_TXN_ID',
    defaultValue: 'sandbox_nets|m|8ff8e5b6-d43e-4786-8ac5-7accf8c5bd9b',
  );

  // what premium costs. the screen reads this too, so the advertised and
  // the charged amount cannot drift apart
  //
  // note: every example in the NETS docs uses a whole dollar amount. if
  // the sandbox rejects 2.99, change this to 3.00 and the UI follows
  static const double premiumPriceSgd = 2.99;

  static const String _base =
      'https://sandbox.nets.openapipaas.com/api/v1/common/payments';

  // webhook messages that mean the transaction is over, one way or the
  // other. deliberately NOT including "scanned" - the user has opened the
  // payment in TWallet at that point but has not confirmed it yet
  //
  // the NETS docs only show these messages as fragments, never the exact
  // strings, so this is a best-effort accelerator. checkPayment() is the
  // authority - an unmatched message costs a longer wait, never a wrong
  // answer. correct this list once the real messages have been observed
  static const List<String> terminalWebhookHints = [
    'success',
    'fail',
    'completed',
    'timeout',
  ];

  // the credentials this instance actually uses. default to the consts
  // above; tests pass their own so they never depend on a real key
  final String apiKey;
  final String projectId;
  final String txnId;
  final http.Client _client;

  NETSService({
    String? apiKey,
    String? projectId,
    String? txnId,
    http.Client? client,
  })  : apiKey = apiKey ?? netsApiKey,
        projectId = projectId ?? netsProjectId,
        txnId = txnId ?? netsTxnId,
        _client = client ?? http.Client();

  // false until both credentials are filled in - the UI checks this
  // before trying, so an unconfigured app says so instead of erroring
  //
  // the startsWith checks matter: a placeholder is a non-empty string, so
  // without them the app would think it had real credentials, call NETS,
  // get an HTTP error back, and report that instead of "No NETS API key
  // set" - which looks like a broken key rather than an absent one
  bool get isConfigured =>
      apiKey.isNotEmpty &&
      !apiKey.startsWith('PASTE_') &&
      projectId.isNotEmpty &&
      !projectId.startsWith('PASTE_');

  Map<String, String> get _headers => {
        'api-key': apiKey,
        'project-id': projectId,
        'Content-Type': 'application/json',
      };

  // ---------- 1. RequestAPI: ask NETS for a QR code ----------

  Future<NetsQr> requestQr(double amount) async {
    late final http.Response response;
    try {
      response = await _client.post(
        Uri.parse('$_base/nets-qr/request'),
        headers: _headers,
        body: jsonEncode({
          'txn_id': txnId,
          'amt_in_dollars': amount,
          'notify_mobile': 0,
        }),
      );
    } catch (_) {
      throw const NetsUnavailable('Could not reach the NETS sandbox');
    }

    if (response.statusCode != 200) {
      throw NetsUnavailable('NETS returned HTTP ${response.statusCode}');
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // a gateway error page rather than JSON - do not let a raw
      // FormatException escape into the UI
      throw const NetsUnavailable('NETS sent a reply we could not read');
    }

    if (body['status'] != 'success') {
      throw const NetsUnavailable('NETS rejected the payment request');
    }

    Map? data;
    String? encodedQr;
    String? txnRef;
    try {
      data = (body['result'] as Map?)?['data'] as Map?;
      encodedQr = data?['qr_code'] as String?;
      txnRef = data?['txn_retrieval_ref']?.toString();
    } catch (_) {
      // the documented rate limit can return a success status with
      // 'result' as a plain string, or fields of the wrong type - a
      // shape JSON-valid enough to decode but not to cast. same message
      // as the jsonDecode failure above: both mean "a 200 we could not
      // read", so they should look the same to the user
      throw const NetsUnavailable('NETS sent a reply we could not read');
    }

    if (encodedQr == null || encodedQr.isEmpty || txnRef == null) {
      // the documented rate limit (4 scans/second across all sandbox
      // users) shows up here as a success with no QR in it
      throw const NetsUnavailable('NETS did not return a QR code');
    }

    try {
      return NetsQr(image: base64Decode(encodedQr), txnRef: txnRef);
    } catch (_) {
      throw const NetsUnavailable('The QR code from NETS was not valid');
    }
  }

  // ---------- 2. S2SWebhookAPI: live updates over SSE ----------

  // yields the text of each server-sent event, eg "QR code scanned",
  // so the screen can tell the user what is happening while they pay
  Stream<String> webhookStream(String txnRef) async* {
    final uri = Uri.parse('$_base/nets/webhook')
        .replace(queryParameters: {'txn_retrieval_ref': txnRef});

    final request = http.Request('GET', uri)..headers.addAll(_headers);
    final response = await _client.send(request);

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      // SSE frames look like "data: <payload>", separated by blank
      // lines. anything else (comments, keepalives) is not for us
      if (line.startsWith('data:')) {
        final payload = line.substring(5).trim();
        if (payload.isNotEmpty) yield payload;
      }
    }
  }

  // ---------- 3. QueryAPI: the authoritative result ----------

  // asks NETS where the transaction has got to. safe to call repeatedly
  // while the user is paying, as long as frontendTimedOut stays false
  //
  // frontendTimedOut maps to the API's frontend_timeout_status, and it is
  // NOT a read-only flag: sending 1 tells NETS the payment window closed
  // and VOIDS a transaction that is still in progress. verified against
  // the sandbox on 10 Aug 2026 - a pending ref returning
  // {response_code: "", txn_status: 0} was queried once with 1 and
  // permanently became {response_code: "09"}, even on later queries with
  // 0. so it may only be sent when the countdown has genuinely expired
  //
  // an unreachable gateway or an unreadable reply is `pending`, not
  // `notPaid` - "we could not ask" must never read as "they did not pay",
  // or one dropped packet mid-poll would fail a good payment. the caller
  // decides what to do when time runs out and the answer is still pending
  Future<NetsPaymentResult> queryPayment(
    String txnRef, {
    bool frontendTimedOut = false,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$_base/nets-qr/query'),
        headers: _headers,
        body: jsonEncode({
          'txn_retrieval_ref': txnRef,
          'frontend_timeout_status': frontendTimedOut ? 1 : 0,
        }),
      );

      if (response.statusCode != 200) return NetsPaymentResult.pending;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (body['result'] as Map?)?['data'] as Map?;
      final code = data?['response_code']?.toString() ?? '';

      if (code == '00') return NetsPaymentResult.paid;
      // the sandbox leaves response_code empty for the whole time the QR
      // is live and unpaid - that is the ordinary polling answer
      if (code.isEmpty) return NetsPaymentResult.pending;
      return NetsPaymentResult.notPaid;
    } catch (_) {
      return NetsPaymentResult.pending;
    }
  }
}
