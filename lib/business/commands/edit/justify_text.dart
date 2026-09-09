import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditJustifyTextCommand extends FanCadCommand {
  const EditJustifyTextCommand();

  @override
  String get id => 'edit.justifyText';
  @override
  String get title => 'Justify Text';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['justifytext', 'justify'];
  @override
  String get description =>
      'Changes the justification of selected text or mtext and moves the '
      'insertion point so the letters stay where they are. Align and Fit '
      'are not offered; they need a second point.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'justify',
      type: ParamType.text,
      description: 'Left, Center, Right, TL, TC, TR, ML, MC, MR, BL, BC, BR',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'JUSTIFYTEXT  Select text objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final targets = <CadEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final CadEntity entity)
          if (entity is TextEntity || entity is MTextEntity) entity,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed('Select text or mtext to justify.');
    }
    final justify = (await context.resolveText(
      'justify',
      'JUSTIFYTEXT  Enter justification [Left/Center/Right/TL/TC/TR/ML/MC/MR/BL/BC/BR]:',
    )).trim();
    if (justify.isEmpty) {
      return const CommandResult.failed('JUSTIFYTEXT needs a justification.');
    }
    final key = justify.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    if (const {'a', 'align', 'aligned', 'f', 'fit'}.contains(key)) {
      return const CommandResult.failed(
        'Align and Fit need two points. Use Left, Center, Right or a '
        'corner code such as TL.',
      );
    }
    if (Construct.parseTextJustify(
          justify,
          currentH: TextHAlign.left,
          currentV: TextVAlign.baseline,
        ) ==
        null) {
      return CommandResult.failed(
        '"$justify" is not a justification. Use Left, Center, Right, '
        'TL, TC, TR, ML, MC, MR, BL, BC or BR.',
      );
    }
    final committed = context.edit('Justify Text', (transaction) {
      for (final entity in targets) {
        final updated = switch (entity) {
          TextEntity() => Construct.justifyText(entity, justify),
          MTextEntity() => Construct.justifyMText(entity, justify),
          _ => null,
        };
        if (updated == null || updated == entity) continue;
        transaction.modify(updated);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the text already has that justification, or '
        'the objects are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Changed justification on ${committed.change.modified.length} '
          'text object(s).',
      transaction: committed,
    );
  }
}
