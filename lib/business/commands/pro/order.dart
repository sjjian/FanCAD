import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'layout_helpers.dart';

const _category = 'Output';

class LayoutOrderCommand extends FanCadCommand {
  const LayoutOrderCommand();

  @override
  String get id => 'layout.order';
  @override
  String get title => 'Layout Order';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['layoutorder', 'movelayout'];
  @override
  String get description =>
      'Moves a paper tab in the layout strip. Model stays first. '
      'index is the destination among paper tabs (0 = first paper). '
      'Or pass before / after another tab name.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Tab to move. Defaults to the current paper layout.',
      required: false,
    ),
    ParamSpec(
      name: 'index',
      type: ParamType.integer,
      description: 'Destination among paper tabs, from 0',
      required: false,
    ),
    ParamSpec(
      name: 'before',
      type: ParamType.text,
      description: 'Insert before this tab',
      required: false,
    ),
    ParamSpec(
      name: 'after',
      type: ParamType.text,
      description: 'Insert after this tab',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    var requested = context.args.text('name')?.trim() ?? '';
    if (requested.isEmpty) {
      if (context.document.activeLayout.isModelSpace) {
        requested = await context.resolveText('name', 'Layout to move:');
      } else {
        requested = context.document.activeLayoutName;
      }
    }
    final source = layoutNamed(context.document, requested);
    if (source == null) {
      return CommandResult.failed('No layout named $requested');
    }
    if (source.isModelSpace) {
      return const CommandResult.failed('Model stays first.');
    }

    final index = context.args.integer('index');
    final before = context.args.text('before')?.trim() ?? '';
    final after = context.args.text('after')?.trim() ?? '';
    final destCount = [
      if (index != null) 'index',
      if (before.isNotEmpty) 'before',
      if (after.isNotEmpty) 'after',
    ];
    if (destCount.isEmpty) {
      return const CommandResult.failed(
        'Supply index, before or after to place the tab.',
      );
    }
    if (destCount.length > 1) {
      return const CommandResult.failed(
        'Supply only one of index, before or after.',
      );
    }
    if (index != null && index < 0) {
      return const CommandResult.failed('Tab index cannot be negative.');
    }

    final papers = [
      for (final layout in context.document.layouts)
        if (!layout.isModelSpace) layout,
    ];
    if (papers.length < 2) {
      return CommandResult.ok(
        message: 'Layout "${source.name}" is already in place.',
        data: {
          'name': source.name,
          'order': [for (final layout in context.document.layouts) layout.name],
        },
      );
    }

    final remaining = [
      for (final layout in papers)
        if (layout.name != source.name) layout,
    ];
    var insertAt = remaining.length;
    if (index != null) {
      insertAt = index > remaining.length ? remaining.length : index;
    } else if (before.isNotEmpty) {
      final target = layoutNamed(context.document, before);
      if (target == null) {
        return CommandResult.failed('No layout named $before');
      }
      if (target.isModelSpace) {
        return const CommandResult.failed('Cannot place a tab before Model.');
      }
      if (target.name == source.name) {
        return CommandResult.ok(
          message: 'Layout "${source.name}" is already in place.',
          data: {
            'name': source.name,
            'order': [
              for (final layout in context.document.layouts) layout.name,
            ],
          },
        );
      }
      insertAt = remaining.indexWhere((item) => item.name == target.name);
    } else {
      final target = layoutNamed(context.document, after);
      if (target == null) {
        return CommandResult.failed('No layout named $after');
      }
      if (target.isModelSpace) {
        insertAt = 0;
      } else if (target.name == source.name) {
        return CommandResult.ok(
          message: 'Layout "${source.name}" is already in place.',
          data: {
            'name': source.name,
            'order': [
              for (final layout in context.document.layouts) layout.name,
            ],
          },
        );
      } else {
        insertAt = remaining.indexWhere((item) => item.name == target.name) + 1;
      }
    }
    if (insertAt < 0) {
      return const CommandResult.failed('The destination tab is missing.');
    }

    final next = [...remaining]..insert(insertAt, source);
    final sameOrder =
        next.length == papers.length &&
        [
          for (var i = 0; i < next.length; i++) next[i].name == papers[i].name,
        ].every((item) => item);
    if (sameOrder) {
      return CommandResult.ok(
        message: 'Layout "${source.name}" is already in place.',
        data: {
          'name': source.name,
          'order': [for (final layout in context.document.layouts) layout.name],
        },
      );
    }

    final model = context.document.layouts.firstWhere(
      (layout) => layout.isModelSpace,
    );
    final committed = context.edit('Layout Order', (transaction) {
      if (model.tabOrder != 0) {
        transaction.putLayout(model.copyWith(tabOrder: 0));
      }
      for (var i = 0; i < next.length; i++) {
        final order = i + 1;
        if (next[i].tabOrder != order) {
          transaction.putLayout(next[i].copyWith(tabOrder: order));
        }
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The tab order was not changed.');
    }
    context.services.invalidate();
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Moved "${source.name}" to paper tab $insertAt.',
      data: {
        'name': source.name,
        'index': insertAt,
        'order': [model.name, for (final layout in next) layout.name],
      },
      transaction: committed,
    );
  }
}
