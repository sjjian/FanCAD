import 'dart:io';

import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
import 'commands.dart';

const _category = 'Extensions';

class PluginsTypingsCommand extends FanCadCommand {
  PluginsTypingsCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.typings';
  @override
  String get title => 'Write Plugin API Typings';
  @override
  String get category => _category;
  @override
  String get description =>
      'Regenerates fancad.d.ts from the live command registry, so editors '
      'and models see the real API surface.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'Where to write it. Defaults to the extensions folder.',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final host = plugins.host;
    final target = context.args.text('path')?.trim();
    final path = target == null || target.isEmpty
        ? p.join(plugins.pluginsDirectory, 'fancad.d.ts')
        : target;
    final output = buildTypeDeclarations(
      commands: host.registry.all,
      hostVersion: host.hostVersion,
    );
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(output);
    return CommandResult.ok(
      message: 'Wrote ${host.registry.length} command declarations to $path',
      data: {
        'path': path,
        'commands': host.registry.length,
        'characters': output.length,
      },
    );
  }
}
