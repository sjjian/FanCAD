import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/settings.dart';
import '../storage/appearance_settings.dart';
import 'providers.dart';

part 'appearance.g.dart';

/// Theme and language. Not a layout pane.
@Riverpod(keepAlive: true)
class AppearanceNotifier extends _$AppearanceNotifier {
  AppearanceSettings get _settings => ref.read(appSettingsProvider).appearance;

  @override
  AppearanceModel build() {
    final settings = ref.watch(appSettingsProvider).appearance;
    return AppearanceModel(
      theme: ThemePreference.parse(settings.themeBrightness()),
      language: FanCadLanguage.parse(
        settings.language(fallback: FanCadLanguage.english),
      ),
    );
  }

  void toggleTheme() {
    setPreference(
      state.theme == ThemePreference.light
          ? ThemePreference.dark
          : ThemePreference.light,
    );
  }

  void setPreference(ThemePreference value) {
    if (state.theme == value) return;
    state = state.copyWith(theme: value);
    _settings.setThemeBrightness(value.id);
  }

  void setLanguage(String value) {
    final language = FanCadLanguage.parse(value);
    if (state.language == language) return;
    state = state.copyWith(language: language);
    _settings.setLanguage(state.language);
  }
}
