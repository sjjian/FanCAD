import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditBlockCommand extends FanCadCommand {
  const EditBlockCommand();

  @override
  String get id => 'edit.block';
  @override
  String get title => 'Block';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['b', 'block'];
  @override
  String get description =>
      'Defines a named block from selected objects and replaces them '
      'with one insert at the base point, so the drawing looks the same '
      'and the definition can be inserted again.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(name: 'name', type: ParamType.text, description: 'Block name'),
    ParamSpec.point('base', description: 'Insertion base point'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection('ids', 'BLOCK  Select objects:');
    if (ids.isEmpty) return const CommandResult.cancelled();
    final name = (await context.resolveText(
      'name',
      'BLOCK  Enter block name:',
    )).trim();
    if (name.isEmpty) {
      return const CommandResult.failed('A block needs a name.');
    }
    if (name.startsWith('*')) {
      return const CommandResult.failed(
        'Block names that start with * are reserved.',
      );
    }
    final taken = context.document.blocks.keys.any(
      (existing) => existing.toUpperCase() == name.toUpperCase(),
    );
    if (taken) {
      return CommandResult.failed('A block named "$name" already exists.');
    }
    final base = await context.resolvePoint(
      'base',
      'BLOCK  Specify insertion base point:',
    );
    final space = context.document.currentBlockName;
    final members = <CadEntity>[];
    for (final id in ids) {
      if (context.document.ownerOf(id) != space) continue;
      final entity = context.document.entity(id);
      if (entity == null) continue;
      members.add(entity);
    }
    if (members.isEmpty) {
      return const CommandResult.failed(
        'None of the selected objects can be turned into a block.',
      );
    }
    final committed = context.edit('Block', (transaction) {
      transaction.putBlock(
        BlockRecord(name: name, basePoint: base, entityIds: const []),
      );
      for (final entity in members) {
        transaction
          ..add(entity.withId(0), blockName: name)
          ..erase(entity.id);
      }
      transaction.add(
        InsertEntity(
          id: 0,
          props: EntityProps(layer: context.document.currentLayer),
          blockName: name,
          position: base,
          attributes: {
            for (final entity in members)
              if (entity is AttdefEntity && entity.defaultValue.isNotEmpty)
                entity.tag: entity.defaultValue,
          },
        ),
      );
    });
    if (committed == null) {
      return const CommandResult.failed('The block was not created.');
    }
    final insertIds = [
      for (final id in committed.change.added)
        if (context.document.entity(id) is InsertEntity) id,
    ];
    context.selection.replace(insertIds);
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Block "$name": ${members.length} object(s) defined.',
      data: {'block': name, 'ids': insertIds},
      transaction: committed,
    );
  }
}
