import 'package:fancad/fancad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme leftovers collapse to a known preference', () {
    expect(ThemePreference.parse(null), ThemePreference.dark);
    expect(ThemePreference.parse(''), ThemePreference.dark);
    expect(ThemePreference.parse('LIGHT'), ThemePreference.light);
    expect(ThemePreference.parse('system'), ThemePreference.system);
    expect(ThemePreference.parse('sepia'), ThemePreference.dark);
  });
}
