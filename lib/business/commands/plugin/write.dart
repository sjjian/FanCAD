import 'package:fancad_core/fancad_core.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
import 'commands.dart';
import 'helpers.dart';

const _category = 'Extensions';

class PluginsWriteCommand extends FanCadCommand {
  PluginsWriteCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.write';
  @override
  String get title => 'Write Extension File';
  @override
  String get category => _category;
  @override
  String get description =>
      'Overwrites one file inside an extension folder. Paths are confined '
      'to that folder.';
  @override
  CommandRisk get risk => CommandRisk.destructive;
  @override
  AiExposure get aiExposure => AiExposure.approvalRequired;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'Relative path inside the extension, e.g. main.js',
    ),
    ParamSpec(name: 'content', type: ParamType.text),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText('id', 'Extension id:');
    final handle = plugins.host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final directory = handle.manifest.directory;
    if (directory.isEmpty) {
      return CommandResult.failed('$id has no folder on disk');
    }

    final relative = await context.resolveText('path', 'File to write:');
    final file = resolveInside(directory, relative);
    if (file == null) {
      return CommandResult.failed(
        'Refusing to write outside the extension folder: "$relative"',
      );
    }

    final content = context.args.text('content') ?? '';
    await file.parent.create(recursive: true);
    await file.writeAsString(content);

    // Reloading here is the point: the caller wants the change to take effect,
    // and a write that leaves the old code running is a trap.
    final reloaded = await plugins.host.reload(id);
    return CommandResult.ok(
      message:
          'Wrote ${p.relative(file.path, from: directory)} and reloaded $id',
      data: {
        'path': file.path,
        'bytes': content.length,
        'state': reloaded?.state.name ?? 'unknown',
        if (reloaded?.error != null) 'error': reloaded!.error,
        'log': reloaded?.log ?? const <String>[],
      },
    );
  }
}
