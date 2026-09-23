import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/app_settings.dart';
import '../storage/settings.dart';

part 'providers.g.dart';

/// Riverpod wiring for the application.
///
/// Leaf stores live here. Each module Notifier is in its own file; screens
/// subscribe with `select`, not a second provider tree.

/// Provided by the app at startup, after settings have been loaded from disk.
@Riverpod(keepAlive: true)
SettingsStore settings(Ref ref) =>
    throw StateError('settingsProvider must be overridden at startup');

/// Service-internal bag. Screen watches typed providers, not this.
@Riverpod(keepAlive: true)
AppSettings appSettings(Ref ref) => AppSettings(ref.watch(settingsProvider));

/// Drawing file access. Overridden in tests with an in-memory DWG adapter.
@Riverpod(keepAlive: true)
DrawingFileService drawingFiles(Ref ref) => DrawingFileService();

@Riverpod(keepAlive: true)
CommandRegistry commandRegistry(Ref ref) {
  final registry = CommandRegistry();
  ref.onDispose(registry.dispose);
  return registry;
}

/// Where user extensions live. Overridden at startup with a real path, and left
/// empty in tests so that a test run never scans the user's real folder.
@Riverpod(keepAlive: true)
String pluginsDirectory(Ref ref) => '';

/// The transport plugins run over. Overridden in tests with [LocalTransport].
@Riverpod(keepAlive: true)
PluginTransport pluginTransport(Ref ref) => IsolateTransport();
