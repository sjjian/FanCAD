import 'package:fancad_command/fancad_command.dart';

import '../command_base.dart';

const _category = 'Diagnostics';

/// Clears the rolling frame window so the next `perf.session` measures fresh
/// frames.
///
/// With `regen` (the default) it also drops the retained display list, which
/// makes the next snapshot a cold build instead of a replay. It touches only
/// caches and the timing window; the drawing is unchanged.
class PerfResetCommand extends FanCadCommand {
  const PerfResetCommand();

  @override
  String get id => 'perf.reset';
  @override
  String get title => 'Reset Performance Window';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description =>
      'Clears the rolling build/raster frame samples and, unless regen is '
      'false, drops the retained display list so the next perf.session '
      'measures a cold build. Does not modify the drawing.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'regen',
      type: ParamType.boolean,
      description: 'Also rebuild the display list (default true)',
      required: false,
      defaultValue: true,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final services = context.services;
    if (services is! RenderStatsSource) {
      return const CommandResult.ok(
        message: 'Performance statistics are not available in this host.',
        data: {'supported': false},
      );
    }
    final regen = context.args.boolean('regen') ?? true;
    (services as RenderStatsSource).resetRenderStats(
      context.session,
      regen: regen,
    );
    return CommandResult.ok(
      message: regen
          ? 'Frame samples cleared; display regenerated.'
          : 'Frame samples cleared.',
      data: {'supported': true, 'cleared': true, 'regen': regen},
    );
  }
}
