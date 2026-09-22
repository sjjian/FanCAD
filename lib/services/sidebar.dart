import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/sidebar.dart';
import '../storage/sidebar_settings.dart';
import 'providers.dart';

part 'sidebar.g.dart';

/// Left sidebar: which view is showing, whether it is open, and its width.
@Riverpod(keepAlive: true)
class SidebarNotifier extends _$SidebarNotifier {
  SidebarSettings get _settings => ref.read(appSettingsProvider).sidebar;

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
  SidebarModel build() {
    final settings = ref.watch(appSettingsProvider).sidebar;
    return SidebarModel(
      viewId: _leftViewId(settings.view()),
      isOpen: settings.isOpen(),
      width: settings
          .width(fallback: SidebarLayout.defaultWidth)
          .clamp(SidebarLayout.minWidth, SidebarLayout.maxWidth),
    );
  }

  /// Assistant used to live here; a leftover setting must not open an empty
  /// left pane after the chat moved to the right.
  static String _leftViewId(String viewId) =>
      _leftViews.contains(viewId) ? viewId : 'layers';

  /// Clicking the active icon collapses the sidebar, as VS Code does.
  void select(String viewId) {
    final left = _leftViewId(viewId);
    if (state.viewId == left && state.isOpen) {
      setOpen(false);
      return;
    }
    state = state.copyWith(viewId: left, isOpen: true);
    _settings
      ..setView(left)
      ..setOpen(true);
  }

  /// Brings a view forward without toggling, for `revealPanel`.
  void reveal(String viewId) {
    final left = _leftViewId(viewId);
    state = state.copyWith(viewId: left, isOpen: true);
    _settings
      ..setView(left)
      ..setOpen(true);
  }

  void setOpen(bool value) {
    state = state.copyWith(isOpen: value);
    _settings.setOpen(value);
  }

  void toggle() => setOpen(!state.isOpen);

  void resize(double width) {
    state = state.copyWith(
      width: width.roundToDouble().clamp(
        SidebarLayout.minWidth,
        SidebarLayout.maxWidth,
      ),
    );
  }

  /// Persisted on drag end rather than on every frame, to avoid writing the
  /// settings file sixty times a second.
  void commitWidth() => _settings.setWidth(state.width);

  /// Double-clicking the sash puts the pane back where it started, instead of
  /// hunting for a comfortable width after a drag went too far.
  void resetWidth() {
    state = state.copyWith(width: SidebarLayout.defaultWidth);
    commitWidth();
  }
}
