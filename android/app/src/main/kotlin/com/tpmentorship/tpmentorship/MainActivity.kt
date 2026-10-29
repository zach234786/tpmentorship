package com.tpmentorship.tpmentorship

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
// the biometric prompt is an AndroidX BiometricPrompt, which can only be
// hosted by a FragmentActivity. with the plain FlutterActivity the
// fingerprint unlock throws "no_fragment_activity" at run time
class MainActivity : FlutterFragmentActivity()
