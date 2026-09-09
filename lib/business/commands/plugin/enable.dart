import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsEnableCommand extends FanCadCommand {
  PluginsEnableCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.enable';
  @override
  String get title => 'Enable Extension';
  @override
  String get category => _category;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      _setEnabled(context, plugins, true);
}

class PluginsDisableCommand extends FanCadCommand {
  PluginsDisableCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.disable';
  @override
  String get title => 'Disable Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Unloads an extension and stops it activating again until enabled.';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) =>
      _setEnabled(context, plugins, false);
}

Future<CommandResult> _setEnabled(
  CommandContext context,
  PluginCommands plugins,
  bool enabled,
) async {
  final id = await context.resolveText('id', 'Extension id:');
  if (plugins.host.plugin(id) == null) {
    return CommandResult.failed('$id is not installed');
  }
  await plugins.host.setEnabled(id, enabled);
  return CommandResult.ok(
    message: '${enabled ? 'Enabled' : 'Disabled'} $id',
    data: {'id': id, 'enabled': enabled},
  );
}
