import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
import 'commands.dart';
import 'helpers.dart';

const _category = 'Extensions';

class PluginsScaffoldCommand extends FanCadCommand {
  PluginsScaffoldCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.scaffold';
  @override
  String get title => 'Create Extension';
  @override
  String get category => _category;
  @override
  String get description =>
      'Writes a new extension folder with a manifest and a working '
      'main.js, then loads it. Returns the paths written.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'id',
      type: ParamType.text,
      description: 'Extension id, conventionally publisher.name',
    ),
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Display name',
      required: false,
    ),
    ParamSpec(name: 'description', type: ParamType.text, required: false),
    ParamSpec(
      name: 'source',
      type: ParamType.text,
      description: 'The JavaScript for main.js. A sample is used if empty.',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    if (id.isEmpty) return const CommandResult.failed('An id is required');
    if (plugins.host.plugin(id) != null) {
      return CommandResult.failed('$id is already installed');
    }
    if (!isSafeSegment(id)) {
      return CommandResult.failed(
        'An extension id may only contain letters, digits, dots, dashes and '
        'underscores: "$id"',
      );
    }

    final manifest = await PluginHost.scaffold(
      root: plugins.pluginsDirectory,
      id: id,
      name: context.args.text('name') ?? id,
      description: context.args.text('description') ?? '',
      source: context.args.text('source'),
    );
    final handle = await plugins.host.install(manifest.directory);
    if (handle == null) {
      return CommandResult.failed('Wrote $id but could not install it');
    }
    await plugins.host.activate(id);
    final refreshed = plugins.host.plugin(id)!;
    return CommandResult.ok(
      message: 'Created $id in ${manifest.directory}',
      data: {
        'id': id,
        'directory': manifest.directory,
        'manifest': p.join(manifest.directory, PluginManifest.fileName),
        'entryPoint': p.join(manifest.directory, manifest.entryPoint),
        'state': refreshed.state.name,
        if (refreshed.error != null) 'error': refreshed.error,
        'log': refreshed.log,
      },
    );
  }
}
