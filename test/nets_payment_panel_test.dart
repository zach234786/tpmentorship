import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/services/nets_service.dart';
import 'package:tpmentorship/services/user_service.dart';
import 'package:tpmentorship/widgets/nets_payment_panel.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _FakeNetsService implements NETSService {
  _FakeNetsService({this.configured = true, this.result = NetsPaymentResult.paid});

  final bool configured;
  final NetsPaymentResult result;
  final StreamController<String> webhook = StreamController<String>.broadcast();

  @override
  bool get isConfigured => configured;

  @override
  Future<NetsQr> requestQr(double amount) async =>
      NetsQr(image: base64Decode(_pngBase64), txnRef: 'ref-1');

  @override
  Stream<String> webhookStream(String txnRef) => webhook.stream;

  @override
  Future<NetsPaymentResult> queryPayment(
    String txnRef, {
    bool frontendTimedOut = false,
  }) async =>
      result;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserService implements UserService {
  @override
  Future<void> upgradeToPremium(String uid) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SlowUserService implements UserService {
  int upgradeCalls = 0;
  // counts calls rather than just recording that one happened, so the
  // double-tap test can prove it fired exactly once, not merely at least
  // once
  final Completer<void> _gate = Completer<void>();
  // upgradeToPremium blocks here until the test calls release() - a fake
  // that resolved immediately would let the first tap's whole flow finish
  // (and _simulating flip back to false) before a second tap ever landed,
  // which would prove nothing about the guard

  @override
  Future<void> upgradeToPremium(String uid) async {
    upgradeCalls++;
    await _gate.future;
  }

  void release() => _gate.complete();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  String get uid => 'student-1';

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _panelWith(
  _FakeNetsService nets, {
  UserService? userService,
  Stream<User?>? authStream,
  // lets a test hold the auth read open (eg an unfinished
  // StreamController), instead of the default stream that resolves
  // straight away
}) {
  return ProviderScope(
    overrides: [
      netsServiceProvider.overrideWithValue(nets),
      userServiceProvider.overrideWithValue(userService ?? _FakeUserService()),
      authStateProvider.overrideWith(
        (ref) => authStream ?? Stream<User?>.value(_FakeUser()),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: NetsPaymentPanel())),
    ),
  );
}

void main() {
  testWidgets('shows the QR and the countdown once NETS replies',
      (tester) async {
    await tester.pumpWidget(_panelWith(_FakeNetsService()));
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.textContaining('5:00'), findsOneWidget);
    expect(find.textContaining('TWallet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('counts the timer down', (tester) async {
    await tester.pumpWidget(_panelWith(_FakeNetsService()));
    await tester.pump();
    await tester.pump();

    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('4:59'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows the live webhook message under the QR', (tester) async {
    final nets = _FakeNetsService();
    await tester.pumpWidget(_panelWith(nets));
    await tester.pump();
    await tester.pump();

    nets.webhook.add('QR code scanned');
    // a stream event lands on the state during this pump's microtask
    // flush, but that pump's frame was already drawn by then - the
    // rebuild that shows it needs a second pump, same as the
    // success/failure webhook tests below
    await tester.pump();
    await tester.pump();

    expect(find.text('QR code scanned'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows demo mode with a reason when no key is set',
      (tester) async {
    await tester.pumpWidget(_panelWith(_FakeNetsService(configured: false)));
    await tester.pump();
    await tester.pump();

    // narrower than plain 'demo mode': that phrase also appears in the
    // "no real payment is made" caption below the button, so matching
    // just the banner's own wording is what keeps this to one widget
    expect(find.textContaining('Running in demo mode'), findsOneWidget);
    expect(find.textContaining('No NETS API key'), findsOneWidget);
    expect(find.text("I've paid - unlock premium"), findsOneWidget);
  });

  testWidgets('shows the success state when NETS confirms payment',
      (tester) async {
    final nets = _FakeNetsService(result: NetsPaymentResult.paid);
    await tester.pumpWidget(_panelWith(nets));
    await tester.pump();
    await tester.pump();

    nets.webhook.add('Payment success');
    await tester.pump();
    await tester.pump();

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    // the confirmation sentence must be on screen, not the raw webhook
    // text NetsController was tracking for the awaitingScan caption -
    // this is the regression Fix 1 guards against
    expect(
      find.text(
        'You now get priority booking and instant messaging '
        'with mentors.',
      ),
      findsOneWidget,
    );
    expect(find.text('Payment success'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  // Fix 2 (2026-08 review): a candidate regression test for the double-pop
  // bug ("tap Done, then omit the final pumpWidget(const SizedBox()), so an
  // uncancelled _returnTimer trips flutter_test's pending-timer check") was
  // tried here and verified NOT to discriminate. Evidence is in
  // final-fix-report.md - in short, flutter_test's own post-test teardown
  // (AutomatedTestWidgetsFlutterBinding._runTestBody, package:flutter_test
  // binding.dart) unconditionally does the equivalent of
  // pumpWidget(const SizedBox()) - runApp(Container(...)); await pump(); -
  // before it ever checks for pending timers, for every test. That disposes
  // NetsPaymentPanel and runs its dispose(), which cancels _returnTimer
  // regardless of what _close() does. Confirmed by pumping the existing
  // 'shows the success state' test without its own trailing pumpWidget: it
  // still passes. No public API exposes pending-timer state mid-test as an
  // alternative. _close()'s own cancel (line ~62) is still correct and
  // still load-bearing for the real bug (a stale timer firing during a
  // route's exit-transition window, before its dispose() runs) - it is
  // just not one this test file's widget-test harness can observe, because
  // Navigator.canPop is always false here (single-route MaterialApp), so a
  // second pop attempt is unobservable regardless of the timer.

  testWidgets('offers a retry when the payment fails', (tester) async {
    final nets = _FakeNetsService(result: NetsPaymentResult.notPaid);
    await tester.pumpWidget(_panelWith(nets));
    await tester.pump();
    await tester.pump();

    nets.webhook.add('Payment failed');
    await tester.pump();
    await tester.pump();

    expect(find.text('Payment failed or timed out'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    // the query API collapses a real decline and an unreadable/unreachable
    // query API into the same false, so the screen cannot claim to know
    // nothing was charged - a TWallet payment followed by a query hiccup
    // would make that claim false
    expect(
      find.text(
        'We could not confirm the payment. If you were charged, do not '
        'pay again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Nothing was charged'), findsNothing);
  });

  testWidgets('shows a spinner and the contacting message while loading',
      (tester) async {
    // generateQr() is deferred to a post-frame callback and only resolves
    // once the fake service's Future completes, so this first frame is
    // still on NetsState's default status - loading - before either has
    // had a chance to run
    await tester.pumpWidget(_panelWith(_FakeNetsService()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Contacting NETS...'), findsOneWidget);
  });

  testWidgets(
      'tapping the demo-mode button twice only unlocks premium once',
      (tester) async {
    final userService = _SlowUserService();
    await tester.pumpWidget(
      _panelWith(
        _FakeNetsService(configured: false),
        userService: userService,
      ),
    );
    await tester.pump();
    await tester.pump();

    // found by type, not label: the button's text switches to
    // "Unlocking..." once _simulating flips, and a stale text finder
    // would fail to locate it for the second tap
    final button = find.byType(ElevatedButton);

    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    // upgradeToPremium is now in flight (blocked on the gate) and
    // _simulating is true, so this second tap lands on a rebuilt,
    // disabled button and must not start a second call
    await tester.tap(button);
    await tester.pump();

    userService.release();
    await tester.pump();
    await tester.pump();

    expect(userService.upgradeCalls, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'tapping the unlock button twice before auth resolves only '
      'unlocks premium once',
      (tester) async {
    // the auth stream deliberately never emits during this test, holding
    // _simulatePayment's first await open - this is the exact window
    // Fix 3 closes: the double-tap guard has to be set before that
    // await, not after it, or the button stays enabled the whole time
    // the auth read is in flight
    final authController = StreamController<User?>();
    final userService = _SlowUserService();
    await tester.pumpWidget(
      _panelWith(
        _FakeNetsService(configured: false),
        userService: userService,
        authStream: authController.stream,
      ),
    );
    await tester.pump();
    await tester.pump();

    final button = find.byType(ElevatedButton);

    await tester.tap(button);
    await tester.pump();
    await tester.pump();
    // still awaiting auth - a rebuild has already happened here, so this
    // is exactly where an unguarded button would still be tappable
    await tester.tap(button);
    await tester.pump();

    authController.add(_FakeUser());
    userService.release();
    await tester.pump();
    await tester.pump();

    expect(userService.upgradeCalls, 1);
  });
}
