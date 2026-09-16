import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawCircle3pCommand extends FanCadCommand {
  const DrawCircle3pCommand();

  @override
  String get id => 'draw.circle3p';
  @override
  String get title => 'Circle (3 Points)';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['c3p'];
  @override
  String get description =>
      'Draws the unique circle that passes through three specified points.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.point('first', description: 'First point on the circle'),
    ParamSpec.point('second', description: 'Second point on the circle'),
    ParamSpec.point('third', description: 'Third point on the circle'),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final first = await context.resolvePoint(
      'first',
      context.commandPrompt(
        'CIRCLE',
        context.l10n.prompt_specify_first_on_circle,
      ),
    );
    context.input
      ..setMarkers([first])
      ..setPreview((cursor) => [OverlayLine(first, cursor)]);
    final second = await context.resolvePoint(
      'second',
      context.commandPrompt(
        'CIRCLE',
        context.l10n.prompt_specify_second_on_circle,
      ),
      basePoint: first,
    );

    context.input
      ..setMarkers([first, second])
      ..setPreview((cursor) {
        final circle = Construct.circleThrough(first, second, cursor);
        if (circle == null) return [OverlayLine(first, second)];
        return [
          OverlayArc(center: circle.center, radius: circle.radius),
          OverlayLine(first, second, dashed: true),
        ];
      });
    final third = await context.resolvePoint(
      'third',
      context.commandPrompt(
        'CIRCLE',
        context.l10n.prompt_specify_third_on_circle,
      ),
      basePoint: second,
    );
    context.input
      ..setPreview(null)
      ..setMarkers(const []);

    final circle = Construct.circleThrough(
      first,
      second,
      third,
      props: EntityProps(layer: context.document.currentLayer),
    );
    if (circle == null) {
      return const CommandResult.failed(
        'The three points are collinear, so they do not define a circle.',
      );
    }
    return commitDraw(context, 'Circle', [circle]);
  }
}
