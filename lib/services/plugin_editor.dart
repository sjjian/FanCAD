import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/workspace.dart';

part 'plugin_editor.g.dart';

/// The built-in extension editor: which file to open, and a request counter so
/// a second edit of the same file still reloads it.
///
/// Global and independent of the workspace service. `plugins.edit` writes
/// here; the panel listens.
@Riverpod(keepAlive: true)
class PluginEditorNotifier extends _$PluginEditorNotifier {
  @override
  PluginEditorModel build() => const PluginEditorModel();

  PluginEditorTargetModel? get target => state.target;
  int get request => state.request;

  void open(String id, String relative) {
    state = state.copyWith(
      target: PluginEditorTargetModel(id: id, relative: relative),
      request: state.request + 1,
    );
  }
}

/// The extension editor. Prefer [PluginEditorNotifier] at new call sites.
typedef PluginEditorController = PluginEditorNotifier;
