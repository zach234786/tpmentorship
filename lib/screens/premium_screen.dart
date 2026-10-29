import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/services/nets_service.dart';
// for the price constant, so the advertised price matches the charge
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/widgets/nets_payment_panel.dart';
// the NETS QR payment flow

class PremiumScreen extends ConsumerWidget {
// upgrading to TPMentorship Premium by paying with NETS QR
//
// this screen only sells premium - the payment itself lives in
// NetsPaymentPanel, which talks to the NETS sandbox and unlocks
// premium once NETS confirms the transaction

  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = NETSService.premiumPriceSgd.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(title: const Text('Go Premium')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ----- what you get -----
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCardBg,
                  border: Border.all(color: AppTheme.darkBorder),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TPMentorship Premium',
                          style: TextStyle(
                            color: AppTheme.tpRed,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.workspace_premium,
                            color: Colors.amber, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$$price/month - first time purchase gets '
                      '+3 months free',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _benefit('Priority when booking sessions'),
                    _benefit('Instant messages without needing to book'),
                    _benefit('Support student mentors on the platform'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ----- the NETS QR payment -----
              const NetsPaymentPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // one green-ticked benefit line
  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
