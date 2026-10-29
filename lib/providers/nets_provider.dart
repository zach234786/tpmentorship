import 'dart:async';
// Timer and StreamSubscription
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/nets_state.dart';
// the payment snapshot the UI reads
import 'package:tpmentorship/providers/auth_provider.dart';
// gives us the logged in user
import 'package:tpmentorship/providers/data_providers.dart';
// netsServiceProvider and userServiceProvider
import 'package:tpmentorship/services/nets_service.dart';
// the NETS sandbox API

class NetsController extends StateNotifier<NetsState> {
// owns one NETS QR transaction from request to result
//
// the query API is what actually decides the outcome, and it is polled on
// a timer for as long as the QR is up. the webhook only supplies the
// status line under the QR and a nudge to poll immediately - it is an
// accelerator, never the mechanism
//
// polling is here because the webhook cannot be relied on to end a
// transaction. the messages it sends are matched against guessed
// substrings (terminalWebhookHints), and if the SSE stream drops or the
// wording does not match, nothing settles until the five minute countdown
// expires - the user pays, TWallet says Completed, and the app sits on the
// QR. polling makes the payment land regardless of any of that

  NetsController(this._ref) : super(const NetsState());

  // how often to ask NETS whether the payment has landed. every query is
  // a round trip, so this trades a little traffic for the delay the user
  // sees between paying and the screen reacting
  static const Duration pollInterval = Duration(seconds: 3);

  final Ref _ref;
  Timer? _timer;
  Timer? _pollTimer;
  StreamSubscription<String>? _webhookSub;
  bool _polling = false;
  // one query in flight at a time - a slow reply must not let the timer
  // stack a second query on top of it
  bool _settled = false;
  // stops a poll, a webhook message and the countdown all settling the
  // same transaction, which could write premium more than once
  String? _activeTxnRef;
  // the transaction the controller currently belongs to. a query already
  // in flight when retry() throws the transaction away still resolves,
  // and without this its stale answer would settle the fresh transaction
  // that replaced it - failing, or silently unlocking, a payment the user
  // has not made yet

  Future<void> generateQr() async {
    final service = _ref.read(netsServiceProvider);

    if (!service.isConfigured) {
      _fallback('No NETS API key set');
      return;
    }

    try {
      final qr = await service.requestQr(NETSService.premiumPriceSgd);
      if (!mounted) return;

      _activeTxnRef = qr.txnRef;
      state = state.copyWith(
        status: NetsStatus.awaitingScan,
        qrCode: qr.image,
        txnRef: qr.txnRef,
        timeLeft: 300,
      );

      _startTimer(qr.txnRef);
      _startPolling(qr.txnRef);
      _startWebhookListener(qr.txnRef);
    } on NetsUnavailable catch (e) {
      _fallback(e.reason);
    } catch (_) {
      _fallback('Could not reach the NETS sandbox');
    }
  }

  // throw the transaction away and start a clean one
  Future<void> retry() async {
    cleanup();
    _settled = false;
    _polling = false;
    _activeTxnRef = null;
    if (!mounted) return;
    state = const NetsState();
    await generateQr();
  }

  void _fallback(String reason) {
    if (!mounted) return;
    state = state.copyWith(status: NetsStatus.unavailable, message: reason);
  }

  void _startTimer(String txnRef) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final left = state.timeLeft - 1;
      if (left <= 0) {
        timer.cancel();
        state = state.copyWith(timeLeft: 0);
        _expire(txnRef);
      } else {
        state = state.copyWith(timeLeft: left);
      }
    });
  }

  // asks NETS where the payment has got to, over and over, until it has a
  // definite answer or the countdown runs out
  void _startPolling(String txnRef) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _poll(txnRef));
  }

  // one non-destructive check. `pending` means keep waiting - it covers
  // both "still paying" and "could not reach NETS", neither of which is a
  // reason to fail a payment
  Future<void> _poll(String txnRef) async {
    if (_settled || _polling) return;
    _polling = true;
    try {
      final result =
          await _ref.read(netsServiceProvider).queryPayment(txnRef);
      if (txnRef != _activeTxnRef) return;
      if (result == NetsPaymentResult.pending) return;
      await _finish(paid: result == NetsPaymentResult.paid);
    } finally {
      _polling = false;
    }
  }

  // the countdown ran out. this is the one place allowed to send
  // frontend_timeout_status: 1, which tells NETS the window closed and
  // voids the transaction server-side - see NETSService.queryPayment.
  // a still-pending answer here is out of time, so it counts as not paid
  Future<void> _expire(String txnRef) async {
    if (_settled) return;
    final result = await _ref
        .read(netsServiceProvider)
        .queryPayment(txnRef, frontendTimedOut: true);
    if (txnRef != _activeTxnRef) return;
    await _finish(paid: result == NetsPaymentResult.paid);
  }

  void _startWebhookListener(String txnRef) {
    _webhookSub?.cancel();
    _webhookSub =
        _ref.read(netsServiceProvider).webhookStream(txnRef).listen(
      (message) {
        if (!mounted) return;
        state = state.copyWith(message: message);

        // a terminal-looking message only brings the next poll forward.
        // it must not settle anything by itself: the hint list is a set of
        // guesses, and a false match that voided a live transaction would
        // cancel a payment the user is halfway through making
        final lower = message.toLowerCase();
        if (NETSService.terminalWebhookHints.any(lower.contains)) {
          _poll(txnRef);
        }
      },
      // a dropped SSE connection is not fatal - polling still settles the
      // transaction, so this costs nothing but the status line
      onError: (_) {},
      cancelOnError: true,
    );
  }

  // the single terminal path: everything that can end a transaction ends
  // here, and the _settled latch is set before the first await so only the
  // first caller through ever runs it
  Future<void> _finish({required bool paid}) async {
    if (_settled) return;
    _settled = true;
    cleanup();

    if (!paid) {
      if (mounted) state = state.copyWith(status: NetsStatus.failed);
      return;
    }

    // no `if (!mounted) return` guarding the write below: the query is a
    // real network round trip and netsProvider is autoDispose, so the user
    // can leave the premium screen while one is in flight. if it came back
    // paid, the premium write still has to run, or a user who paid never
    // gets premium and there is no transaction left to retry. mounted only
    // gates the UI writes, not the payment logic
    //
    // the write happens here rather than in the widget so it runs
    // exactly once, whatever the user does with the success screen
    //
    // both the auth read and the upgrade write are in this one try: a
    // broken auth stream (AsyncError from authStateChanges) is just as
    // possible here as a failed write, and by this point the payment has
    // already gone through either way, so both have to land on the same
    // "premium did not unlock" state rather than one of them escaping
    // _settle as an uncaught error with no user-facing message at all
    try {
      // .future rather than a bare .value: this is often the very first
      // read of authStateProvider (nothing else needs the user until now),
      // so the stream may not have delivered its first event yet. a bare
      // .value would race that and see AsyncLoading, silently skipping the
      // premium write for a user who did pay. .future resolves with the
      // current value immediately if it already has one, so this costs
      // nothing once the app's auth gate has warmed the provider
      final uid = (await _ref.read(authStateProvider.future))?.uid;
      if (uid != null) {
        await _ref.read(userServiceProvider).upgradeToPremium(uid);
      }
    } catch (_) {
      // they did pay, so this must never read as a failed payment - and
      // reopening the screen would start a fresh transaction and take a
      // second payment, so this must not tell them to do that either
      if (!mounted) return;
      state = state.copyWith(
        status: NetsStatus.success,
        message: 'Payment received, but premium did not unlock. It will '
            'need to be restored manually - no need to pay again.',
      );
      return;
    }

    if (!mounted) return;
    // clearMessage: otherwise the last webhook line (eg "QR code
    // scanned") would still be sitting in state and the success screen
    // would show that instead of the confirmation sentence
    state = state.copyWith(status: NetsStatus.success, clearMessage: true);
  }

  // cancels the countdown, the poll and the SSE subscription. called when
  // the transaction settles and again on dispose, so nothing keeps ticking
  // after the screen is gone
  void cleanup() {
    _timer?.cancel();
    _timer = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _webhookSub?.cancel();
    _webhookSub = null;
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}

// autoDispose because a payment belongs to one visit to the premium
// screen - leaving and coming back should start a fresh transaction
// rather than resume a dead one
final netsProvider =
    StateNotifierProvider.autoDispose<NetsController, NetsState>((ref) {
  return NetsController(ref);
});
