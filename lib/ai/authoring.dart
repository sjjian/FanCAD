import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';

/// Helpers for the "write a plugin and run it" loop.
///
/// The loop itself is three commands already in the registry —
/// `plugins.scaffold`, `plugins.write`, `plugins.reload` — plus the typings
/// command. This class injects the live `fancad.d.ts` into the model's
/// context and turns an activation error into a repair prompt.
class PluginAuthoring implements ActivationRepair {
  const PluginAuthoring();

  /// Commands the model uses to create and iterate on an extension.
  static const List<String> commandIds = [
    'plugins.scaffold',
    'plugins.write',
    'plugins.read',
    'plugins.reload',
    'plugins.typings',
    'plugins.logs',
    'plugins.list',
    'reEditor.open',
  ];

  @override
  String repairPrompt({
    required String pluginId,
    required String error,
    String? source,
    String? typings,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Extension $pluginId failed to load. Fix the source and write it back '
      'with plugins.write, then plugins.reload.',
    );
    buffer.writeln('Error:');
    buffer.writeln(error);
    if (source != null && source.isNotEmpty) {
      buffer.writeln('Current main.js:');
      buffer.writeln(source);
    }
    if (typings != null && typings.isNotEmpty) {
      buffer.writeln('The fancad API the host actually implements:');
      buffer.writeln(typings);
    }
    return buffer.toString();
  }

  @override
  bool isActivationFailure(CommandResult result) {
    if (!result.isFailed && result.isOk) {
      final state = result.data?['state'];
      if (state == 'failed' || state == 'disabled') return true;
      if (result.data?['error'] is String) return true;
    }
    return result.isFailed &&
        (result.message.contains('activate') ||
            result.message.contains('eval') ||
            result.message.contains('SyntaxError') ||
            result.message.contains('ReferenceError'));
  }
}
