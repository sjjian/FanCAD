import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../commands/builtins.dart';
import '../commands/file_commands.dart';
import '../commands/plugin_commands.dart';
import 'ai_controller.dart';
import 'plugin_delegate.dart';
import 'settings.dart';
import 'workspace.dart';

/// Riverpod wiring for the application.
///
/// Only the genuinely global things live here. Per-document state hangs off
/// [Workspace] rather than off providers, because a provider per tab would make
/// "which document is this?" a question with two answers, and every CAD bug
/// worth fearing starts that way.

/// Provided by the app at startup, after settings have been loaded from disk.
final settingsProvider = Provider<SettingsStore>(
  (ref) => throw StateError('settingsProvider must be overridden at startup'),
);

/// The on-disk FCB cache, or null when no cache directory is available.
///
/// Overridden at startup once the platform support directory is known, and left
/// null in tests so that a test run never touches a real cache.
final fcbCacheProvider = Provider<FcbCache?>((ref) => null);

/// The drawing importer. Overridden in tests with a stub backend.
final importerProvider = Provider<DrawingImporter>(
  (ref) => DrawingImporter(cache: ref.watch(fcbCacheProvider)),
);

final commandRegistryProvider = Provider<CommandRegistry>((ref) {
  final registry = CommandRegistry();
  ref.onDispose(registry.dispose);
  return registry;
});

/// The application state.
///
/// A plain [Provider] over a [ChangeNotifier] rather than a
/// `ChangeNotifierProvider`, because there must be exactly one owner of its
/// disposal and the registration below has to be torn down first. Widgets
/// subscribe with a `ListenableBuilder`, which also keeps rebuilds scoped to the
/// part of the shell that actually changed — during a drag the workspace
/// notifies dozens of times a second, and rebuilding the whole tree at that rate
/// is the difference between a smooth pan and a stuttering one.
final Provider<Workspace> workspaceProvider = Provider((ref) {
  final workspace = Workspace(
    commands: ref.watch(commandRegistryProvider),
    importer: ref.watch(importerProvider),
    settings: ref.watch(settingsProvider),
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
      recentFiles: () => workspace.settings.getStringList(
        SettingsKeys.recentFiles,
      ),
    ),
    pluginCommands: ref.watch(pluginCommandsProvider),
  );

  ref.onDispose(() {
    registration.dispose();
    workspace.dispose();
  });
  return workspace;
});

/// Where user extensions live. Overridden at startup with a real path, and left
/// empty in tests so that a test run never scans the user's real folder.
final pluginsDirectoryProvider = Provider<String>((ref) => '');

/// The extension host, or null when this session has no extensions folder.
///
/// Null rather than a host with nowhere to load from: it keeps a test run from
/// spawning a worker isolate, and it gives the extensions panel something
/// honest to say instead of showing an empty list that will never fill.
final Provider<PluginHost?> pluginHostProvider = Provider((ref) {
  if (ref.watch(pluginsDirectoryProvider).isEmpty) return null;
  final host = PluginHost(
    registry: ref.watch(commandRegistryProvider),
    delegate: ref.watch(pluginDelegateProvider),
    transport: ref.watch(pluginTransportProvider),
  );
  ref.onDispose(host.dispose);
  return host;
});

/// The transport plugins run over. Overridden in tests with [LocalTransport].
final pluginTransportProvider = Provider<PluginTransport>(
  (ref) => IsolateTransport(),
);

final Provider<WorkspacePluginDelegate> pluginDelegateProvider =
    Provider((ref) {
  return WorkspacePluginDelegate(
    workspace: () => ref.read(workspaceProvider),
    settings: ref.watch(settingsProvider),
  );
});

/// The assistant session. Created even when no key is configured so the panel
/// can explain how to set one up.
final Provider<AiController> aiControllerProvider = Provider((ref) {
  final controller = AiController(
    workspace: ref.watch(workspaceProvider),
    settings: ref.watch(settingsProvider),
    host: ref.watch(pluginHostProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// The extension management commands, or null when there is no plugins folder.
final Provider<PluginCommands?> pluginCommandsProvider = Provider((ref) {
  final directory = ref.watch(pluginsDirectoryProvider);
  final host = ref.watch(pluginHostProvider);
  if (directory.isEmpty || host == null) return null;
  return PluginCommands(host: host, pluginsDirectory: directory);
});

/// Which sidebar view is showing, and whether the sidebar is open at all.
class SidebarState {
  const SidebarState({
    this.viewId = 'layers',
    this.isOpen = true,
    this.width = 280,
  });

  final String viewId;
  final bool isOpen;
  final double width;

  SidebarState copyWith({String? viewId, bool? isOpen, double? width}) =>
      SidebarState(
        viewId: viewId ?? this.viewId,
        isOpen: isOpen ?? this.isOpen,
        width: width ?? this.width,
      );
}

class SidebarController extends StateNotifier<SidebarState> {
  SidebarController(this._settings)
    : super(
        SidebarState(
          viewId: _settings.getString(
            SettingsKeys.sidebarView,
            fallback: 'layers',
          ),
          isOpen: _settings.getBool(SettingsKeys.sidebarOpen, fallback: true),
          width: _settings.getDouble(SettingsKeys.sidebarWidth, fallback: 280),
        ),
      );

  final SettingsStore _settings;

  static const double minWidth = 200;
  static const double maxWidth = 560;

  /// Clicking the active icon collapses the sidebar, as VS Code does.
  void select(String viewId) {
    if (state.viewId == viewId && state.isOpen) {
      setOpen(false);
      return;
    }
    state = state.copyWith(viewId: viewId, isOpen: true);
    _settings
      ..set(SettingsKeys.sidebarView, viewId)
      ..set(SettingsKeys.sidebarOpen, true);
  }

  /// Brings a view forward without toggling, for `revealPanel`.
  void reveal(String viewId) {
    state = state.copyWith(viewId: viewId, isOpen: true);
    _settings
      ..set(SettingsKeys.sidebarView, viewId)
      ..set(SettingsKeys.sidebarOpen, true);
  }

  void setOpen(bool value) {
    state = state.copyWith(isOpen: value);
    _settings.set(SettingsKeys.sidebarOpen, value);
  }

  void toggle() => setOpen(!state.isOpen);

  void resize(double width) {
    state = state.copyWith(width: width.clamp(minWidth, maxWidth));
  }

  /// Persisted on drag end rather than on every frame, to avoid writing the
  /// settings file sixty times a second.
  void commitWidth() => _settings.set(SettingsKeys.sidebarWidth, state.width);
}

final sidebarProvider =
    StateNotifierProvider<SidebarController, SidebarState>(
  (ref) => SidebarController(ref.watch(settingsProvider)),
);

/// Height of the command line pane, and whether the history is expanded.
class CommandPaneState {
  const CommandPaneState({this.height = 132, this.isExpanded = false});

  final double height;
  final bool isExpanded;

  CommandPaneState copyWith({double? height, bool? isExpanded}) =>
      CommandPaneState(
        height: height ?? this.height,
        isExpanded: isExpanded ?? this.isExpanded,
      );
}

class CommandPaneController extends StateNotifier<CommandPaneState> {
  CommandPaneController(this._settings)
    : super(
        CommandPaneState(
          height: _settings.getDouble(
            SettingsKeys.commandPaneHeight,
            fallback: 132,
          ),
        ),
      );

  final SettingsStore _settings;

  static const double minHeight = 28;
  static const double maxHeight = 420;

  void resize(double height) {
    state = state.copyWith(height: height.clamp(minHeight, maxHeight));
  }

  void commitHeight() =>
      _settings.set(SettingsKeys.commandPaneHeight, state.height);

  void toggleExpanded() => state = state.copyWith(
    isExpanded: !state.isExpanded,
    height: state.isExpanded ? 132 : 320,
  );
}

final commandPaneProvider =
    StateNotifierProvider<CommandPaneController, CommandPaneState>(
  (ref) => CommandPaneController(ref.watch(settingsProvider)),
);

/// Whether the command palette overlay is showing.
final paletteOpenProvider = StateProvider<bool>((ref) => false);

/// The theme mode, persisted across launches.
class ThemeModeController extends StateNotifier<Brightness> {
  ThemeModeController(this._settings)
    : super(
        _settings.getString(SettingsKeys.themeBrightness, fallback: 'dark') ==
                'light'
            ? Brightness.light
            : Brightness.dark,
      );

  final SettingsStore _settings;

  void toggle() {
    setBrightness(
      state == Brightness.dark ? Brightness.light : Brightness.dark,
    );
  }

  void setBrightness(Brightness value) {
    if (state == value) return;
    state = value;
    _settings.set(SettingsKeys.themeBrightness, state.name);
  }
}

final themeBrightnessProvider =
    StateNotifierProvider<ThemeModeController, Brightness>(
  (ref) => ThemeModeController(ref.watch(settingsProvider)),
);
