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
    // `value` stays the first text parameter. A prompt takes the next unused
    // text argument, so a supplied `tag` would otherwise become the new value
    // and the command line would never ask.
    ParamSpec(
      name: 'value',
      type: ParamType.text,
      description: 'New value for that tag',
      required: false,
    ),
    ParamSpec(
      name: 'tag',
      type: ParamType.text,
      description: 'Attribute tag to change',
      required: false,
    ),
    ParamSpec(
      name: 'values',
      type: ParamType.json,
      description: 'Tag to new value, applied in one undo',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      context.commandPrompt(
        'ATTEDIT',
        context.l10n.prompt_select_block_reference,
      ),
    );
    final inserts = [
      for (final id in ids)
        if (context.document.entity(id) is InsertEntity)
          context.document.entity(id)! as InsertEntity,
    ];
    if (inserts.isEmpty) {
      return const CommandResult.failed('ATTEDIT needs a block reference.');
    }
    final supplied = _stringMap(context.args['values']);
    final tag = context.args.text('tag')?.trim();
    final hasValue = context.args.has('value');
    final value = context.args.text('value');
    final updates = <InsertEntity>[];
    var sawEditable = false;
    for (final insert in inserts) {
      final editable = [
        for (final def in context.document.attdefsOf(insert.blockName))
          if (!def.constant) def,
      ];
      if (editable.isEmpty) continue;
      sawEditable = true;
      final next = Map<String, String>.from(insert.attributes);
      if (supplied != null) {
        for (final entry in supplied.entries) {
          final def = _definitionFor(editable, entry.key);
          if (def == null) continue;
          next[def.tag] = entry.value;
        }
      } else if (tag != null && tag.isNotEmpty) {
        final def = _definitionFor(editable, tag);
        if (def == null) continue;
        next[def.tag] = hasValue
            ? (value ?? '')
            : await context.resolveText(
                'value',
                _prompt(def),
                defaultValue: insert.attributeValue(def.tag, def.defaultValue),
              );
      } else {
        for (final def in editable) {
          next[def.tag] = await context.input.text(
            _prompt(def),
            defaultValue: insert.attributeValue(def.tag, def.defaultValue),
          );
        }
      }
      if (_attributesChanged(insert.attributes, next)) {
        updates.add(insert.withAttributes(next));
      }
    }
    if (updates.isEmpty) {
      return CommandResult.failed(
        sawEditable ? 'Nothing changed.' : 'That block has no attributes.',
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

String _prompt(AttdefEntity def) =>
    'ATTEDIT  ${def.prompt.isEmpty ? def.tag : def.prompt}:';

AttdefEntity? _definitionFor(List<AttdefEntity> defs, String tag) {
  final key = tag.toUpperCase();
  for (final def in defs) {
    if (def.tag.toUpperCase() == key) return def;
  }
  return null;
}

/// `CommandArgs.object` rejects `Map<String, String>`, so read the raw map.
Map<String, String>? _stringMap(Object? raw) {
  if (raw is! Map) return null;
  return {
    for (final entry in raw.entries)
      if (entry.value != null) entry.key.toString(): entry.value.toString(),
  };
}

bool _attributesChanged(Map<String, String> before, Map<String, String> after) {
  if (before.length != after.length) return true;
  for (final entry in after.entries) {
    if (before[entry.key] != entry.value) return true;
  }
  return false;
}
