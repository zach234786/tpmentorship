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
// helper to check if fields are valid

class ChangePasswordScreen extends ConsumerStatefulWidget {
// change password screen lets a logged in user set a new password
  final VoidCallback? onForgotPassword;
  // to switch to the forgot password screen 

  const ChangePasswordScreen({
    super.key,
    this.onForgotPassword,
  });

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  // to validate all fields
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // grab whatever the user types into the current new and confirm password boxes
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  // each password field hidden has its own eye toggle
  bool _isLoading = false;
  // true while changing password used to show spinner and disable button

  void _showSnackBar(String message, {bool success = false}) {
    if (!mounted) return;
    // if the screen was closed while loading dont display popup
    showAppSnackBar(context, message, success: success);
  }

  Future<void> _changePassword() async {
    final authService = ref.read(authServiceProvider);
    // grab the auth service once for this action
    if (!authService.isEmailPasswordAccount) {
      // if the user signed in with google/github they have no password to change
      _showSnackBar('Only available for email/password accounts');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    // check all fields are valid first, stop if not

    setState(() => _isLoading = true);
    // turn on loading spinner
    try {
      await authService.changePassword(
      // try to change the password using the old and new passwords typed
        oldPassword: _oldPasswordController.text,
        newPassword: _newPasswordController.text,
      );
      if (mounted) {
        _showSnackBar('Password changed successfully!', success: true);
        Navigator.pop(context);
        // close this screen and go back to the previous one
      }
    } catch (e) {
      if (mounted) _showSnackBar(AuthService.friendlyError(e));
      // if it fails show error message
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
            // to validate every field 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // back arrow, closes this screen and goes back 
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.arrow_back,
                        color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 24),

                // title and subtitle
                Text(
                  'Change Password',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your current password and choose a new one.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // current password field with its own eye toggle
                TextFormField(
                  controller: _oldPasswordController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.visiblePassword,
                  // password keyboard - no autocorrect or word suggestions
                  obscureText: _obscureOldPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle:
                        TextStyle(color: AppTheme.textSecondary),
                    prefixIcon:
                        Icon(Icons.lock, color: AppTheme.tpRed),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureOldPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => setState(
                          () => _obscureOldPassword = !_obscureOldPassword),
                      // eye button flips show/hide for the current password
                    ),
                  ),
                  validator: (value) =>
                      Validators.password(value, label: 'your current password'),
                ),
                const SizedBox(height: 16),

                // new password field, must be valid and different from the current one
                TextFormField(
                  controller: _newPasswordController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle:
                        TextStyle(color: AppTheme.textSecondary),
                    prefixIcon:
                        Icon(Icons.lock_outline, color: AppTheme.tpRed),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword),
                      // eye button to show/hide for the new password
                    ),
                  ),
                  validator: (value) {
                    final error =
                        Validators.password(value, label: 'a new password');
                    if (error != null) return error;
                    // check if new password valid
                    if (value == _oldPasswordController.text) {
                      return 'New password must be different from current';
                      // check its different from old pw
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // confirm password field must match the new password above
                TextFormField(
                  controller: _confirmPasswordController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  keyboardType: TextInputType.visiblePassword,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    labelStyle:
                        TextStyle(color: AppTheme.textSecondary),
                    prefixIcon:
                        Icon(Icons.lock_outline, color: AppTheme.tpRed),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppTheme.textSecondary,
                      ),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                      // eye button to show/hide for the confirm password
                    ),
                  ),
                  validator: (value) {
                    final error = Validators.password(value,
                        label: 'your new password again');
                    if (error != null) return error;
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                      // show error if this doesnt match the new password field
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // change password button, disabled and shows a spinner while loading
                ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
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
                      : const Text('Change Password'),
                ),
                const SizedBox(height: 16),

                // forgot password link
                Center(
                  child: GestureDetector(
                    onTap: widget.onForgotPassword,
                    // tapping this switches to the forgot password screen
                    child: Text(
                      'Forgot Password?',
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
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    // free the controllers memory to avoid leaks
    super.dispose();
  }
}
