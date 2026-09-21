import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/shell.dart';
import '../screen/theme/tokens.dart';
import '../storage/shell_settings.dart';
import 'providers.dart';

part 'shell.g.dart';

/// Layout, theme and language. One store; chrome is low-frequency.
@Riverpod(keepAlive: true)
class ShellNotifier extends _$ShellNotifier {
  ShellSettings get _settings => ref.read(appSettingsProvider).shell;

  static const double sidebarDefaultWidth = FanCadTokens.sidePanelWidth;
  static const double sidebarMinWidth = FanCadTokens.sidePanelMinWidth;
  static const double sidebarMaxWidth = FanCadTokens.sidePanelMaxWidth;

  /// Splitter plus the input row. History is given no pixels, so collapse
  /// looks like a single command line rather than a half-empty console.
  static const double commandCollapsedHeight =
      FanCadTokens.splitterHit + FanCadTokens.commandLineHeight;

  /// Input plus two or three history lines — enough to read a prompt.
  static const double commandDefaultHeight = 84;

  /// Tall enough to reread an import warning, short enough to keep the canvas.
  static const double commandExpandedHeight = 200;

  static const double commandMinHeight = commandCollapsedHeight;
  static const double commandMaxHeight = 420;

  static const double assistantDefaultWidth = 320;
  static const double assistantMinWidth = FanCadTokens.sidePanelMinWidth;
  static const double assistantMaxWidth = FanCadTokens.sidePanelMaxWidth;

  static const _leftViews = {
    'layers',
    'properties',
    'layouts',
    'history',
    'commands',
    'plugins',
    'editor',
  };

  /// Not persisted. Survives a settings-driven [build] rebuild.
  bool _paletteOpen = false;
  bool _commandExpanded = false;

  @override
  ShellModel build() {
    final settings = ref.watch(appSettingsProvider).shell;
    return ShellModel(
      sidebar: SidebarModel(
        viewId: _leftViewId(settings.sidebarView()),
        isOpen: settings.sidebarOpen(),
        width: settings
            .sidebarWidth(fallback: sidebarDefaultWidth)
            .clamp(sidebarMinWidth, sidebarMaxWidth),
      ),
      commandPane: CommandPaneModel(
        height: settings
            .commandPaneHeight(fallback: commandDefaultHeight)
            .clamp(commandMinHeight, commandMaxHeight),
        isExpanded: _commandExpanded,
      ),
      assistant: AssistantPaneModel(
        isOpen: settings.assistantOpen(),
        width: settings
            .assistantWidth(fallback: assistantDefaultWidth)
            .clamp(assistantMinWidth, assistantMaxWidth),
      ),
      theme: ThemePreference.parse(settings.themeBrightness()),
      language: FanCadLanguage.parse(
        settings.language(fallback: FanCadLanguage.english),
      ),
      paletteOpen: _paletteOpen,
    );
  }

  /// Assistant used to live here; a leftover setting must not open an empty
  /// left pane after the chat moved to the right.
  static String _leftViewId(String viewId) =>
      _leftViews.contains(viewId) ? viewId : 'layers';

  /// Clicking the active icon collapses the sidebar, as VS Code does.
  void select(String viewId) {
    final left = _leftViewId(viewId);
    if (state.sidebar.viewId == left && state.sidebar.isOpen) {
      setOpen(false);
      return;
    }
    state = state.copyWith(
      sidebar: state.sidebar.copyWith(viewId: left, isOpen: true),
    );
    _settings
      ..setSidebarView(left)
      ..setSidebarOpen(true);
  }

  /// Brings a view forward without toggling, for `revealPanel`.
  void reveal(String viewId) {
    final left = _leftViewId(viewId);
    state = state.copyWith(
      sidebar: state.sidebar.copyWith(viewId: left, isOpen: true),
    );
    _settings
      ..setSidebarView(left)
      ..setSidebarOpen(true);
  }

  void setOpen(bool value) {
    state = state.copyWith(sidebar: state.sidebar.copyWith(isOpen: value));
    _settings.setSidebarOpen(value);
  }

  void toggle() => setOpen(!state.sidebar.isOpen);

  void resize(double width) {
    state = state.copyWith(
      sidebar: state.sidebar.copyWith(
        width: width.roundToDouble().clamp(sidebarMinWidth, sidebarMaxWidth),
      ),
    );
  }

  /// Persisted on drag end rather than on every frame, to avoid writing the
  /// settings file sixty times a second.
  void commitWidth() => _settings.setSidebarWidth(state.sidebar.width);

  /// Double-clicking the sash puts the pane back where it started, instead of
  /// hunting for a comfortable width after a drag went too far.
  void resetWidth() {
    state = state.copyWith(
      sidebar: state.sidebar.copyWith(width: sidebarDefaultWidth),
    );
    commitWidth();
  }

  void resizeCommand(double height) {
    state = state.copyWith(
      commandPane: state.commandPane.copyWith(
        height: height.clamp(commandMinHeight, commandMaxHeight),
      ),
    );
  }

  void commitCommandHeight() =>
      _settings.setCommandPaneHeight(state.commandPane.height);

  void toggleCommandExpanded() {
    _commandExpanded = !state.commandPane.isExpanded;
    state = state.copyWith(
      commandPane: state.commandPane.copyWith(
        isExpanded: _commandExpanded,
        height: _commandExpanded
            ? commandExpandedHeight
            : commandCollapsedHeight,
      ),
    );
  }

  void setAssistantOpen(bool value) {
    state = state.copyWith(assistant: state.assistant.copyWith(isOpen: value));
    _settings.setAssistantOpen(value);
  }

  void toggleAssistant() => setAssistantOpen(!state.assistant.isOpen);

  void resizeAssistant(double width) {
    state = state.copyWith(
      assistant: state.assistant.copyWith(
        width: width.roundToDouble().clamp(
          assistantMinWidth,
          assistantMaxWidth,
        ),
      ),
    );
  }

  void commitAssistantWidth() =>
      _settings.setAssistantWidth(state.assistant.width);

  void resetAssistantWidth() {
    state = state.copyWith(
      assistant: state.assistant.copyWith(width: assistantDefaultWidth),
    );
    commitAssistantWidth();
  }

  void setPaletteOpen(bool value) {
    if (_paletteOpen == value) return;
    _paletteOpen = value;
    state = state.copyWith(paletteOpen: value);
  }

  void togglePalette() => setPaletteOpen(!state.paletteOpen);

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

/// Shell chrome. Prefer [ShellNotifier] at new call sites.
typedef Shell = ShellNotifier;
