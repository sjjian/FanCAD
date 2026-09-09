import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsEvalCommand extends FanCadCommand {
  PluginsEvalCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.eval';
  @override
  String get title => 'Evaluate In Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Runs a JavaScript expression inside an extension scope. For '
      'debugging; it can do anything the extension can.';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
    ParamSpec(name: 'source', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final source = await context.resolveText('source', 'JavaScript:');
    if (plugins.host.plugin(id) == null) {
      return CommandResult.failed('$id is not installed');
    }
    try {
      final value = await plugins.host.evaluate(id, source);
      context.input.write('$value');
      return CommandResult.ok(message: '$value', data: {'value': value});
    } on RpcException catch (error) {
      return CommandResult.failed(error.message);
    } on StateError catch (error) {
      return CommandResult.failed(error.message);
    }
  }
}
