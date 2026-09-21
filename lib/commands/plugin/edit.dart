import 'package:fancad_core/fancad_core.dart';
import 'package:path/path.dart' as p;

import '../command_base.dart';
import 'commands.dart';
import 'helpers.dart';

const _category = 'Extensions';

class PluginsEditCommand extends FanCadCommand {
  PluginsEditCommand(this.plugins);

  final PluginCommands plugins;

  @override
  String get id => 'plugins.edit';
  @override
  String get title => 'Edit Extension File';
  @override
  String get category => _category;
  @override
  String get description =>
      'Opens an extension file in the built-in editor so a person can '
      'review or change what the AI authoring loop wrote.';
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'id', type: ParamType.text),
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      description: 'Relative path inside the extension, e.g. main.js',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final id = await context.resolveText(
      'id',
      context.l10n.prompt_extension_id,
    );
    final handle = plugins.host.plugin(id);
    if (handle == null) return CommandResult.failed('$id is not installed');
    final relative = context.args.text('path') ?? handle.manifest.entryPoint;
    final file = resolveInside(handle.manifest.directory, relative);
    if (file == null) {
      return CommandResult.failed(
        'Refusing to open a path outside the extension folder: "$relative"',
      );
    }
    final relativePath = p.normalize(relative);
    plugins.openEditor?.call(id, relativePath);
    context.services.revealPanel('editor');
    return CommandResult.ok(
      message:
          'Editing ${p.relative(file.path, from: handle.manifest.directory)}',
      data: {'id': id, 'path': file.path, 'relative': relative},
    );
  }
}
