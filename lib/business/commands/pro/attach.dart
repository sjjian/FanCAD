import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_io/fancad_io.dart';

import '../command_base.dart';

const _category = 'Output';

class XrefAttachCommand extends FanCadCommand {
  const XrefAttachCommand();

  @override
  String get id => 'xref.attach';
  @override
  String get title => 'Attach Xref';
  @override
  String get category => _category;
  @override
  String get description =>
      'Loads another drawing as an external reference and places it in '
      'model space. Reload by attaching the same path again; existing '
      'inserts keep their position.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'path', type: ParamType.text),
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      required: false,
      description: 'Block name. Defaults to the file stem.',
    ),
    ParamSpec(
      name: 'at',
      type: ParamType.point,
      required: false,
      description: 'Insertion point. Defaults to the origin.',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final path = await context.resolveText('path', 'Drawing to attach:');
    final imported = await DrawingImporter().open(path);
    final at = context.args.point('at') ?? const Vec2.zero();
    late String name;
    final committed = context.edit('Attach xref', (transaction) {
      name = const XrefResolver().attach(
        host: context.document,
        foreign: imported.document,
        path: path,
        blockName: context.args.text('name'),
        at: at,
        transaction: transaction,
      );
    });
    if (committed == null) {
      return const CommandResult.failed('The xref was not attached.');
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Attached $name from $path '
          '(${imported.entityCount} entities).',
      data: {
        'block': name,
        'entities': imported.entityCount,
        'at': [at.x, at.y],
      },
      transaction: committed,
    );
  }
}
