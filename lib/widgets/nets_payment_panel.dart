import 'dart:async';
// Timer, for the auto-return after a successful payment
import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/models/nets_state.dart';
// the payment snapshot
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/providers/nets_provider.dart';
// the app's providers
import 'package:tpmentorship/services/nets_service.dart';
// for the price constant
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages

class NetsPaymentPanel extends ConsumerStatefulWidget {
// the NETS QR half of the premium screen
//
// asks for a QR as soon as it appears, then renders whichever of the
// five payment states we are in. it holds no payment logic of its own -
// everything comes off netsProvider

  const NetsPaymentPanel({super.key});

  @override
  ConsumerState<NetsPaymentPanel> createState() => _NetsPaymentPanelState();
}

class _NetsPaymentPanelState extends ConsumerState<NetsPaymentPanel> {
  Timer? _returnTimer;
  bool _simulating = false;
  // true while the demo-mode button is working, so it cannot be
  // tapped twice

  @override
  void initState() {
    super.initState();
    // a provider cannot be written to during a build, so the first
    // request waits for the frame to finish
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(netsProvider.notifier).generateQr();
    });
  }

  @override
  void dispose() {
    _returnTimer?.cancel();
    super.dispose();
  }

  void _close() {
    // cancel here too, not just in dispose(): dispose() is not synchronous
    // with Navigator.pop() (Flutter defers it until the exit transition
    // finishes), so without this a "Done" tap and the 5s auto-return can
    // both still fire - the second call would then pop a second,
    // unrelated route because canPop() reflects the stack after the first
    // pop already happened
    _returnTimer?.cancel();
    if (mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  // demo mode only: unlock premium without a real payment, which is
  // what this screen did before the NETS integration existed
  Future<void> _simulatePayment() async {
    // set before the first await, not after: the guard has to be in
    // place synchronously on tap, or a second tap landing while this
    // await is still in flight sees _simulating still false and queues
    // its own upgradeToPremium call
    setState(() => _simulating = true);
    try {
      // .future rather than a bare .value: same race NetsController._settle
      // documents - this can be the first read of authStateProvider, so the
      // stream may not have delivered its first event yet. a bare .value
      // would race that and see AsyncLoading, silently no-op'ing the button
      // with no feedback. .future resolves immediately if a value already
      // exists, so this costs nothing once the app's auth gate has warmed
      // the provider
      final user = await ref.read(authStateProvider.future);
      if (user == null) return;

      await ref.read(userServiceProvider).upgradeToPremium(user.uid);
      if (!mounted) return;
      showAppSnackBar(context, 'Premium unlocked (demo mode)', success: true);
      _close();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, 'Could not unlock premium. Try again.');
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  String _mmss(int seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(netsProvider);

    // once NETS confirms the payment, give the user five seconds to
    // read the confirmation and then take them back by themselves
    ref.listen<NetsState>(netsProvider, (previous, next) {
      if (previous?.status != NetsStatus.success &&
          next.status == NetsStatus.success) {
        _returnTimer?.cancel();
        _returnTimer = Timer(const Duration(seconds: 5), _close);
      }
    });

    switch (state.status) {
      case NetsStatus.loading:
        return _loading();
      case NetsStatus.awaitingScan:
        return _awaitingScan(state);
      case NetsStatus.success:
        return _success(state);
      case NetsStatus.failed:
        return _failed();
      case NetsStatus.unavailable:
        return _unavailable(state);
    }
  }

  Widget _loading() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Contacting NETS...',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _awaitingScan(NetsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Scan with the NETS TWallet app to pay',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // QR codes need a white background to scan reliably
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'NETS QR',
                  style: TextStyle(
                    color: Color(0xFF003087),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Image.memory(state.qrCode!, width: 190, height: 190),
                const SizedBox(height: 4),
                Text(
                  'SGD ${NETSService.premiumPriceSgd.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Expires in ${_mmss(state.timeLeft)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (state.message != null) ...[
          const SizedBox(height: 6),
          Text(
            state.message!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.tpRed, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: _close,
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _success(NetsState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 72),
          const SizedBox(height: 16),
          Text(
            'Payment successful',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.message ??
                'You now get priority booking and instant messaging '
                    'with mentors.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _close, child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _failed() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.cancel, color: AppTheme.tpRed, size: 72),
          const SizedBox(height: 16),
          Text(
            'Payment failed or timed out',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            // checkPayment folds a real decline, an unreadable reply and
            // an unreachable gateway into the same false - "nothing was
            // charged" would be a lie for that last case, eg a TWallet
            // payment that went through but a query-API hiccup right
            // after it
            'We could not confirm the payment. If you were charged, do '
            'not pay again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => ref.read(netsProvider.notifier).retry(),
            child: const Text('Try again'),
          ),
          TextButton(onPressed: _close, child: const Text('Cancel')),
        ],
      ),
    );
  }

  Widget _unavailable(NetsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.12),
            border: Border.all(color: Colors.amber),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NETS sandbox unavailable - ${state.message ?? 'unknown'}. '
                  'Running in demo mode.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _simulating ? null : _simulatePayment,
          child: _simulating
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text('Unlocking...'),
                  ],
                )
              : const Text("I've paid - unlock premium"),
        ),
        const SizedBox(height: 8),
        Text(
          'No real payment is made in demo mode',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
