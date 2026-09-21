import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsReloadCommand extends FanCadCommand {
  PluginsReloadCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.reload';
  @override
  String get title => 'Reload Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Re-reads an extension from disk and re-evaluates it, picking up '
      'both code and manifest changes without restarting.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'id',
      type: ParamType.text,
      description: 'The extension id. Omit to reload every extension.',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final host = plugins.host;
    final id = context.args.text('id');
    final targets = id == null || id.isEmpty
        ? [for (final handle in host.plugins) handle.id]
        : [id];
    if (targets.isEmpty) {
      return const CommandResult.failed('No extensions to reload');
    }
    final reloaded = <String>[];
    final failed = <String, String>{};
    for (final target in targets) {
      if (host.plugin(target) == null) {
        failed[target] = 'not installed';
        continue;
      }
      final handle = await host.reload(target);
      if (handle == null || handle.state == PluginState.failed) {
        failed[target] = handle?.error ?? 'reload failed';
      } else {
        reloaded.add(target);
      }
    }
    for (final entry in failed.entries) {
      context.input.write('${entry.key}: ${entry.value}');
    }
    return CommandResult.ok(
      message: failed.isEmpty
          ? 'Reloaded ${reloaded.join(', ')}'
          : 'Reloaded ${reloaded.length}, failed ${failed.length}',
      data: {'reloaded': reloaded, 'failed': failed},
    );
  }
}
