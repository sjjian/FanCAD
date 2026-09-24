import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/assistant.dart';
import '../models/command_line.dart';
import '../models/layout.dart';
import '../models/sidebar.dart';
import '../storage/layout.dart';
import 'providers.dart';

part 'layout.g.dart';

/// Workbench chrome: open panes, the sidebar view, and the three sizes.
///
/// Every change stays in memory. The file is written once, when the process
/// is about to exit, via [persist].
@Riverpod(keepAlive: true)
class LayoutNotifier extends _$LayoutNotifier {
  LayoutStore get _settings => ref.read(appSettingsProvider).layout;

  static const _leftViews = {
    'layers',
    'properties',
    'layouts',
    'history',
    'commands',
    'plugins',
    'editor',
  };

  @override
  LayoutModel build() {
    final stored = ref.watch(appSettingsProvider).layout.load();
    return stored.copyWith(
      sidebarView: _leftViewId(stored.sidebarView),
      sidebarWidth: stored.sidebarWidth.clamp(
        SidebarLayout.minWidth,
        SidebarLayout.maxWidth,
      ),
      assistantWidth: stored.assistantWidth.clamp(
        AssistantPaneLayout.minWidth,
        AssistantPaneLayout.maxWidth,
      ),
      commandHeight: stored.commandHeight.clamp(
        CommandLineLayout.minHeight,
        CommandLineLayout.maxHeight,
      ),
    );
  }

  /// Assistant used to live here; a leftover setting must not open an empty
  /// left pane after the chat moved to the right.
  static String _leftViewId(String viewId) =>
      _leftViews.contains(viewId) ? viewId : 'layers';

  /// Clicking the active icon collapses the sidebar, as VS Code does.
  void select(String viewId) {
    final left = _leftViewId(viewId);
    if (state.sidebarView == left && state.sidebarOpen) {
      setSidebarOpen(false);
      return;
    }
    state = state.copyWith(sidebarView: left, sidebarOpen: true);
  }

  /// Brings a view forward without toggling, for `revealPanel`.
  void reveal(String viewId) {
    final left = _leftViewId(viewId);
    state = state.copyWith(sidebarView: left, sidebarOpen: true);
  }

  void setSidebarOpen(bool value) {
    state = state.copyWith(sidebarOpen: value);
  }

  void toggleSidebar() => setSidebarOpen(!state.sidebarOpen);

  void setAssistantOpen(bool value) {
    state = state.copyWith(assistantOpen: value);
  }

  void toggleAssistant() => setAssistantOpen(!state.assistantOpen);

  void resizeSidebar(double width) {
    state = state.copyWith(
      sidebarWidth: width.roundToDouble().clamp(
        SidebarLayout.minWidth,
        SidebarLayout.maxWidth,
      ),
    );
  }

  void resizeAssistant(double width) {
    state = state.copyWith(
      assistantWidth: width.roundToDouble().clamp(
        AssistantPaneLayout.minWidth,
        AssistantPaneLayout.maxWidth,
      ),
    );
  }

  void resizeCommand(double height) {
    state = state.copyWith(
      commandHeight: height.clamp(
        CommandLineLayout.minHeight,
        CommandLineLayout.maxHeight,
      ),
    );
  }

  /// Writes the in-memory layout. Called once before the process exits.
  void persist() => _settings.save(state);

  /// Double-clicking the sash puts the pane back where it started, instead of
  /// hunting for a comfortable width after a drag went too far.
  void resetSidebarWidth() {
    state = state.copyWith(sidebarWidth: SidebarLayout.defaultWidth);
  }

  void resetAssistantWidth() {
    state = state.copyWith(assistantWidth: AssistantPaneLayout.defaultWidth);
  }
}
