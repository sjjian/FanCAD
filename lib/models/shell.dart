import 'package:freezed_annotation/freezed_annotation.dart';

part 'shell.freezed.dart';

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

/// Stored theme choice. `system` follows the OS; the other two pin a scheme.
enum ThemePreference {
  dark,
  light,
  system;

  static const ThemePreference fallback = ThemePreference.dark;

  /// Maps a leftover settings string onto a known choice.
  static ThemePreference parse(
    String? raw, {
    ThemePreference fallback = fallback,
  }) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'light' => ThemePreference.light,
      'system' => ThemePreference.system,
      'dark' => ThemePreference.dark,
      _ => fallback,
    };
  }

  /// Wire value written to `settings.json`.
  String get id => name;
}

/// Which sidebar view is showing, and whether the sidebar is open at all.
@freezed
abstract class SidebarModel with _$SidebarModel {
  const factory SidebarModel({
    @Default('layers') String viewId,
    @Default(true) bool isOpen,
    @Default(240) double width,
  }) = _SidebarModel;
}

/// Height of the command line pane, and whether the history is expanded.
@freezed
abstract class CommandPaneModel with _$CommandPaneModel {
  const factory CommandPaneModel({
    @Default(84) double height,
    @Default(false) bool isExpanded,
  }) = _CommandPaneModel;
}

/// The assistant chat, docked on the right so it can stay open next to Layers.
@freezed
abstract class AssistantPaneModel with _$AssistantPaneModel {
  const factory AssistantPaneModel({
    @Default(false) bool isOpen,
    @Default(320) double width,
  }) = _AssistantPaneModel;
}

/// Application-layer store of the shell: layout panes, theme, language.
@freezed
abstract class ShellModel with _$ShellModel {
  const factory ShellModel({
    @Default(SidebarModel()) SidebarModel sidebar,
    @Default(CommandPaneModel()) CommandPaneModel commandPane,
    @Default(AssistantPaneModel()) AssistantPaneModel assistant,
    @Default(ThemePreference.fallback) ThemePreference theme,
    @Default(FanCadLanguage.english) String language,
    @Default(false) bool paletteOpen,
  }) = _ShellModel;
}
