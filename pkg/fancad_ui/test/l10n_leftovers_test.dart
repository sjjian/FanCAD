import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty leftover language is English, the default', () {
    expect(FanCadLanguage.parse(null), FanCadLanguage.english);
    expect(FanCadLanguage.parse(''), FanCadLanguage.english);
    expect(FanCadLanguage.parse('   '), FanCadLanguage.english);
  });

  test('regional and mixed-case leftovers still resolve', () {
    expect(FanCadLanguage.parse('en-US'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('EN'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('zh'), FanCadLanguage.chinese);
    expect(FanCadLanguage.parse('zh_CN'), FanCadLanguage.chinese);
    expect(FanCadLanguage.parse('zh-Hans'), FanCadLanguage.chinese);
    expect(FanCadLanguage.parse('ZH-TW'), FanCadLanguage.chinese);
  });

  test('an unsupported leftover language does not blank the shell', () {
    expect(FanCadLanguage.parse('fr'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('de-DE'), FanCadLanguage.english);
    expect(FanCadLanguage.parse('??'), FanCadLanguage.english);
  });

  test('a leftover command id keeps the English registry title', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(l10n.commandTitle('draw.line', 'Line'), '直线');
    expect(
      l10n.commandTitle('plugin.unknown', 'My Plugin Command'),
      'My Plugin Command',
    );
  });

  test('a leftover command category keeps the registry name', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    expect(l10n.commandCategory('Draw'), '绘图');
    expect(l10n.commandCategory('Custom'), 'Custom');
  });

  testWidgets('missing localizations leftover falls back to English', (
    tester,
  ) async {
    late AppLocalizations resolved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            resolved = context.l10n;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(resolved.layers, 'Layers');
    expect(resolved.localeName, 'en');
  });
}
