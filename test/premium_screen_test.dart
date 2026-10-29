import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/providers/auth_provider.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/screens/premium_screen.dart';
import 'package:tpmentorship/services/nets_service.dart';
import 'package:tpmentorship/services/user_service.dart';
import 'package:tpmentorship/widgets/nets_payment_panel.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

class _FakeNetsService implements NETSService {
  final StreamController<String> webhook = StreamController<String>.broadcast();

  @override
  bool get isConfigured => true;

  @override
  Future<NetsQr> requestQr(double amount) async =>
      NetsQr(image: base64Decode(_pngBase64), txnRef: 'ref-1');

  @override
  Stream<String> webhookStream(String txnRef) => webhook.stream;

  // this test only renders the screen, so the transaction stays pending -
  // anything else would settle it out from under the assertions
  @override
  Future<NetsPaymentResult> queryPayment(
    String txnRef, {
    bool frontendTimedOut = false,
  }) async =>
      NetsPaymentResult.pending;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUserService implements UserService {
  @override
  Future<void> upgradeToPremium(String uid) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUser implements User {
  @override
  String get uid => 'student-1';

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('shows the benefits and hosts the NETS panel', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        netsServiceProvider.overrideWithValue(_FakeNetsService()),
        userServiceProvider.overrideWithValue(_FakeUserService()),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
      ],
      child: const MaterialApp(home: PremiumScreen()),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('TPMentorship Premium'), findsOneWidget);
    expect(find.text('Priority when booking sessions'), findsOneWidget);
    expect(find.byType(NetsPaymentPanel), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('advertises the same price the service charges',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        netsServiceProvider.overrideWithValue(_FakeNetsService()),
        userServiceProvider.overrideWithValue(_FakeUserService()),
        authStateProvider.overrideWith((ref) => Stream<User?>.value(_FakeUser())),
      ],
      child: const MaterialApp(home: PremiumScreen()),
    ));
    await tester.pump();
    await tester.pump();

    final price = NETSService.premiumPriceSgd.toStringAsFixed(2);
    expect(find.textContaining('\$$price/month'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
