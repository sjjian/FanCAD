import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'manifest.dart';
import 'plugin_host.dart';

/// Watches plugin folders and reloads on change.
///
/// The debounce is not cosmetic. An editor writing a file produces several
/// filesystem events, and a save that lands mid-write would be evaluated as
/// truncated JavaScript, so the reload waits for the writes to stop.
class PluginWatcher {
  PluginWatcher({
    required this.host,
    this.debounce = const Duration(milliseconds: 250),
  });

  final PluginHost host;
  final Duration debounce;

  final Map<String, StreamSubscription<FileSystemEvent>> _watches = {};
  final Map<String, Timer> _timers = {};
  final StreamController<String> _reloads =
      StreamController<String>.broadcast();

  /// Fires with a plugin id after each successful reload.
  Stream<String> get reloads => _reloads.stream;

  bool get isWatching => _watches.isNotEmpty;

  /// Watches [root] for changes to any plugin folder inside it.
  ///
  /// Watching the root rather than each plugin means a folder added after
  /// startup is picked up too, which is what the AI authoring loop needs: it
  /// writes a new plugin and expects it to appear.
  Future<void> watch(String root) async {
    if (_watches.containsKey(root)) return;
    final directory = Directory(root);
    if (!directory.existsSync()) await directory.create(recursive: true);
    _watches[root] = directory
        .watch(recursive: true)
        .listen((event) => _schedule(root, event.path));
  }

  void _schedule(String root, String changedPath) {
    final pluginId = _owningPlugin(root, changedPath);
    if (pluginId == null) return;
    _timers[pluginId]?.cancel();
    _timers[pluginId] = Timer(debounce, () => _reload(root, pluginId));
  }

  /// Maps a changed file back to the plugin folder that contains it.
  String? _owningPlugin(String root, String changedPath) {
    final relative = p.relative(changedPath, from: root);
    if (relative.startsWith('..')) return null;
    final segments = p.split(relative);
    if (segments.isEmpty) return null;
    final folder = segments.first;
    if (folder.isEmpty || folder.startsWith('.')) return null;
    // Only source and manifest changes matter; a plugin writing to its own
    // storage must not reload itself into a loop.
    final extension = p.extension(changedPath);
    final isRelevant = extension == '.js' ||
        extension == '.mjs' ||
        p.basename(changedPath) == PluginManifest.fileName;
    return isRelevant ? folder : null;
  }

  Future<void> _reload(String root, String folder) async {
    _timers.remove(folder);
    final directory = p.join(root, folder);
    final manifestFile = File(p.join(directory, PluginManifest.fileName));
    if (!manifestFile.existsSync()) {
      // The folder went away, so retire whatever it had contributed.
      final existing = host.plugins.firstWhere(
        (candidate) => candidate.manifest.directory == directory,
        orElse: () => PluginHandle(
          manifest: const PluginManifest(
            id: '',
            name: '',
            version: '',
            entryPoint: '',
          ),
          state: PluginState.failed,
        ),
      );
      if (existing.id.isNotEmpty) await host.uninstall(existing.id);
      return;
    }

    final existing = host.plugins
        .where((candidate) => candidate.manifest.directory == directory)
        .toList();
    if (existing.isEmpty) {
      final installed = await host.install(directory);
      if (installed != null) {
        await host.activate(installed.id);
        if (!_reloads.isClosed) _reloads.add(installed.id);
      }
      return;
    }
    final reloaded = await host.reload(existing.first.id);
    if (reloaded != null && !_reloads.isClosed) _reloads.add(reloaded.id);
  }

  Future<void> dispose() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final subscription in _watches.values) {
      await subscription.cancel();
    }
    _watches.clear();
    await _reloads.close();
  }
}
