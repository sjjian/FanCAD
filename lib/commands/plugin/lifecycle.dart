import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_extension/fancad_extension.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsStartCommand extends FanCadCommand {
  PluginsStartCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.start';
  @override
  String get title => 'Start Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Loads an enabled extension. A disabled extension has to be enabled first.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', context.l10n.prompt_extension_id);
    final handle = plugins.manager.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    if (handle.state == PluginState.disabled) {
      return CommandResult.failed('$id is disabled');
    }
    final started = await plugins.manager.activate(id);
    if (!started) {
      return CommandResult.failed(handle.error ?? 'could not start $id');
    }
    return CommandResult.ok(message: 'Started $id', data: {'id': id});
  }
}

class PluginsStopCommand extends FanCadCommand {
  PluginsStopCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.stop';
  @override
  String get title => 'Stop Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Unloads an extension and leaves its commands and panels registered.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', context.l10n.prompt_extension_id);
    final handle = plugins.manager.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    if (handle.state == PluginState.disabled) {
      return CommandResult.failed('$id is disabled');
    }
    await plugins.manager.deactivate(id);
    return CommandResult.ok(message: 'Stopped $id', data: {'id': id});
  }
}
