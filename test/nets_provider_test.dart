import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// fake_async is a real dependency here (not just a stray transitive
// import) but only comes in transitively via flutter_test, so the
// pubspec doesn't list it directly - adding it there is out of scope
// for this task, so the lint is silenced rather than the pubspec edited
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/nets_state.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/providers/nets_provider.dart';
import 'package:tpmentorship/services/nets_service.dart';
import 'package:tpmentorship/services/user_service.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

// a stand-in for NETSService so the controller can be tested without a
// network, a key, or a five minute wait
class _FakeNetsService implements NETSService {
  _FakeNetsService({
    this.configured = true,
    this.failWith,
    this.result = NetsPaymentResult.paid,
  });

  final bool configured;
  final NetsUnavailable? failWith;

  // mutable so a test can leave the transaction pending and then flip it,
  // the way a real payment lands part way through the countdown
  NetsPaymentResult result;

  final StreamController<String> webhook = StreamController<String>.broadcast();
  int queryCalls = 0;
  // records whether the destructive void flag was sent, so a test can
  // prove an ordinary poll never sets it
  final List<bool> timeoutFlags = [];

  // lets a test hold a query open, to simulate it still being in flight
  // when something else happens - eg the screen closing
  Completer<NetsPaymentResult>? queryGate;

  @override
  bool get isConfigured => configured;

  int _issued = 0;

  @override
  Future<NetsQr> requestQr(double amount) async {
    if (failWith != null) throw failWith!;
    // a fresh ref per request, as NETS does - the same txn_id sent twice
    // comes back with two different txn_retrieval_refs
    return NetsQr(image: base64Decode(_pngBase64), txnRef: 'ref-${++_issued}');
  }

  @override
  Stream<String> webhookStream(String txnRef) => webhook.stream;

  @override
  Future<NetsPaymentResult> queryPayment(
    String txnRef, {
    bool frontendTimedOut = false,
  }) async {
    queryCalls++;
    timeoutFlags.add(frontendTimedOut);
    final gate = queryGate;
    if (gate != null) return gate.future;
    return result;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserService implements UserService {
  final List<String> upgraded = [];

  @override
  Future<void> upgradeToPremium(String uid) async => upgraded.add(uid);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// simulates the premium write itself failing (eg a Firestore error) after
// a genuine payment, for Fix 5/6: the user must never be told to redo the
// payment for this
class _FailingUserService implements UserService {
  @override
  Future<void> upgradeToPremium(String uid) async {
    throw Exception('write failed');
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// only uid is ever read off the Firebase user, so everything else can
// fall through to noSuchMethod
class _FakeUser implements User {
  @override
  String get uid => 'student-1';

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _containerWith(
  _FakeNetsService nets, {
  UserService? users,
}) {
  final container = ProviderContainer(overrides: [
    netsServiceProvider.overrideWithValue(nets),
    userServiceProvider.overrideWithValue(users ?? _FakeUserService()),
    authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
  ]);
  addTearDown(container.dispose);

  // netsProvider is autoDispose, so a bare container.read() would build
  // the controller and immediately throw it away - the next read would
  // get a brand new one with none of the state the test just set up.
  // an open listener keeps one instance alive for the whole test
  final sub = container.listen(netsProvider, (_, _) {});
  addTearDown(sub.close);

  return container;
}

void main() {
  group('NetsController.generateQr', () {
    test('shows the QR and starts the countdown at five minutes', () async {
      final container = _containerWith(_FakeNetsService());

      await container.read(netsProvider.notifier).generateQr();
      final state = container.read(netsProvider);

      expect(state.status, NetsStatus.awaitingScan);
      expect(state.qrCode, isA<Uint8List>());
      expect(state.txnRef, 'ref-1');
      expect(state.timeLeft, 300);

      container.read(netsProvider.notifier).cleanup();
    });

    test('falls back to demo mode when no key is set', () async {
      final container = _containerWith(_FakeNetsService(configured: false));

      await container.read(netsProvider.notifier).generateQr();
      final state = container.read(netsProvider);

      expect(state.status, NetsStatus.unavailable);
      expect(state.message, contains('No NETS API key'));
    });

    test('falls back to demo mode with the reason when NETS refuses',
        () async {
      final container = _containerWith(_FakeNetsService(
        failWith: const NetsUnavailable('NETS did not return a QR code'),
      ));

      await container.read(netsProvider.notifier).generateQr();
      final state = container.read(netsProvider);

      expect(state.status, NetsStatus.unavailable);
      expect(state.message, 'NETS did not return a QR code');
    });
  });

  group('NetsController webhook handling', () {
    test('shows a scan message without ending the transaction', () async {
      // "QR code scanned" means the user opened the payment, not that
      // they confirmed it - settling here would fail a good payment
      final nets = _FakeNetsService();
      final container = _containerWith(nets);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('QR code scanned');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(netsProvider).message, 'QR code scanned');
      expect(container.read(netsProvider).status, NetsStatus.awaitingScan);
      expect(nets.queryCalls, 0);

      container.read(netsProvider.notifier).cleanup();
    });

    test('settles through the query API on a terminal message', () async {
      final nets = _FakeNetsService(result: NetsPaymentResult.paid);
      final users = _FakeUserService();
      final container = _containerWith(nets, users: users);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('Payment success');
      await Future<void>.delayed(Duration.zero);

      expect(nets.queryCalls, 1);
      expect(container.read(netsProvider).status, NetsStatus.success);
      expect(users.upgraded, ['student-1']);
    });

    test('trusts the query API over the webhook message', () async {
      // a "success" message with an unpaid query result must not unlock
      // premium - the query API is the authority
      final nets = _FakeNetsService(result: NetsPaymentResult.notPaid);
      final users = _FakeUserService();
      final container = _containerWith(nets, users: users);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('Payment success');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(netsProvider).status, NetsStatus.failed);
      expect(users.upgraded, isEmpty);
    });

    test('settles only once even if several messages arrive', () async {
      final nets = _FakeNetsService();
      final container = _containerWith(nets);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('Payment success');
      nets.webhook.add('Payment completed');
      await Future<void>.delayed(Duration.zero);

      expect(nets.queryCalls, 1);
    });

    test('keeps waiting when the webhook stream dies', () async {
      // a dropped SSE connection must degrade to the countdown, not
      // break the payment
      final nets = _FakeNetsService();
      final container = _containerWith(nets);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.addError('connection reset');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(netsProvider).status, NetsStatus.awaitingScan);

      container.read(netsProvider.notifier).cleanup();
    });

    test(
        'writes premium even if the screen closes before checkPayment '
        'resolves', () async {
      // checkPayment is a real network round trip, and netsProvider is
      // autoDispose - leaving the premium screen mid-query disposes the
      // controller. if the query comes back paid, the premium write
      // still has to happen: the user already paid, _settled is already
      // latched so nothing will ever retry this transaction, and the
      // provider being autoDispose means reopening the screen starts a
      // brand new one with a brand new txnRef
      final nets = _FakeNetsService(result: NetsPaymentResult.paid)
        ..queryGate = Completer<NetsPaymentResult>();
      final users = _FakeUserService();
      final container = ProviderContainer(overrides: [
        netsServiceProvider.overrideWithValue(nets),
        userServiceProvider.overrideWithValue(users),
        authStateProvider.overrideWith(
          (ref) => Stream<User?>.value(_FakeUser()),
        ),
      ]);
      addTearDown(container.dispose);

      // listens directly (rather than via _containerWith) so this test
      // can close just this one subscription and let netsProvider's
      // autoDispose actually tear the controller down, while the
      // container - and the other providers in it - stay alive, same
      // as when a real screen closes
      final sub = container.listen(netsProvider, (_, _) {});
      final controller = container.read(netsProvider.notifier);

      await controller.generateQr();
      nets.webhook.add('Payment success');
      await Future<void>.delayed(Duration.zero);

      // the query is now stuck on the gate - this is where the
      // screen closes
      sub.close();
      await pumpEventQueue();
      expect(controller.mounted, isFalse);

      nets.queryGate!.complete(NetsPaymentResult.paid);
      await Future<void>.delayed(Duration.zero);

      expect(users.upgraded, ['student-1']);
    });
  });

  group('NetsController premium-write failure', () {
    test(
        'tells the user premium needs restoring, not to repay, when the '
        'unlock write fails', () async {
      final nets = _FakeNetsService(result: NetsPaymentResult.paid);
      final container = _containerWith(nets, users: _FailingUserService());

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('Payment success');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(netsProvider);
      expect(state.status, NetsStatus.success);
      // the old wording told the user to "reopen this screen to try
      // again", which starts a fresh transaction and takes a second
      // payment for a premium write that has nothing to do with paying
      expect(state.message, isNot(contains('Reopen this screen')));
      expect(state.message, contains('did not unlock'));
    });

    test(
        'reaches the same state when the auth stream errors instead of '
        'the write', () async {
      // _settle reads authStateProvider.future before it can even call
      // upgradeToPremium - if that read throws (a broken auth stream)
      // the payment still went through, so this has to land on the same
      // user-visible state as upgradeToPremium itself failing, not
      // escape _settle as an uncaught error
      final nets = _FakeNetsService(result: NetsPaymentResult.paid);
      final container = ProviderContainer(overrides: [
        netsServiceProvider.overrideWithValue(nets),
        userServiceProvider.overrideWithValue(_FakeUserService()),
        authStateProvider.overrideWith((ref) => Stream<User?>.error('boom')),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(netsProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('Payment success');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(netsProvider);
      expect(state.status, NetsStatus.success);
      expect(state.message, contains('did not unlock'));
    });
  });

  group('NetsController polling', () {
    test('unlocks premium from polling alone, with no webhook message', () {
      // the bug this exists for: the user pays, TWallet shows the payment
      // completed, and the app sits on the QR until the countdown expires.
      // the webhook is the only thing that used to end a transaction early,
      // and it is matched on guessed substrings over an SSE stream that may
      // never deliver. polling has to carry the whole flow on its own
      fakeAsync((async) {
        final nets = _FakeNetsService(result: NetsPaymentResult.pending);
        final users = _FakeUserService();
        final container = _containerWith(nets, users: users);

        container.read(netsProvider.notifier).generateQr();
        async.elapse(Duration.zero);

        // still on the QR while NETS says pending, however many polls
        async.elapse(const Duration(seconds: 30));
        expect(container.read(netsProvider).status, NetsStatus.awaitingScan);
        expect(nets.queryCalls, greaterThan(1));

        // the user pays in TWallet - no webhook message ever arrives
        nets.result = NetsPaymentResult.paid;
        async.elapse(NetsController.pollInterval);

        expect(container.read(netsProvider).status, NetsStatus.success);
        expect(users.upgraded, ['student-1']);
      });
    });

    test('never sends the transaction-voiding timeout flag while polling',
        () {
      // frontend_timeout_status: 1 voids a live transaction server-side, so
      // a poll that sent it would cancel the payment it is waiting for
      fakeAsync((async) {
        final nets = _FakeNetsService(result: NetsPaymentResult.pending);
        final container = _containerWith(nets);

        container.read(netsProvider.notifier).generateQr();
        async.elapse(Duration.zero);
        async.elapse(const Duration(seconds: 60));

        expect(nets.queryCalls, greaterThan(1));
        expect(nets.timeoutFlags, everyElement(isFalse));

        container.read(netsProvider.notifier).cleanup();
      });
    });

    test('a pending answer is not treated as a failed payment', () {
      // "still paying" and "we could not reach NETS" both come back as
      // pending, and neither is a reason to fail the transaction
      fakeAsync((async) {
        final nets = _FakeNetsService(result: NetsPaymentResult.pending);
        final container = _containerWith(nets);

        container.read(netsProvider.notifier).generateQr();
        async.elapse(Duration.zero);
        async.elapse(const Duration(seconds: 120));

        expect(container.read(netsProvider).status, NetsStatus.awaitingScan);

        container.read(netsProvider.notifier).cleanup();
      });
    });

    test('polls one at a time when a query is slower than the interval', () {
      fakeAsync((async) {
        final nets = _FakeNetsService(result: NetsPaymentResult.pending)
          ..queryGate = Completer<NetsPaymentResult>();
        final container = _containerWith(nets);

        container.read(netsProvider.notifier).generateQr();
        async.elapse(Duration.zero);
        // four intervals pass while the first query is still in flight
        async.elapse(const Duration(seconds: 12));

        expect(nets.queryCalls, 1);

        container.read(netsProvider.notifier).cleanup();
      });
    });
  });

  group('NetsController countdown', () {
    test('settles through the query API once the countdown reaches zero',
        () {
      // the countdown is the last backstop, and the one place allowed to
      // send the voiding timeout flag
      fakeAsync((async) {
        final nets = _FakeNetsService(result: NetsPaymentResult.pending);
        final container = _containerWith(nets);

        container.read(netsProvider.notifier).generateQr();
        async.elapse(Duration.zero);

        expect(container.read(netsProvider).status, NetsStatus.awaitingScan);
        expect(container.read(netsProvider).timeLeft, 300);

        async.elapse(const Duration(seconds: 300));

        // out of time with no confirmation - pending counts as not paid
        expect(container.read(netsProvider).status, NetsStatus.failed);
        expect(nets.timeoutFlags.last, isTrue);
      });
    });

    test('a payment that lands on the final poll still unlocks premium', () {
      fakeAsync((async) {
        final nets = _FakeNetsService(result: NetsPaymentResult.pending);
        final users = _FakeUserService();
        final container = _containerWith(nets, users: users);

        container.read(netsProvider.notifier).generateQr();
        async.elapse(Duration.zero);
        async.elapse(const Duration(seconds: 290));
        expect(container.read(netsProvider).status, NetsStatus.awaitingScan);

        nets.result = NetsPaymentResult.paid;
        async.elapse(const Duration(seconds: 10));

        expect(container.read(netsProvider).status, NetsStatus.success);
        expect(users.upgraded, ['student-1']);
      });
    });
  });

  group('NetsController.retry', () {
    test('clears the failure and requests a fresh QR', () async {
      final nets = _FakeNetsService(result: NetsPaymentResult.notPaid);
      final container = _containerWith(nets);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('Payment failed');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(netsProvider).status, NetsStatus.failed);

      await container.read(netsProvider.notifier).retry();

      expect(container.read(netsProvider).status, NetsStatus.awaitingScan);
      expect(container.read(netsProvider).timeLeft, 300);

      container.read(netsProvider.notifier).cleanup();
    });

    test('a query still in flight cannot settle the transaction that '
        'replaced it', () async {
      // retry() abandons the old transaction, but a query already on the
      // wire still resolves. its answer is about a ref nobody is paying
      // any more, so it must not decide the fresh one
      final gate = Completer<NetsPaymentResult>();
      final nets = _FakeNetsService(result: NetsPaymentResult.notPaid)
        ..queryGate = gate;
      final users = _FakeUserService();
      final container = _containerWith(nets, users: users);

      await container.read(netsProvider.notifier).generateQr();
      nets.webhook.add('Payment success');
      await Future<void>.delayed(Duration.zero);

      // the stale query is now parked on the gate; start over
      nets.queryGate = null;
      await container.read(netsProvider.notifier).retry();
      expect(container.read(netsProvider).status, NetsStatus.awaitingScan);

      // the abandoned query finally answers
      gate.complete(NetsPaymentResult.notPaid);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(netsProvider).status, NetsStatus.awaitingScan);
      expect(users.upgraded, isEmpty);

      container.read(netsProvider.notifier).cleanup();
    });
  });

  group('NetsState.copyWith', () {
    test('keeps fields that are not passed', () {
      const original = NetsState(
        status: NetsStatus.awaitingScan,
        txnRef: 'ref-1',
        timeLeft: 42,
        message: 'hello',
      );

      final updated = original.copyWith(timeLeft: 41);

      expect(updated.timeLeft, 41);
      expect(updated.status, NetsStatus.awaitingScan);
      expect(updated.txnRef, 'ref-1');
      expect(updated.message, 'hello');
    });
  });
}
