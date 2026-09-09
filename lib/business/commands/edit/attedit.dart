import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditAtteditCommand extends FanCadCommand {
  const EditAtteditCommand();

  @override
  String get id => 'edit.attedit';
  @override
  String get title => 'Edit Attributes';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['attedit', 'eattedit'];
  @override
  String get description =>
      'Changes the values on a block reference. Constant tags stay as '
      'the definition wrote them.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'tag',
      type: ParamType.text,
      description: 'Attribute tag to change',
      required: false,
    ),
    ParamSpec(
      name: 'value',
      type: ParamType.text,
      description: 'New value for that tag',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'ATTEDIT  Select a block reference:',
    );
    final inserts = [
      for (final id in ids)
        if (context.document.entity(id) is InsertEntity)
          context.document.entity(id)! as InsertEntity,
    ];
    if (inserts.isEmpty) {
      return const CommandResult.failed('ATTEDIT needs a block reference.');
    }
    final tag = context.args.text('tag')?.trim();
    final value = context.args.text('value');
    final updates = <InsertEntity>[];
    for (final insert in inserts) {
      final defs = context.document.attdefsOf(insert.blockName);
      if (defs.isEmpty) continue;
      final next = Map<String, String>.from(insert.attributes);
      if (tag != null && tag.isNotEmpty) {
        AttdefEntity? def;
        for (final each in defs) {
          if (each.tag.toUpperCase() == tag.toUpperCase()) def = each;
        }
        if (def == null || def.constant) continue;
        next[def.tag] =
            value ??
            await context.input.text(
              'ATTEDIT  ${def.prompt.isEmpty ? def.tag : def.prompt}:',
              defaultValue: insert.attributeValue(def.tag, def.defaultValue),
            );
      } else {
        for (final def in defs) {
          if (def.constant) continue;
          next[def.tag] = await context.input.text(
            'ATTEDIT  ${def.prompt.isEmpty ? def.tag : def.prompt}:',
            defaultValue: insert.attributeValue(def.tag, def.defaultValue),
          );
        }
      }
      var changed = next.length != insert.attributes.length;
      if (!changed) {
        for (final entry in next.entries) {
          if (insert.attributes[entry.key] != entry.value) {
            changed = true;
            break;
          }
        }
      }
      if (changed) updates.add(insert.withAttributes(next));
    }
    if (updates.isEmpty) {
      return const CommandResult.failed(
        'Nothing changed, or that block has no attributes.',
      );
    }
    final written = context.edit('Attedit', (transaction) {
      for (final insert in updates) {
        transaction.modify(insert);
      }
    });
    if (written == null) {
      return const CommandResult.failed(
        'The attributes were not changed; the objects may be on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Edited attributes on ${written.change.modified.length} insert(s).',
      transaction: written,
    );
  }
}
