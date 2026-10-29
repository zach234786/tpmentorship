import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/providers/connectivity_provider.dart';
// the offline detection provider

class OfflineBanner extends ConsumerWidget {
// additional feature: offline mode handling
// a thin banner that slides in at the top of the app whenever the
// device loses its connection, and disappears when its back
// (this is also one of the "other forms of feedback" beyond
// SnackBar and AlertDialog)

  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    // AnimatedContainer smoothly grows/shrinks instead of popping
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isOffline ? 32 : 0,
      // height 0 = completely hidden when online
      color: Colors.orange.shade800,
      child: isOffline
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.wifi_off, color: Colors.white, size: 14),
                SizedBox(width: 8),
                Text(
                  "You're offline - changes will sync when you reconnect",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : null,
    );
  }
}
