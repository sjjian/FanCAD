import 'package:fancad/fancad.dart';
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
}
