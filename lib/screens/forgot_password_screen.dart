import 'package:flutter/material.dart';
// flutter's built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod for state management lets this screen read the auth providers
import 'package:tpmentorship/providers/auth_provider.dart';
// the providers that hold the auth service
import 'package:tpmentorship/services/auth_service.dart';
// the auth service that talks to firebase
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages
import 'package:tpmentorship/utils/validators.dart';
// helper to check if the email field is valid

class ForgotPasswordScreen extends ConsumerStatefulWidget {
// forgot password screen, sends a reset link to the user email
  final VoidCallback onGoToLogin;
  // go back to the login screen

  final String backLabel;
  // text shown on the back link defaults to "Back to Login"

  const ForgotPasswordScreen({
    super.key,
    required this.onGoToLogin,
    this.backLabel = 'Back to Login',
  });

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  // validate the email field
  final _emailController = TextEditingController();
  // grab whatever the user types into the email box
  bool _isLoading = false;
  // true while sending the email used to show spinner and disable button

  void _showSnackBar(String message, {bool success = false}) {
    if (!mounted) return;
    // if the screen was closed while loading dont display popup
    showAppSnackBar(context, message, success: success);
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    // check if email valid
    setState(() => _isLoading = true);
    // turn on loading spinner
    try {
      await ref
          .read(authServiceProvider)
          .sendPasswordResetEmail(_emailController.text);
          // ask firebase to send a reset email
      _showSnackBar(
        'Password reset link sent! Check your email.',
        success: true,
      );
    } catch (e) {
      _showSnackBar(AuthService.friendlyError(e));
      // if it fails show error msg
    } finally {
      if (mounted) setState(() => _isLoading = false);
      // always turn the loading spinner back off when done
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: SafeArea(
      // keep content out from under the notch/status bar
        child: SingleChildScrollView(
        // makes the form scrollable so it doesn't overflow
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            // validate the email field
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // go back to log in
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: widget.onGoToLogin,
                    child: Icon(Icons.arrow_back,
                        color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.tpRed,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.lock_reset,
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Forgot Password?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email and we will send you a link to reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 32),

                // valid email
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.email, color: AppTheme.tpRed),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 28),

                // send reset link button disabled and shows a spinner while loading
                ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Send Reset Link'),
                ),
                const SizedBox(height: 16),

                // back to login at bottom
                Center(
                  child: GestureDetector(
                    onTap: widget.onGoToLogin,
                    // tapping this goes back to the login screen
                    child: Text(
                      widget.backLabel,
                      style: TextStyle(
                        color: AppTheme.tpRed,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
  // runs when the screen is closed for good
    _emailController.dispose();
    // free the controllers memory to avoid leaks
    super.dispose();
  }
}
