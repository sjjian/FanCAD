import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawCenterLineCommand extends FanCadCommand {
  const DrawCenterLineCommand();

  @override
  String get id => 'draw.centerLine';
  @override
  String get title => 'Centerline';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['centerline', 'cline'];
  @override
  String? get icon => 'dimension';
  @override
  String get description =>
      'Draws a centreline between two parallel lines, or through the '
      'centres of two circles or arcs. The line spans both objects and '
      'extends a little past each end.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'first',
      type: ParamType.entity,
      description: 'First line, circle or arc',
      required: false,
    ),
    ParamSpec(
      name: 'second',
      type: ParamType.entity,
      description: 'Second line, circle or arc',
      required: false,
    ),
    ParamSpec(
      name: 'extension',
      type: ParamType.distance,
      description: 'How far the centreline overshoots each end',
      required: false,
      defaultValue: 2.5,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final pair = await _resolveCenterLinePair(context);
    if (pair == null) {
      return const CommandResult.cancelled();
    }
    final (first, second) = pair;
    final line = Construct.centerLine(
      first,
      second,
      props: EntityProps(layer: context.document.currentLayer),
      extension: context.args.number('extension') ?? 2.5,
    );
    if (line == null) {
      return const CommandResult.failed(
        'Centerline needs two parallel lines, or two circles or arcs '
        'with different centres.',
      );
    }
    return commitDraw(context, 'Centerline', [line]);
  }
}

Future<(CadEntity, CadEntity)?> _resolveCenterLinePair(
  CommandContext context,
) async {
  var firstId = context.args.integer('first');
  var secondId = context.args.integer('second');
  if (firstId == null || secondId == null) {
    final ids = context.args.ids('ids') ?? context.selection.ids.toList();
    if (ids.length >= 2) {
      firstId ??= ids[0];
      secondId ??= ids[1];
    }
  }
  if (firstId == null) {
    context.selection.clear();
    final picked = await context.input.selection(
      'CENTERLINE  Select first line, circle or arc:',
      useExistingSelection: false,
      single: true,
    );
    if (picked.isEmpty) return null;
    firstId = picked.first;
  }
  if (secondId == null) {
    context.selection.clear();
    final picked = await context.input.selection(
      'CENTERLINE  Select second line, circle or arc:',
      useExistingSelection: false,
      single: true,
    );
    if (picked.isEmpty) return null;
    secondId = picked.first;
  }
  if (firstId == secondId) return null;
  final first = context.document.entity(firstId);
  final second = context.document.entity(secondId);
  if (first == null || second == null) return null;
  return (first, second);
}
