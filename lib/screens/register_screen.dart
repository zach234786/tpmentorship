import 'package:flutter/material.dart';
// built in ui widgets
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod for state management, lets this screen read the auth providers
import 'package:tpmentorship/providers/auth_provider.dart';
// the providers that hold the auth service
import 'package:tpmentorship/services/auth_service.dart';
// the auth service that talks to firebase
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages
import 'package:tpmentorship/utils/validators.dart';
// helper to check if fields are valid

class RegisterScreen extends ConsumerStatefulWidget {
// register screen, same as login but for creating a new account
  final VoidCallback onGoToLogin;
  // switch back to the login screen

  const RegisterScreen({
    super.key,
    required this.onGoToLogin,
  });

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // remote control for the form lets us validate all fields at once
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  // grab whatever the user types and confirms
  bool _obscurePassword = true;
  // password hidden by default
  bool _isLoading = false;
  // true while registering used to show spinner and disable button

  void _showSnackBar(String message, {bool success = false}) {
    if (!mounted) return;
    // if the screen was closed while loading dont show a popup 
    showAppSnackBar(context, message, success: success);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    // check all fields are valid first stop if not
    setState(() => _isLoading = true);
    // turn on loading spinner
    try {
      await ref.read(authServiceProvider).register(
      // grab the auth service and try to create the account with the typed details
            name: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      // stop if the screen was closed while registering
      _showSnackBar(
        'Account created! Please log in with your details.',
        success: true,
      );
      widget.onGoToLogin();
      // account made, send the user back to the login screen
    } catch (e) {
      _showSnackBar(AuthService.friendlyError(e));
      // if register fails show  error message
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
        // makes the form scrollable so it doesnt overflow
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            // linked to _formKey so we can validate every field at once
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // back arrow, taps to go back to login 
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: widget.onGoToLogin,
                    child: Icon(Icons.arrow_back,
                        color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: AppTheme.tpRed,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.person_add,
                        color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the TP Mentorship community',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // name field must not be empty
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  // name keyboard, and capitalise each word for the user
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.person, color: AppTheme.tpRed),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                      // show error if name box is empty
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // check if email field valid
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
                const SizedBox(height: 16),

                // password field with the eye icon to show/hide
                TextFormField(
                  controller: _passwordController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.visiblePassword,
                  // password keyboard - no autocorrect or word suggestions
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.lock, color: AppTheme.tpRed),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      // eye button to show/hide password 
                    ),
                  ),
                  validator: (value) =>
                      Validators.password(value, label: 'a password'),
                ),
                const SizedBox(height: 16),

                // confirm password field must match the password above
                TextFormField(
                  controller: _confirmController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: Icon(Icons.lock_outline, color: AppTheme.tpRed),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                      // show error if this doesnt match the password field
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // register button disabled and shows a spinner while loading
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
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
                      : const Text('Register'),
                ),
                const SizedBox(height: 16),

                // already have an account? login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                    GestureDetector(
                      onTap: widget.onGoToLogin,
                      // tapping this switches back to the login screen
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: AppTheme.tpRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    // free the controllers memory to avoid leaks
    super.dispose();
  }
}
