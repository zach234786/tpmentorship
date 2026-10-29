import 'package:flutter_test/flutter_test.dart';
import 'package:tpmentorship/theme/app_theme.dart';

void main() {
  group('AppTheme palettes', () {
    test('offers a third palette so the picker is not just light and dark',
        () {
      expect(AppTheme.palettes.length, greaterThanOrEqualTo(3));
    });

    test('includes the Midnight Purple palette from the Part 1 theme study',
        () {
      final names = AppTheme.palettes.map((p) => p.name).toList();
      expect(names, contains('Midnight Purple'));
    });

    test('paletteByName finds Midnight Purple instead of falling back', () {
      final palette = AppTheme.paletteByName('Midnight Purple');
      expect(palette.name, 'Midnight Purple');
      expect(palette, isNot(AppTheme.tpDark));
    });

    test('applyPalette swaps the colours every screen reads', () {
      addTearDown(() => AppTheme.applyPalette(AppTheme.tpDark));

      AppTheme.applyPalette(AppTheme.paletteByName('Midnight Purple'));

      expect(AppTheme.tpRed, AppTheme.paletteByName('Midnight Purple').accent);
      expect(AppTheme.darkBg, AppTheme.paletteByName('Midnight Purple').bg);
    });
  });
}
