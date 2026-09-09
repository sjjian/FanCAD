import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditTextContentCommand extends FanCadCommand {
  const EditTextContentCommand();

  @override
  String get id => 'edit.textContent';
  @override
  String get title => 'Edit Text';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ddedit', 'ted'];
  @override
  String get description =>
      'Changes the content of selected text, mtext or dimensions. On a '
      'dimension, empty restores the measured value and <> stands for '
      'that value, same as DIMEDIT.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'text',
      type: ParamType.text,
      description: 'New content, or dimension override',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'DDEDIT  Select text, mtext or a dimension:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final targets = <CadEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final CadEntity entity)
          if (entity is TextEntity ||
              entity is MTextEntity ||
              entity is DimensionEntity)
            entity,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed(
        'Select text, mtext or a dimension to edit.',
      );
    }

    final current = switch (targets.first) {
      TextEntity(:final content) => content,
      MTextEntity(:final content) => content,
      DimensionEntity(:final overrideText) => overrideText,
      AttdefEntity(:final defaultValue) => defaultValue,
      AttribEntity(:final value) => value,
      _ => '',
    };
    final text = context.args.has('text')
        ? (context.args.text('text') ?? '')
        : await context.input.text(
            'DDEDIT  Enter new text:',
            defaultValue: current,
          );
    final needsContent = targets.any(
      (entity) => entity is TextEntity || entity is MTextEntity,
    );
    if (needsContent && text.isEmpty) {
      return const CommandResult.failed('Text cannot be empty.');
    }

    final committed = context.edit('Edit Text', (transaction) {
      for (final entity in targets) {
        final updated = switch (entity) {
          TextEntity() when entity.content != text => entity.withContent(text),
          MTextEntity() when entity.content != text => entity.withContent(text),
          AttdefEntity() when entity.defaultValue != text => AttdefEntity(
            id: entity.id,
            props: entity.props,
            position: entity.position,
            tag: entity.tag,
            prompt: entity.prompt,
            defaultValue: text,
            height: entity.height,
            rotation: entity.rotation,
            styleName: entity.styleName,
            widthFactor: entity.widthFactor,
            obliqueAngle: entity.obliqueAngle,
            hAlign: entity.hAlign,
            vAlign: entity.vAlign,
            invisible: entity.invisible,
            constant: entity.constant,
            verify: entity.verify,
            preset: entity.preset,
          ),
          AttribEntity() when entity.value != text => entity.withValue(text),
          DimensionEntity() when entity.overrideText != text => DimensionEntity(
            id: entity.id,
            props: entity.props,
            definitionPoints: entity.definitionPoints,
            textPosition: entity.textPosition,
            measurement: entity.measurement,
            overrideText: text,
            styleName: entity.styleName,
            dimensionType: entity.dimensionType,
          ),
          _ => null,
        };
        if (updated != null) transaction.modify(updated);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the text is already that value, or the '
        'objects are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Edited ${committed.change.modified.length} text object(s).',
      transaction: committed,
    );
  }
}
