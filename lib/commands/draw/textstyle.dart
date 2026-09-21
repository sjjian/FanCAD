import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _category = 'Draw';

class AnnotTextstyleCommand extends FanCadCommand {
  const AnnotTextstyleCommand();

  @override
  String get id => 'annot.textstyle';
  @override
  String get title => 'Text Style';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['style', '-style', 'textstyle', 'ddstyle'];
  @override
  String get description =>
      'Creates or edits a text style. New TEXT and MTEXT read the font, '
      'fixed height, width factor and oblique from the named style. Omit '
      'the name to list styles or to edit the current one.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'name',
      type: ParamType.text,
      description: 'Style to create or edit. Omit to list or edit current.',
      required: false,
    ),
    ParamSpec(
      name: 'font',
      type: ParamType.text,
      description: 'SHX or TTF font family recorded in the drawing',
      required: false,
    ),
    ParamSpec(
      name: 'bigFont',
      type: ParamType.text,
      description: 'Secondary font for CJK glyphs in SHX styles',
      required: false,
    ),
    ParamSpec(
      name: 'height',
      type: ParamType.distance,
      description: 'Fixed height, or 0 when each object supplies height',
      required: false,
    ),
    ParamSpec(
      name: 'widthFactor',
      type: ParamType.number,
      description: 'Character width factor. Must be positive.',
      required: false,
    ),
    ParamSpec(
      name: 'oblique',
      type: ParamType.angle,
      description: 'Oblique angle in degrees',
      required: false,
    ),
    ParamSpec(
      name: 'current',
      type: ParamType.boolean,
      description: 'Make this the current text style',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final name = context.args.text('name')?.trim() ?? '';
    final makeCurrent = context.args.boolean('current') ?? false;
    final hasEdits =
        (context.args.text('font')?.trim().isNotEmpty ?? false) ||
        context.args.has('bigFont') ||
        context.args.number('height') != null ||
        context.args.number('widthFactor') != null ||
        context.args.number('oblique') != null;
    if (name.isEmpty && !hasEdits && !makeCurrent) {
      return _listTextStyles(context);
    }

    final target = name.isEmpty ? context.document.currentTextStyle : name;
    if (target.isEmpty) {
      return const CommandResult.failed('A text style needs a name.');
    }
    final existing = context.document.namedTextStyle(target);
    if (!hasEdits) {
      if (existing == null) {
        return CommandResult.failed('No text style named $target.');
      }
      if (!makeCurrent || context.document.currentTextStyle == existing.name) {
        return CommandResult.ok(
          message: 'Current text style is ${existing.name}.',
          data: _textStyleData(existing, current: existing.name),
        );
      }
      final committed = context.edit('Current Text Style', (transaction) {
        transaction.setCurrentTextStyle(existing.name);
      });
      if (committed == null) {
        return const CommandResult.failed(
          'The current text style was not changed.',
        );
      }
      return CommandResult(
        status: CommandStatus.ok,
        message: 'Current text style is ${existing.name}.',
        data: _textStyleData(existing, current: existing.name),
        transaction: committed,
      );
    }

    final base = existing ?? TextStyleDef(name: target);
    final next = _textStyleFromArgs(context, base);
    if (next.$1 != null) return CommandResult.failed(next.$1!);
    final style = next.$2!;
    final committed = context.edit('Text Style', (transaction) {
      transaction.putTextStyle(style);
      if (makeCurrent || existing == null) {
        transaction.setCurrentTextStyle(style.name);
      }
    });
    if (committed == null) {
      return const CommandResult.failed('The text style was not saved.');
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: existing == null
          ? 'Created text style ${style.name}.'
          : 'Updated text style ${style.name}.',
      data: _textStyleData(
        style,
        current: makeCurrent || existing == null
            ? style.name
            : context.document.currentTextStyle,
      ),
      transaction: committed,
    );
  }
}

CommandResult _listTextStyles(CommandContext context) {
  final current = context.document.currentTextStyle;
  final styles = [
    for (final style in context.document.textStyles.values)
      _textStyleData(style, current: current),
  ];
  return CommandResult.ok(
    message: '${styles.length} text style(s). Current is $current.',
    data: {'current': current, 'styles': styles},
  );
}

Map<String, Object?> _textStyleData(
  TextStyleDef style, {
  required String current,
}) => {
  'name': style.name,
  'font': style.fontFamily,
  'bigFont': style.bigFontFamily,
  'height': style.height,
  'widthFactor': style.widthFactor,
  'oblique': style.obliqueAngle * 180 / math.pi,
  'current': style.name == current,
};

(String?, TextStyleDef?) _textStyleFromArgs(
  CommandContext context,
  TextStyleDef base,
) {
  final font = context.args.text('font')?.trim();
  final bigFont = context.args.has('bigFont')
      ? (context.args.text('bigFont') ?? '').trim()
      : null;
  final height = context.args.number('height') ?? base.height;
  final widthFactor = context.args.number('widthFactor') ?? base.widthFactor;
  final obliqueDegrees = context.args.number('oblique');
  if (height < 0) {
    return ('Text style height cannot be negative.', null);
  }
  if (widthFactor <= 0) {
    return ('Width factor must be positive.', null);
  }
  return (
    null,
    base.copyWith(
      fontFamily: (font == null || font.isEmpty) ? base.fontFamily : font,
      bigFontFamily: bigFont ?? base.bigFontFamily,
      height: height,
      widthFactor: widthFactor,
      obliqueAngle: obliqueDegrees == null
          ? base.obliqueAngle
          : obliqueDegrees * math.pi / 180,
    ),
  );
}
