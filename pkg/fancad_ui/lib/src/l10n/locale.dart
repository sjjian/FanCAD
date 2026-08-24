/// Supported UI languages, stored the same way OpenHare does: `en` and `zh`.
class FanCadLanguage {
  const FanCadLanguage._();

  static const String english = 'en';
  static const String chinese = 'zh';

  static const List<String> supported = [english, chinese];

  /// Maps leftover or regional tags onto a supported language.
  ///
  /// `zh_CN`, `zh-Hans` and `ZH` are Chinese. `en-US` is English. Anything
  /// else, including a blank leftover, falls back to English so the shell
  /// still has strings.
  static String parse(String? raw, {String fallback = english}) {
    final value = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '');
    if (value.isEmpty) return fallback;
    final language = value.split('-').first;
    if (language == chinese) return chinese;
    if (language == english) return english;
    return fallback;
  }
}
