import 'package:flutter/material.dart';
// flutter's built in ui widgets (buttons, text fields, etc)
import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod for state management, lets this screen read the auth providers
import 'package:tpmentorship/providers/auth_provider.dart';
// the providers that hold the auth service and login state
import 'package:tpmentorship/services/auth_service.dart';
// the auth service that talks to firebase (login, register, etc)
import 'package:tpmentorship/theme/app_theme.dart';
// app colours and styling
import 'package:tpmentorship/utils/snackbar_helper.dart';
// helper to show popup messages at the bottom of the screen
import 'package:tpmentorship/utils/validators.dart';
// helper to check if email/password fields are valid

class LoginScreen extends ConsumerStatefulWidget {
// login screen, ConsumerStatefulWidget means it can change itself and read riverpod providers
  final VoidCallback onGoToRegister;
  // function passed in from the parent to switch to the register screen
  final VoidCallback onGoToForgotPassword;
  // function passed in from the parent to switch to the forgot password screen

  const LoginScreen({
    super.key,
    required this.onGoToRegister,
    required this.onGoToForgotPassword,
    // whoever creates this screen must provide these two functions
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  // remote control for the form, lets us validate all fields at once
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // grab whatever the user types into the email and password boxes
  bool _obscurePassword = true;
  // password hidden by default
  bool _rememberMe = false;
  // remember me checkbox starts unchecked
  bool _isLoading = false;
  // true while logging in, used to show spinner and disable buttons

  void _showSnackBar(String message, {bool success = false}) {
    if (!mounted) return;
    // if the screen was closed while loading dont display pop up
    showAppSnackBar(context, message, success: success);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    // check all fields are valid first, stop if not
    setState(() => _isLoading = true);
    // turn on loading spinner
    try {
      await ref.read(authServiceProvider).login(
      // grab the auth service and try to log in with the typed email and password
            email: _emailController.text,
            password: _passwordController.text,
          );
    } catch (e) {
      _showSnackBar(AuthService.friendlyError(e));
      // if login fails, show error message
    } finally {
      if (mounted) setState(() => _isLoading = false);
      // always turn the loading spinner back off when done
    }
  }

  Future<void> _signInWithGoogle() async {
  // same pattern as login but uses the google sign in popup 
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      _showSnackBar(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGitHub() async {
  // same pattern but uses the github sign in popup
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).signInWithGitHub();
    } catch (e) {
      _showSnackBar(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Stack(
      // Stack layers widgets on top of each other
        children: [
          Positioned(
          // red gradient glow at the bottom of the screen, sits behind the form
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.darkBg,
                    AppTheme.tpRed.withValues(alpha: 0.3),
                    AppTheme.tpRed.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
          // keep content out from under the notch/status bar
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                // makes the form scrollable so it doesn't overflow when the keyboard pops up
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                    // make the form at least as tall as the screen but taller if needed
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Form(
                          key: _formKey,
                          // linked to _formKey so we can validate every field at once
                          child: Column(
                            children: [
                              const SizedBox(height: 40),

                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppTheme.tpRedLight, AppTheme.tpRed],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.tpRed.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    const Center(
                                      child: Text(
                                        'TP',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.people,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'TP ',
                                      style: TextStyle(
                                        color: AppTheme.tpRed,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Mentorship',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Connect. Learn. Grow Together',
                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              ),
                              const SizedBox(height: 24),

                              //"don't have an account? register here" link 
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                  GestureDetector(
                                    onTap: widget.onGoToRegister,
                                    // tapping this calls the function to switch to the register screen
                                    child: Text(
                                      'Register Here.',
                                      style: TextStyle(
                                        color: AppTheme.tpRed,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // card holding the email and password fields 
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkCardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.darkBorder),
                                ),
                                child: Column(
                                  children: [
                                    // email field, displayed as a Student ID
                                    TextFormField(
                                      controller: _emailController,
                                      style: TextStyle(color: AppTheme.textPrimary),
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        hintText: 'Student ID',
                                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(10),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.darkBg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.person_outline,
                                              color: AppTheme.textSecondary, size: 18),
                                        ),
                                        fillColor: AppTheme.darkBg,
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppTheme.darkBorder),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppTheme.darkBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppTheme.tpRed, width: 2),
                                        ),
                                      ),
                                      validator: (value) => Validators
                                          .email(value, field: 'Student ID'),
                                      // checks it's a valid email
                                    ),
                                    const SizedBox(height: 12),

                                    // password field, with the eye icon to show/hide
                                    TextFormField(
                                      controller: _passwordController,
                                      style: TextStyle(color: AppTheme.textPrimary),
                                      keyboardType: TextInputType.visiblePassword,
                                      // password keyboard - no autocorrect or word suggestions
                                      obscureText: _obscurePassword,
                                      // hides the text when true
                                      decoration: InputDecoration(
                                        hintText: 'Password',
                                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                                        prefixIcon: Container(
                                          margin: const EdgeInsets.all(10),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppTheme.darkBg,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.lock_outline,
                                              color: AppTheme.textSecondary, size: 18),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: AppTheme.textSecondary,
                                            size: 18,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscurePassword = !_obscurePassword),
                                          // eye button, flips show/hide password 
                                        ),
                                        fillColor: AppTheme.darkBg,
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppTheme.darkBorder),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppTheme.darkBorder),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: AppTheme.tpRed, width: 2),
                                        ),
                                      ),
                                      validator: Validators.password,
                                      // checks the password is valid
                                    ),
                                    const SizedBox(height: 4),

                                    // --- remember me checkbox + forgot password link ---
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 36,
                                              height: 36,
                                              child: Checkbox(
                                                value: _rememberMe,
                                                onChanged: (value) => setState(
                                                    () => _rememberMe = value ?? false),
                                                // update the remember me state when tapped
                                                fillColor: WidgetStateProperty.resolveWith(
                                                  (states) => states.contains(WidgetState.selected)
                                                      ? AppTheme.tpRed
                                                      : Colors.transparent,
                                                ),
                                                side: BorderSide(color: AppTheme.tpRed, width: 2),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Remember Me?',
                                              style: TextStyle(
                                                  color: AppTheme.textSecondary, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        GestureDetector(
                                          onTap: widget.onGoToForgotPassword,
                                          // tapping switches to the forgot password screen
                                          child: Text(
                                            'Forgot Password?',
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
                              const SizedBox(height: 20),

                              // login button 
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  // disabled while loading so you can't tap twice
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.tpRed,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                    shadowColor: AppTheme.tpRed.withValues(alpha: 0.5),
                                  ),
                                  child: _isLoading
                                      // show a spinner while loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // divider between login and social sign in 
                              Row(
                                children: [
                                  Expanded(child: Divider(color: AppTheme.darkBorder)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text('OR',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  ),
                                  Expanded(child: Divider(color: AppTheme.darkBorder)),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // google sign in button 
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isLoading ? null : _signInWithGoogle,
                                  icon: Icon(Icons.g_mobiledata,
                                      color: AppTheme.tpRed, size: 28),
                                  label: const Text('Continue with Google'),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // github sign in button 
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed:
                                      _isLoading ? null : _signInWithGitHub,
                                  icon: Icon(Icons.code,
                                      color: AppTheme.tpRed),
                                  label: const Text('Continue with GitHub'),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
  // runs when the screen is closed 
    _emailController.dispose();
    _passwordController.dispose();
    // free memory to avoid leaks
    super.dispose();
  }
}
