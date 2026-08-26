import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../business/commands/builtins.dart';
import '../business/commands/file_commands.dart';
import '../business/commands/plugin_commands.dart';
import '../business/l10n/locale.dart';
import '../business/theme/tokens.dart';
import '../storage/app_settings.dart';
import '../storage/settings.dart';
import '../storage/shell_settings.dart';
import 'ai_controller.dart';
import 'plugin/host_call.dart';
import 'plugin_delegate.dart';
import 'workspace.dart';

part 'providers.freezed.dart';
part 'providers.g.dart';

/// Riverpod wiring for the application.
///
/// Only the genuinely global things live here. Per-document state hangs off
/// [Workspace] rather than off providers, because a provider per tab would make
/// "which document is this?" a question with two answers, and every CAD bug
/// worth fearing starts that way.

/// Provided by the app at startup, after settings have been loaded from disk.
@Riverpod(keepAlive: true)
SettingsStore settings(Ref ref) =>
    throw StateError('settingsProvider must be overridden at startup');

/// The same bag, split into the views services actually ask for.
@Riverpod(keepAlive: true)
AppSettings appSettings(Ref ref) =>
    AppSettings(ref.watch(settingsProvider));

/// The on-disk FCB cache, or null when no cache directory is available.
///
/// Overridden at startup once the platform support directory is known, and left
/// null in tests so that a test run never touches a real cache.
@Riverpod(keepAlive: true)
FcbCache? fcbCache(Ref ref) => null;

/// The drawing importer. Overridden in tests with a stub backend.
@Riverpod(keepAlive: true)
DrawingImporter importer(Ref ref) =>
    DrawingImporter(cache: ref.watch(fcbCacheProvider));

@Riverpod(keepAlive: true)
CommandRegistry commandRegistry(Ref ref) {
  final registry = CommandRegistry();
  ref.onDispose(registry.dispose);
  return registry;
}

/// The application state.
///
/// A generated [Provider] over a [ChangeNotifier] rather than a
/// `ChangeNotifierProvider`, because there must be exactly one owner of its
/// disposal and the registration below has to be torn down first. Widgets
/// subscribe with a `ListenableBuilder`, which also keeps rebuilds scoped to the
/// part of the shell that actually changed — during a drag the workspace
/// notifies dozens of times a second, and rebuilding the whole tree at that rate
/// is the difference between a smooth pan and a stuttering one.
@Riverpod(keepAlive: true)
Workspace workspace(Ref ref) {
  final workspace = Workspace(
    commands: ref.watch(commandRegistryProvider),
    importer: ref.watch(importerProvider),
    drawing: ref.watch(appSettingsProvider).drawing,
  );

  // The file commands are the one group that has to act on the workspace
  // itself, so they are constructed here where both halves are in scope.
  final registration = registerBuiltinCommands(
    workspace.commands,
    fileCommands: FileCommands(
      openFile: (path) async => await workspace.openFile(path) != null,
      newDocument: workspace.newDocument,
      closeActive: ({bool force = false}) =>
          workspace.closeTab(workspace.activeIndex, force: force),
      saveActive: (path) => workspace.saveActive(path),
      recentFiles: () => workspace.recentFiles,
    ),
    pluginCommands: ref.watch(pluginCommandsProvider),
  );

  ref.onDispose(() {
    registration.dispose();
    workspace.dispose();
  });
  return workspace;
}

/// Where user extensions live. Overridden at startup with a real path, and left
/// empty in tests so that a test run never scans the user's real folder.
@Riverpod(keepAlive: true)
String pluginsDirectory(Ref ref) => '';

/// The extension host, or null when this session has no extensions folder.
///
/// Null rather than a host with nowhere to load from: it keeps a test run from
/// spawning a worker isolate, and it gives the extensions panel something
/// honest to say instead of showing an empty list that will never fill.
@Riverpod(keepAlive: true)
PluginHost? pluginHost(Ref ref) {
  if (ref.watch(pluginsDirectoryProvider).isEmpty) return null;
  final host = PluginHost(
    registry: ref.watch(commandRegistryProvider),
    delegate: ref.watch(pluginDelegateProvider),
    transport: ref.watch(pluginTransportProvider),
    createHostCall: createFanCadHostCall,
  );
  ref.onDispose(host.dispose);
  return host;
}

/// The transport plugins run over. Overridden in tests with [LocalTransport].
@Riverpod(keepAlive: true)
PluginTransport pluginTransport(Ref ref) => IsolateTransport();

@Riverpod(keepAlive: true)
WorkspacePluginDelegate pluginDelegate(Ref ref) {
  return WorkspacePluginDelegate(
    workspace: () => ref.read(workspaceProvider),
    plugins: ref.watch(appSettingsProvider).plugins,
  );
}

/// The assistant session. Created even when no key is configured so the panel
/// can explain how to set one up.
@Riverpod(keepAlive: true)
AiController aiController(Ref ref) {
  final controller = AiController(
    workspace: ref.watch(workspaceProvider),
    assistant: ref.watch(appSettingsProvider).assistant,
    host: ref.watch(pluginHostProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// The extension management commands, or null when there is no plugins folder.
@Riverpod(keepAlive: true)
PluginCommands? pluginCommands(Ref ref) {
  final directory = ref.watch(pluginsDirectoryProvider);
  final host = ref.watch(pluginHostProvider);
  if (directory.isEmpty || host == null) return null;
  return PluginCommands(host: host, pluginsDirectory: directory);
}

/// Which sidebar view is showing, and whether the sidebar is open at all.
@freezed
abstract class SidebarState with _$SidebarState {
  const factory SidebarState({
    @Default('layers') String viewId,
    @Default(true) bool isOpen,
    @Default(FanCadTokens.sidePanelWidth) double width,
  }) = _SidebarState;
}

@Riverpod(keepAlive: true)
class Sidebar extends _$Sidebar {
  ShellSettings get _shell => ref.read(appSettingsProvider).shell;

  static const double defaultWidth = FanCadTokens.sidePanelWidth;
  static const double minWidth = FanCadTokens.sidePanelMinWidth;
  static const double maxWidth = FanCadTokens.sidePanelMaxWidth;

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
  SidebarState build() {
    final shell = ref.watch(appSettingsProvider).shell;
    return SidebarState(
      viewId: _leftViewId(shell.sidebarView()),
      isOpen: shell.sidebarOpen(),
      width: shell.sidebarWidth(fallback: defaultWidth).clamp(minWidth, maxWidth),
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
    _shell
      ..setSidebarView(left)
      ..setSidebarOpen(true);
  }

  /// Brings a view forward without toggling, for `revealPanel`.
  void reveal(String viewId) {
    final left = _leftViewId(viewId);
    state = state.copyWith(viewId: left, isOpen: true);
    _shell
      ..setSidebarView(left)
      ..setSidebarOpen(true);
  }

  void setOpen(bool value) {
    state = state.copyWith(isOpen: value);
    _shell.setSidebarOpen(value);
  }

  void toggle() => setOpen(!state.isOpen);

  void resize(double width) {
    state = state.copyWith(
      width: width.roundToDouble().clamp(minWidth, maxWidth),
    );
  }

  /// Persisted on drag end rather than on every frame, to avoid writing the
  /// settings file sixty times a second.
  void commitWidth() => _shell.setSidebarWidth(state.width);

  /// Double-clicking the sash puts the pane back where it started, instead of
  /// hunting for a comfortable width after a drag went too far.
  void resetWidth() {
    state = state.copyWith(width: defaultWidth);
    commitWidth();
  }
}

/// Height of the command line pane, and whether the history is expanded.
@freezed
abstract class CommandPaneState with _$CommandPaneState {
  const factory CommandPaneState({
    @Default(84) double height,
    @Default(false) bool isExpanded,
  }) = _CommandPaneState;
}

@Riverpod(keepAlive: true)
class CommandPane extends _$CommandPane {
  ShellSettings get _shell => ref.read(appSettingsProvider).shell;

  /// Splitter plus the input row. History is given no pixels, so collapse
  /// looks like a single command line rather than a half-empty console.
  static const double collapsedHeight =
      FanCadTokens.splitterHit + FanCadTokens.commandLineHeight;

  /// Input plus two or three history lines — enough to read a prompt.
  static const double defaultHeight = 84;

  /// Tall enough to reread an import warning, short enough to keep the canvas.
  static const double expandedHeight = 200;

  static const double minHeight = collapsedHeight;
  static const double maxHeight = 420;

  @override
  CommandPaneState build() {
    return CommandPaneState(
      height: ref
          .watch(appSettingsProvider)
          .shell
          .commandPaneHeight(fallback: defaultHeight)
          .clamp(minHeight, maxHeight),
    );
  }

  void resize(double height) {
    state = state.copyWith(height: height.clamp(minHeight, maxHeight));
  }

  void commitHeight() => _shell.setCommandPaneHeight(state.height);

  void toggleExpanded() => state = state.copyWith(
    isExpanded: !state.isExpanded,
    height: state.isExpanded ? collapsedHeight : expandedHeight,
  );
}

/// The assistant chat, docked on the right so it can stay open next to Layers.
@freezed
abstract class AssistantPaneState with _$AssistantPaneState {
  const factory AssistantPaneState({
    @Default(false) bool isOpen,
    @Default(320) double width,
  }) = _AssistantPaneState;
}

@Riverpod(keepAlive: true)
class AssistantPane extends _$AssistantPane {
  ShellSettings get _shell => ref.read(appSettingsProvider).shell;

  static const double defaultWidth = 320;
  static const double minWidth = FanCadTokens.sidePanelMinWidth;
  static const double maxWidth = FanCadTokens.sidePanelMaxWidth;

  @override
  AssistantPaneState build() {
    final shell = ref.watch(appSettingsProvider).shell;
    return AssistantPaneState(
      isOpen: shell.assistantOpen(),
      width: shell
          .assistantWidth(fallback: defaultWidth)
          .clamp(minWidth, maxWidth),
    );
  }

  void setOpen(bool value) {
    state = state.copyWith(isOpen: value);
    _shell.setAssistantOpen(value);
  }

  void toggle() => setOpen(!state.isOpen);

  void resize(double width) {
    state = state.copyWith(
      width: width.roundToDouble().clamp(minWidth, maxWidth),
    );
  }

  void commitWidth() => _shell.setAssistantWidth(state.width);

  void resetWidth() {
    state = state.copyWith(width: defaultWidth);
    commitWidth();
  }
}

/// Whether the command palette overlay is showing.
@Riverpod(keepAlive: true)
class PaletteOpen extends _$PaletteOpen {
  @override
  bool build() => false;

  void setOpen(bool value) => state = value;

  void toggle() => state = !state;
}

/// The theme mode, persisted across launches.
@Riverpod(keepAlive: true)
class ThemeBrightness extends _$ThemeBrightness {
  ShellSettings get _shell => ref.read(appSettingsProvider).shell;

  @override
  Brightness build() {
    return ref.watch(appSettingsProvider).shell.themeBrightness() == 'light'
        ? Brightness.light
        : Brightness.dark;
  }

  void toggle() {
    setBrightness(
      state == Brightness.dark ? Brightness.light : Brightness.dark,
    );
  }

  void setBrightness(Brightness value) {
    if (state == value) return;
    state = value;
    _shell.setThemeBrightness(state.name);
  }
}

/// UI language. Stored as `en` / `zh`, matching OpenHare. Unknown leftovers
/// fall back to English so a corrupt settings file cannot blank the shell.
@Riverpod(keepAlive: true)
class Language extends _$Language {
  ShellSettings get _shell => ref.read(appSettingsProvider).shell;

  @override
  String build() {
    return FanCadLanguage.parse(
      ref.watch(appSettingsProvider).shell.language(
        fallback: FanCadLanguage.english,
      ),
    );
  }

  void setLanguage(String value) {
    final language = FanCadLanguage.parse(value);
    if (state == language) return;
    state = language;
    _shell.setLanguage(state);
  }
}
