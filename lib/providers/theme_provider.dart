import 'package:flutter_riverpod/flutter_riverpod.dart';
// riverpod state management
import 'package:tpmentorship/providers/auth_provider.dart';
// gives us the logged in user's uid, to save the theme against their account
import 'package:tpmentorship/providers/data_providers.dart';
// gives us the logged in user's live firestore profile and its themeName
import 'package:tpmentorship/theme/app_theme.dart';
// the palettes

class ThemeController extends StateNotifier<AppPalette> {
// part 3 personalisation: remembers and switches the app's theme.
// the choice lives on the logged in user's Firestore profile (not the
// device), so it follows the account across logins and devices, and
// resets to the default the moment nobody is logged in
  ThemeController(this._ref) : super(AppTheme.tpDark) {
    _ref.listen(userProfileProvider, (previous, next) {
      _applyFromProfile(next.value?.themeName);
    }, fireImmediately: true);
  }

  final Ref _ref;

  // applies whatever theme the logged in profile has saved - or the
  // default if it never chose one, or nobody is logged in
  void _applyFromProfile(String? themeName) {
    final palette = themeName == null
        ? AppTheme.tpDark
        : AppTheme.paletteByName(themeName);
    AppTheme.applyPalette(palette);
    state = palette;
  }

  // called when the user picks a theme in settings - applies it straight
  // away so the UI feels instant, then saves it to their Firestore profile
  // so it follows them next time they log in (this device or another)
  Future<void> setPalette(AppPalette palette) async {
    AppTheme.applyPalette(palette);
    state = palette;

    final uid = _ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    // not logged in - shouldn't happen since the theme picker only opens
    // from settings, which requires being logged in, but guard anyway

    await _ref.read(userServiceProvider).updateTheme(uid, palette.name);
  }
}

// the provider screens watch to know the active theme
final themeProvider =
    StateNotifierProvider<ThemeController, AppPalette>((ref) {
  return ThemeController(ref);
});
