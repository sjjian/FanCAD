import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Modify';

class EditMatchPropCommand extends FanCadCommand {
  const EditMatchPropCommand();

  @override
  String get id => 'edit.matchProp';
  @override
  String get title => 'Match Properties';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['ma', 'matchprop'];
  @override
  String get description =>
      'Copies layer, colour, linetype, lineweight and the other display '
      'properties from a source object onto the destination objects. '
      'Visibility is left alone so isolate and hide stay intact.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'source',
      type: ParamType.entity,
      description: 'Object whose properties are copied',
    ),
    ParamSpec.selection(
      'ids',
      description: 'Objects that receive the properties',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final suppliedSource = context.args.integer('source');
    final int sourceId;
    if (suppliedSource != null) {
      sourceId = suppliedSource;
    } else {
      context.selection.clear();
      final picked = await context.input.selection(
        'MATCHPROP  Select source object:',
        single: true,
      );
      if (picked.isEmpty) return const CommandResult.cancelled();
      sourceId = picked.first;
    }

    final source = context.document.entity(sourceId);
    if (source == null) {
      return const CommandResult.failed('The source object no longer exists.');
    }

    context.selection.clear();
    final destinations = (await context.resolveSelection(
      'ids',
      'MATCHPROP  Select destination objects:',
    )).where((id) => id != sourceId).toList();
    if (destinations.isEmpty) return const CommandResult.cancelled();

    final committed = context.edit('Match Properties', (transaction) {
      for (final id in destinations) {
        final target = context.document.entity(id);
        if (target == null) continue;
        transaction.setProps(
          id,
          source.props.copyWith(visible: target.props.visible),
        );
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the destinations already match or are locked.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message:
          'Matched properties onto ${committed.change.modified.length} '
          'object(s).',
      data: {'ids': committed.change.modified},
      transaction: committed,
    );
  }
}
