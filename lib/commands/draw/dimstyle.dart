import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Draw';

class AnnotDimstyleCommand extends FanCadCommand {
  const AnnotDimstyleCommand();

  @override
  String get id => 'annot.dimstyle';
  @override
  String get title => 'Dimension Style';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['dimstyle', '-dimstyle', 'ddim'];
  @override
  String get description =>
      'Creates or edits a dimension style. Regenerated dimensions read '
      'text height, arrow size, extension offsets, scale and decimal '
      'places from the named style. Omit the name to list styles or to '
      'edit the current one.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Style to create or edit. Omit to list or edit current.',
      required: false,
    ),
    ParamSpec(
      name: 'textHeight',
      type: ParamType.distance,
      description: 'DIMTXT, text height in drawing units',
      required: false,
    ),
    ParamSpec(
      name: 'arrowSize',
      type: ParamType.distance,
      description: 'DIMASZ, arrowhead size',
      required: false,
    ),
    ParamSpec(
      name: 'decimalPlaces',
      type: ParamType.integer,
      description: 'DIMDEC, 0–8',
      required: false,
    ),
    ParamSpec(
      name: 'scale',
      type: ParamType.distance,
      description: 'DIMSCALE, overall scale',
      required: false,
    ),
    ParamSpec(
      name: 'extensionOffset',
      type: ParamType.distance,
      description: 'DIMEXO, gap from the origin to the extension line',
      required: false,
    ),
    ParamSpec(
      name: 'extensionExtend',
      type: ParamType.distance,
      description: 'DIMEXE, extension past the dimension line',
      required: false,
    ),
    ParamSpec(
      name: 'textGap',
      type: ParamType.distance,
      description: 'DIMGAP, stored for later text placement',
      required: false,
    ),
    ParamSpec(
      name: 'textStyle',
      type: ParamType.text,
      description: 'DIMTXSTY, text style name',
      required: false,
    ),
    ParamSpec(
      name: 'current',
      type: ParamType.boolean,
      description: 'Make this the current dimension style',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = context.args.text('name')?.trim() ?? '';
    final makeCurrent = context.args.boolean('current') ?? false;
    final hasEdits =
        context.args.number('textHeight') != null ||
        context.args.number('arrowSize') != null ||
        context.args.integer('decimalPlaces') != null ||
        context.args.number('scale') != null ||
        context.args.number('extensionOffset') != null ||
        context.args.number('extensionExtend') != null ||
        context.args.number('textGap') != null ||
        (context.args.text('textStyle')?.trim().isNotEmpty ?? false);
    if (name.isEmpty && !hasEdits && !makeCurrent) {
      return _listDimStyles(context);
    }

    final target = name.isEmpty ? context.document.currentDimStyle : name;
    if (target.isEmpty) {
      return const CommandResult.failed('A dimension style needs a name.');
    }
    final existing = context.document.namedDimStyle(target);
    if (!hasEdits) {
      if (existing == null) {
        return CommandResult.failed('No dimension style named $target.');
      }
      if (!makeCurrent || context.document.currentDimStyle == existing.name) {
        return CommandResult.ok(
          message: 'Current dimension style is ${existing.name}.',
          data: _dimStyleData(existing, current: existing.name),
        );
      }
      final committed = context.edit('Current DimStyle', (transaction) {
        transaction.setCurrentDimStyle(existing.name);
      });
      if (committed == null) {
        return const CommandResult.failed(
          'The current dimension style was not changed.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Current dimension style is ${existing.name}.',
        data: _dimStyleData(existing, current: existing.name),
        transaction: committed,
      );
    }

    final base = existing ?? DimStyleDef(name: target);
    final next = _dimStyleFromArgs(context, base);
    if (next.$1 != null) return CommandResult.failed(next.$1!);
    final style = next.$2!;
    final committed = context.edit('DimStyle', (transaction) {
      transaction.putDimStyle(style);
      if (makeCurrent || existing == null) {
        transaction.setCurrentDimStyle(style.name);
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The dimension style was not saved.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: existing == null
          ? 'Created dimension style ${style.name}.'
          : 'Updated dimension style ${style.name}.',
      data: _dimStyleData(
        style,
        current: makeCurrent || existing == null
            ? style.name
            : context.document.currentDimStyle,
      ),
      transaction: committed,
    );
  }
}

CommandResult _listDimStyles(CommandContext context) {
  final current = context.document.currentDimStyle;
  final styles = [
    for (final style in context.document.dimStyles.values)
      _dimStyleData(style, current: current),
  ];
  return CommandResult.ok(
    message: '${styles.length} dimension style(s). Current is $current.',
    data: {'current': current, 'styles': styles},
  );
}

Map<String, Object?> _dimStyleData(
  DimStyleDef style, {
  required String current,
}) => {
  'name': style.name,
  'textHeight': style.textHeight,
  'arrowSize': style.arrowSize,
  'decimalPlaces': style.decimalPlaces,
  'scale': style.scale,
  'extensionOffset': style.extensionLineOffset,
  'extensionExtend': style.extensionLineExtend,
  'textGap': style.textGap,
  'textStyle': style.textStyle,
  'current': style.name == current,
};

(String?, DimStyleDef?) _dimStyleFromArgs(
  CommandContext context,
  DimStyleDef base,
) {
  final textHeight = context.args.number('textHeight') ?? base.textHeight;
  final arrowSize = context.args.number('arrowSize') ?? base.arrowSize;
  final decimals = context.args.integer('decimalPlaces') ?? base.decimalPlaces;
  final scale = context.args.number('scale') ?? base.scale;
  final exo =
      context.args.number('extensionOffset') ?? base.extensionLineOffset;
  final exe =
      context.args.number('extensionExtend') ?? base.extensionLineExtend;
  final gap = context.args.number('textGap') ?? base.textGap;
  final textStyle = context.args.text('textStyle')?.trim();
  if (textHeight <= 0) {
    return ('Text height must be positive.', null);
  }
  if (arrowSize <= 0) {
    return ('Arrow size must be positive.', null);
  }
  if (scale <= 0) {
    return ('Dimension scale must be positive.', null);
  }
  if (decimals < 0 || decimals > 8) {
    return ('Decimal places must be between 0 and 8.', null);
  }
  if (exo < 0 || exe < 0 || gap < 0) {
    return ('Extension offset, extend and text gap cannot be negative.', null);
  }
  return (
    null,
    base.copyWith(
      textHeight: textHeight,
      arrowSize: arrowSize,
      decimalPlaces: decimals,
      scale: scale,
      extensionLineOffset: exo,
      extensionLineExtend: exe,
      textGap: gap,
      textStyle: (textStyle == null || textStyle.isEmpty)
          ? base.textStyle
          : textStyle,
    ),
  );
}
