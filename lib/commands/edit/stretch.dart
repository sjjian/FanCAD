import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

class EditStretchCommand extends FanCadCommand {
  const EditStretchCommand();

  @override
  String get id => 'edit.stretch';
  @override
  String get title => 'Stretch';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['s', 'stretch'];
  @override
  String? get icon => 'stretch';
  @override
  String get description =>
      'Moves vertices inside a crossing window and leaves the rest '
      'anchored. Objects wholly captured by the window move as a body.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point(
      'corner1',
      description: 'First corner of the stretch window',
    ),
    ParamSpec.point('corner2', description: 'Opposite corner'),
    ParamSpec.point('from', description: 'Base point of the displacement'),
    ParamSpec.point('to', description: 'Second point of the displacement'),
    ParamSpec(
      name: 'ids',
      type: ParamType.selection,
      required: false,
      description: 'Objects to stretch; omitted uses whatever the window hits',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final first = await context.resolvePoint(
      'corner1',
      context.commandPrompt(
        'STRETCH',
        context.l10n.prompt_specify_crossing_first_corner,
      ),
    );
    context.input.setPreview(
      (cursor) => [OverlayRect(first, cursor, crossing: true)],
    );
    final second = await context.resolvePoint(
      'corner2',
      context.commandPrompt(
        'STRETCH',
        context.l10n.prompt_specify_opposite_corner,
      ),
      basePoint: first,
    );
    context.input.setPreview(null);
    final window = Bounds2.fromCorners(first, second);
    if (window.isEmpty || (window.width == 0 && window.height == 0)) {
      return const CommandResult.failed('The stretch window is empty.');
    }

    final provided = context.args.ids('ids');
    final ids = <int>[
      if (provided != null && provided.isNotEmpty)
        ...provided
      else if (context.selection.isNotEmpty)
        ...context.selection.ids
      else
        ...context.document.queryVisible(window),
    ];

    final from = await context.resolvePoint(
      'from',
      context.commandPrompt('STRETCH', context.l10n.prompt_specify_base_point),
    );
    context.input.setPreview((cursor) {
      final delta = cursor - from;
      final shapes = <OverlayShape>[
        OverlayLine(from, cursor),
        OverlayRect(first, second, crossing: true),
      ];
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final stretched = Construct.stretch(entity, window, delta);
        if (stretched != null) {
          shapes.addAll(
            editOutline(
              context.document,
              stretched,
              shxFonts: context.services.shxFonts,
            ),
          );
        }
      }
      return shapes;
    });
    final to = await context.resolvePoint(
      'to',
      context.commandPrompt(
        'STRETCH',
        context.l10n.prompt_specify_second_point,
      ),
      basePoint: from,
    );
    context.input.setPreview(null);

    final delta = to - from;
    if (delta.lengthSquared < 1e-20) {
      return const CommandResult.cancelled('The displacement is zero.');
    }

    final committed = context.edit('Stretch', (transaction) {
      for (final id in ids) {
        final entity = context.document.entity(id);
        if (entity == null) continue;
        final stretched = Construct.stretch(entity, window, delta);
        if (stretched != null) transaction.modify(stretched);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing in the window had a vertex to stretch.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Stretched ${committed.change.modified.length} object(s).',
      data: {'ids': committed.change.modified},
      transaction: committed,
    );
  }
}
