import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'describe.dart';

const _category = 'Inquiry';

class QueryEntitiesCommand extends FanCadCommand {
  const QueryEntitiesCommand();

  @override
  String get id => 'query.entities';
  @override
  String get title => 'Query Entities';
  @override
  String get category => _category;
  @override
  CommandRisk get risk => CommandRisk.readOnly;
  @override
  String get description =>
      'Finds entities matching optional filters and returns their ids and '
      'properties. Use layer, kind and a bounding window to narrow a large '
      'drawing to the part you care about.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'layer',
      type: ParamType.layer,
      description: 'Restrict to one layer',
      required: false,
    ),
    ParamSpec(
      name: 'kind',
      type: ParamType.text,
      description: 'Restrict to one entity type, for example line or circle',
      required: false,
    ),
    ParamSpec(
      name: 'window',
      type: ParamType.json,
      description: 'Bounding box as [minX, minY, maxX, maxY]',
      required: false,
    ),
    ParamSpec(
      name: 'limit',
      type: ParamType.integer,
      description: 'Maximum number of results',
      required: false,
      defaultValue: 200,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final layer = context.args.text('layer');
    final kind = context.args.text('kind')?.toLowerCase();
    final limit = context.args.integer('limit') ?? 200;
    final windowValues = context.args['window'];
    Bounds2? window;
    if (windowValues is List && windowValues.length >= 4) {
      final numbers = [
        for (final value in windowValues) (value as num).toDouble(),
      ];
      window = Bounds2(numbers[0], numbers[1], numbers[2], numbers[3]);
    }

    // The spatial index turns a windowed query from a full scan into a tree
    // descent, which is the difference between a usable AI tool and a timeout
    // on a large drawing.
    final candidates = window == null
        ? context.document.activeEntities
        : [
            for (final id in context.document.queryVisible(window))
              ?context.document.entity(id),
          ];

    final matches = <Map<String, Object?>>[];
    var total = 0;
    for (final entity in candidates) {
      if (layer != null && entity.props.layer != layer) continue;
      if (kind != null && entity.kind.name.toLowerCase() != kind) continue;
      total++;
      if (matches.length < limit) {
        matches.add(describeEntity(context.document, entity));
      }
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: total <= limit
          ? '$total object(s) matched.'
          : '$total object(s) matched; the first $limit are returned.',
      data: {'total': total, 'returned': matches.length, 'entities': matches},
    );
  }
}
