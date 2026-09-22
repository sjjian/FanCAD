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
/// Dragging a sash updates [state] only. The file is written when the drag
/// ends, and when a pane is opened, closed, or switched.
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
    _settings.save(state);
  }

  /// Brings a view forward without toggling, for `revealPanel`.
  void reveal(String viewId) {
    final left = _leftViewId(viewId);
    state = state.copyWith(sidebarView: left, sidebarOpen: true);
    _settings.save(state);
  }

  void setSidebarOpen(bool value) {
    state = state.copyWith(sidebarOpen: value);
    _settings.save(state);
  }

  void toggleSidebar() => setSidebarOpen(!state.sidebarOpen);

  void setAssistantOpen(bool value) {
    state = state.copyWith(assistantOpen: value);
    _settings.save(state);
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

  /// Persisted on drag end rather than on every frame, to avoid writing the
  /// settings file sixty times a second.
  void commit() => _settings.save(state);

  /// Double-clicking the sash puts the pane back where it started, instead of
  /// hunting for a comfortable width after a drag went too far.
  void resetSidebarWidth() {
    state = state.copyWith(sidebarWidth: SidebarLayout.defaultWidth);
    commit();
  }

  void resetAssistantWidth() {
    state = state.copyWith(assistantWidth: AssistantPaneLayout.defaultWidth);
    commit();
  }
}
