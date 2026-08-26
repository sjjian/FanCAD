import 'dart:async';

import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'providers.dart';

part 'plugin_bootstrap.g.dart';

/// Brings the extension host up after the shell is on screen.
///
/// Deliberately not part of application startup. Spawning the worker isolate
/// and reading plugin folders is work that third-party code influences, and
/// none of it should sit between the user launching the application and seeing
/// a window.
class PluginBootstrap {
  PluginBootstrap({required this.ref, required this.bundledDirectories});

  final Ref ref;

  /// Read-only folders shipped with the application, scanned before user
  /// extensions so a user plugin can shadow a bundled one by id.
  final List<String> bundledDirectories;

  PluginWatcher? _watcher;
  bool _started = false;

  bool get isStarted => _started;

  Future<void> start() async {
    if (_started) return;
    final host = ref.read(pluginHostProvider);
    if (host == null) return;
    _started = true;

    await host.start();

    for (final directory in bundledDirectories) {
      await host.discover(directory);
    }
    final userDirectory = ref.read(pluginsDirectoryProvider);
    if (userDirectory.isNotEmpty) {
      await host.discover(userDirectory);
      // Watching only the user folder: reloading a bundled extension on a file
      // change would be reacting to an installer, not to an author.
      final watcher = PluginWatcher(host: host);
      _watcher = watcher;
      await watcher.watch(userDirectory);
    }

    await host.activateStartupPlugins();
    _forwardDocumentEvents(host);
  }

  /// Bridges workspace activity to plugin event handlers.
  ///
  /// Events are notifications, so a plugin that is slow to handle one cannot
  /// delay the edit that produced it.
  void _forwardDocumentEvents(PluginHost host) {
    final workspace = ref.read(workspaceProvider);
    workspace.addListener(() {
      final session = workspace.active?.session;
      if (session == null) return;
      if (identical(session, _watchedSession)) return;
      _watchedSession = session;
      _sessionSubscriptions
        ..forEach((subscription) => subscription.cancel())
        ..clear();
      _sessionSubscriptions.add(
        session.transactions.listen(
          (transaction) => host.broadcast('document.changed', {
            'label': transaction.label,
            'source': transaction.source.name,
            'added': transaction.change.added,
            'removed': transaction.change.removed,
            'modified': transaction.change.modified,
          }),
        ),
      );
      host.broadcast('document.opened', {
        'title': session.title,
        'path': session.filePath,
      });
    });
  }

  Object? _watchedSession;
  final List<StreamSubscription<void>> _sessionSubscriptions = [];

  Future<void> dispose() async {
    for (final subscription in _sessionSubscriptions) {
      await subscription.cancel();
    }
    _sessionSubscriptions.clear();
    await _watcher?.dispose();
    _watcher = null;
  }
}

/// Owns the bootstrap for the application's lifetime.
@Riverpod(keepAlive: true)
PluginBootstrap pluginBootstrap(Ref ref) {
  final bootstrap = PluginBootstrap(
    ref: ref,
    bundledDirectories: ref.watch(bundledPluginDirectoriesProvider),
  );
  ref.onDispose(bootstrap.dispose);
  return bootstrap;
}

/// Folders of extensions shipped with the application.
@Riverpod(keepAlive: true)
List<String> bundledPluginDirectories(Ref ref) =>
    const [];
