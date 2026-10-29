import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/providers/biometric_provider.dart';
import 'package:tpmentorship/screens/lock_screen.dart';
import 'package:tpmentorship/services/biometric_service.dart';

class _FakeBiometricService implements BiometricService {
  _FakeBiometricService({this.scanSucceeds = true});

  final bool scanSucceeds;
  int authenticateCalls = 0;

  @override
  Future<bool> isEnabled() async => true;

  @override
  Future<void> setEnabled(bool value) async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate({String reason = 'Unlock TPMentorship'}) async {
    authenticateCalls++;
    return scanSucceeds;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestApp(
  _FakeBiometricService fake, {
  VoidCallback? onUsePassword,
}) {
  return ProviderScope(
    overrides: [
      biometricServiceProvider.overrideWithValue(fake),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: LockScreen(onUsePassword: onUsePassword ?? () {}),
    ),
  );
}

void main() {
  group('LockScreen', () {
    testWidgets('offers a way to retry the scan and a password escape hatch',
        (tester) async {
      await tester.pumpWidget(_buildTestApp(_FakeBiometricService()));
      await tester.pumpAndSettle();

      expect(find.text('Unlock'), findsOneWidget);
      expect(find.text('Use password instead'), findsOneWidget);
    });

    testWidgets('shows an error when the scan fails', (tester) async {
      await tester
          .pumpWidget(_buildTestApp(_FakeBiometricService(scanSucceeds: false)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.textContaining('not recognised'), findsOneWidget);
    });

    testWidgets('signing out runs the password escape hatch', (tester) async {
      var calls = 0;
      await tester.pumpWidget(_buildTestApp(
        _FakeBiometricService(scanSucceeds: false),
        onUsePassword: () => calls++,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use password instead'));
      await tester.pumpAndSettle();

      expect(calls, 1);
    });
  });
}
