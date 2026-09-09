import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'commands.dart';

const _category = 'File';

class FileActivateCommand extends FanCadCommand {
  const FileActivateCommand(this.files);

  final FileCommands files;

  @override
  String get id => 'file.activate';
  @override
  String get title => 'Activate Drawing';
  @override
  String get category => _category;
  @override
  String get description =>
      'Brings an open drawing to the front. Pass id from file.list, or a '
      'unique path or title.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'id',
      type: ParamType.text,
      required: false,
      description: 'Session id from file.list',
    ),
    ParamSpec(
      name: 'path',
      type: ParamType.text,
      required: false,
      description: 'File path of an open drawing',
    ),
    ParamSpec(
      name: 'title',
      type: ParamType.text,
      required: false,
      description: 'Tab title; must be unique',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final selector = _activateSelector(context.args);
    if (selector.isEmpty) {
      return const CommandResult.failed(
        'file.activate needs id, path, or title. Call file.list first.',
      );
    }
    final activate = files.activateDrawing;
    if (activate == null) {
      return const CommandResult.failed('file.activate is not available.');
    }
    final error = activate(selector);
    if (error != null) return CommandResult.failed(error);
    return CommandResult.ok(message: 'Activated $selector.');
  }
}

String _activateSelector(CommandArgs args) {
  for (final name in const ['id', 'path', 'title']) {
    final value = args.text(name)?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return '';
}
