import 'package:fancad_updater/fancad_updater.dart';
import 'package:test/test.dart';

void main() {
  group('parse', () {
    test('accepts a leading v and build metadata', () {
      expect(SemanticVersion.parse('v0.6.0').toString(), '0.6.0');
      expect(SemanticVersion.parse('0.6.0+42').toString(), '0.6.0');
      expect(SemanticVersion.parse(' v1.2.3 ').core, '1.2.3');
    });

    test('keeps prerelease identifiers', () {
      final version = SemanticVersion.parse('1.2.3-beta.2');
      expect(version.prerelease, ['beta', '2']);
      expect(version.isPrerelease, isTrue);
    });

    test('rejects junk instead of throwing from tryParse', () {
      expect(SemanticVersion.tryParse('latest'), isNull);
      expect(SemanticVersion.tryParse('1.2'), isNull);
      expect(SemanticVersion.tryParse(''), isNull);
      expect(() => SemanticVersion.parse('latest'), throwsFormatException);
    });
  });

  group('order', () {
    int compare(String a, String b) =>
        SemanticVersion.parse(a).compareTo(SemanticVersion.parse(b));

    test('compares the numeric parts', () {
      expect(compare('0.5.0', '0.6.0'), lessThan(0));
      expect(compare('0.10.0', '0.9.9'), greaterThan(0));
      expect(compare('1.0.0', '1.0.0'), 0);
    });

    test('a final release outranks its prerelease', () {
      expect(compare('1.0.0', '1.0.0-rc.1'), greaterThan(0));
      expect(compare('1.0.0-beta', '1.0.0-alpha'), greaterThan(0));
    });

    test('numeric identifiers sort below alphanumeric ones', () {
      expect(compare('1.0.0-2', '1.0.0-alpha'), lessThan(0));
      expect(compare('1.0.0-alpha.1', '1.0.0-alpha'), greaterThan(0));
    });

    test('build metadata does not affect precedence', () {
      expect(compare('1.0.0+1', '1.0.0+2'), 0);
    });
  });

  test('equality ignores build metadata through parse', () {
    expect(SemanticVersion.parse('1.0.0+1'), SemanticVersion.parse('1.0.0+2'));
    expect(
      SemanticVersion.parse('1.0.0+1'),
      isNot(SemanticVersion.parse('1.0.1+1')),
    );
  });
}
