import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/providers/biometric_provider.dart';
// the lock state and the biometric service
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling

class LockScreen extends ConsumerStatefulWidget {
// additional feature: the fingerprint / face lock over the saved session
//
// shown by the auth gate when the user is already signed in but has
// turned on biometric unlock. nothing behind it is rendered until the
// scan succeeds

  const LockScreen({super.key, required this.onUsePassword});

  // called when the user cannot (or does not want to) scan - the auth gate
  // signs them out so they can log in with their password again
  final VoidCallback onUsePassword;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // prompt as soon as the screen appears so the usual case is just
    // "open app, touch sensor" with no extra tap
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_scanning) return;
    setState(() {
      _scanning = true;
      _error = null;
    });

    final ok = await ref.read(biometricLockProvider.notifier).unlock();

    if (!mounted) return;
    setState(() {
      _scanning = false;
      // on success the auth gate swaps this screen out, so the message
      // only ever shows on failure
      _error = ok ? null : 'Fingerprint not recognised. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fingerprint, size: 88, color: AppTheme.tpRed),
                const SizedBox(height: 24),
                Text(
                  'TPMentorship is locked',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock with your fingerprint or face to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),

                // ----- the failure message -----
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _scanning ? null : _unlock,
                  child: _scanning
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Unlock'),
                ),
                const SizedBox(height: 12),

                // escape hatch - a broken sensor must never lock someone
                // out of their own account for good
                TextButton(
                  onPressed: widget.onUsePassword,
                  child: Text(
                    'Use password instead',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
