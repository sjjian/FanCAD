import 'package:fancad_command/fancad_command.dart';

import '../command_base.dart';

const _category = 'Diagnostics';

/// A snapshot of the live renderer: scene, caches, atlas and frame timing.
///
/// This is host diagnostics, not drawing business, so it lives on its own
/// command ids and its own MCP tool. `query.session` stays a description of
/// the drawing and the user's session.
class PerfSessionCommand extends FanCadCommand {
  const PerfSessionCommand();

  @override
  String get id => 'perf.session';
  @override
  String get title => 'Performance Snapshot';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['perf'];
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  AiExposure get aiExposure => AiExposure.hidden;
  @override
  String get description =>
      'Returns live render statistics for the session: retained scene, build '
      'time, submitted segment and draw-call counts, block cache, text atlas '
      'and the rolling build/raster frame percentiles. Use perf.reset before '
      'measuring a cold build.';

  @override
  Future<CommandResult> run(CommandContext context) async {
    final services = context.services;
    if (services is! RenderStatsSource) {
      return const CommandResult.ok(
        message: 'Performance statistics are not available in this host.',
        data: {'supported': false},
      );
    }
    final data = (services as RenderStatsSource).describeRender(
      context.session,
    );
    if (data.isEmpty) {
      return const CommandResult.ok(
        message: 'This session has no canvas to measure.',
        data: {'supported': false},
      );
    }
    final render = data['render'];
    final frame = data['frame'];
    final parts = <String>[];
    if (render is Map) {
      parts.add('${render['drawnSegments']} / ${render['segments']} segments');
      parts.add('${_ms(render['sceneBuildMs'])} ms scene build');
    }
    if (frame is Map) {
      parts.add('${_ms(frame['buildP50Ms'])} ms build p50');
      parts.add('${_ms(frame['rasterP50Ms'])} ms raster p50');
    }
    return CommandResult.ok(
      message: parts.isEmpty
          ? 'Performance snapshot reported.'
          : parts.join(', '),
      data: {...data, 'supported': true},
    );
  }
}

String _ms(Object? value) {
  if (value is num) return value.toStringAsFixed(1);
  return '$value';
}
