import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/models/user_profile.dart';
import 'package:tpmentorship/providers/data_providers.dart';
import 'package:tpmentorship/providers/theme_provider.dart';
import 'package:tpmentorship/theme/app_theme.dart';

UserProfile _profileWithTheme(String? themeName) {
  return UserProfile(
    uid: 'test-uid',
    fullName: 'Test User',
    createdAt: DateTime(2026, 1, 1),
    themeName: themeName,
  );
}

void main() {
  group('ThemeController syncs from the logged in profile', () {
    test("applies the profile's saved theme", () async {
      final container = ProviderContainer(overrides: [
        userProfileProvider.overrideWith(
            (ref) => Stream.value(_profileWithTheme('TP Light'))),
      ]);
      addTearDown(container.dispose);

      container.read(themeProvider);
      // reading the provider constructs ThemeController, which starts
      // listening to userProfileProvider
      await Future<void>.delayed(Duration.zero);
      // let the overridden stream's first value flow through

      expect(container.read(themeProvider), AppTheme.tpLight);
    });

    test('falls back to the default theme when the profile never chose one',
        () async {
      final container = ProviderContainer(overrides: [
        userProfileProvider
            .overrideWith((ref) => Stream.value(_profileWithTheme(null))),
      ]);
      addTearDown(container.dispose);

      container.read(themeProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeProvider), AppTheme.tpDark);
    });

    test('resets to the default theme when logged out', () async {
      final container = ProviderContainer(overrides: [
        userProfileProvider.overrideWith((ref) => Stream.value(null)),
      ]);
      addTearDown(container.dispose);

      container.read(themeProvider);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(themeProvider), AppTheme.tpDark);
    });
  });
}
