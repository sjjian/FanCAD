import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class SandboxQueryCommand extends FanCadCommand {
  SandboxQueryCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'sandbox.query';
  @override
  String get title => 'Query In Sandbox';
  @override
  String get category => _category;
  @override
  String get description =>
      'Runs a read-only script in a disposable sandbox. It can read the '
      'drawing and run read-only commands. It cannot edit or open a panel.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  AiExposure get aiExposure => AiExposure.hostOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'source',
      type: ParamType.text,
      description: 'JavaScript source',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final source = await context.resolveText('source', 'Script:');
    final scratch = plugins.scratch;
    if (scratch == null) {
      return const CommandResult.failed('sandbox is unavailable');
    }
    return scratch(source, write: false);
  }
}

class SandboxRunCommand extends FanCadCommand {
  SandboxRunCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'sandbox.run';
  @override
  String get title => 'Run In Sandbox';
  @override
  String get category => _category;
  @override
  String get description =>
      'Runs a script in a disposable sandbox. It may edit the drawing, run '
      'commands, and open one dialog. It cannot register a panel.';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.hostOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'source',
      type: ParamType.text,
      description: 'JavaScript source',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final source = await context.resolveText('source', 'Script:');
    final scratch = plugins.scratch;
    if (scratch == null) {
      return const CommandResult.failed('sandbox is unavailable');
    }
    return scratch(source, write: true);
  }
}
