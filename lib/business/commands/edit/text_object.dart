import 'dart:math' as math;

import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Modify';

const _alignFit = {'a', 'align', 'aligned', 'f', 'fit'};

class EditTextObjectCommand extends FanCadCommand {
  const EditTextObjectCommand();

  @override
  String get id => 'edit.textObject';
  @override
  String get title => 'Edit Text Object';
  @override
  String get category => _category;
  @override
  String get description =>
      'Updates content, height, colour, justification, rotation, style, '
      'column width, width factor or oblique of selected text, mtext, '
      'attributes or leaders in one undo. Dimension text height is a '
      'dimstyle property and is ignored.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec.selection('ids'),
    ParamSpec(
      name: 'text',
      type: ParamType.text,
      description: 'New content, or dimension override',
      required: false,
    ),
    ParamSpec(
      name: 'height',
      type: ParamType.number,
      description: 'Cap height in drawing units',
      required: false,
    ),
    ParamSpec(
      name: 'color',
      type: ParamType.text,
      description: 'ACI index, #rrggbb, ByLayer or ByBlock',
      required: false,
    ),
    ParamSpec(
      name: 'justify',
      type: ParamType.text,
      description: 'Left, Center, Right, TL, TC, TR, ML, MC, MR, BL, BC, BR',
      required: false,
    ),
    ParamSpec(
      name: 'rotation',
      type: ParamType.angle,
      description: 'Rotation in degrees, counter-clockwise, about the insertion',
      required: false,
    ),
    ParamSpec(
      name: 'style',
      type: ParamType.text,
      description: 'Text style name',
      required: false,
    ),
    ParamSpec(
      name: 'width',
      type: ParamType.distance,
      description: 'MTEXT wrapping width. 0 means no wrap.',
      required: false,
    ),
    ParamSpec(
      name: 'widthFactor',
      type: ParamType.number,
      description: 'TEXT width factor. Must be positive.',
      required: false,
    ),
    ParamSpec(
      name: 'oblique',
      type: ParamType.angle,
      description: 'TEXT oblique angle in degrees',
      required: false,
    ),
    ParamSpec(
      name: 'prompt',
      type: ParamType.text,
      description:
          'Property to ask for: height, rotation, style, width, '
          'widthFactor, oblique or justify',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final ids = await context.resolveSelection(
      'ids',
      'Select text objects:',
    );
    if (ids.isEmpty) return const CommandResult.cancelled();
    final targets = <CadEntity>[
      for (final id in ids)
        if (context.document.entity(id) case final CadEntity entity)
          if (isTextEditTarget(entity)) entity,
    ];
    if (targets.isEmpty) {
      return const CommandResult.failed(
        'Select text, mtext, an attribute or a dimension.',
      );
    }

    final prompt = _fieldKey(context.args.text('prompt') ?? '');
    final hasText = context.args.has('text');
    final hasHeight = context.args.has('height') || prompt == 'height';
    final hasColor = context.args.has('color');
    final hasJustify = context.args.has('justify') || prompt == 'justify';
    final hasRotation = context.args.has('rotation') || prompt == 'rotation';
    final hasStyle = context.args.has('style') || prompt == 'style';
    final hasWidth = context.args.has('width') || prompt == 'width';
    final hasWidthFactor =
        context.args.has('widthFactor') || prompt == 'widthfactor';
    final hasOblique = context.args.has('oblique') || prompt == 'oblique';
    if (!hasText &&
        !hasHeight &&
        !hasColor &&
        !hasJustify &&
        !hasRotation &&
        !hasStyle &&
        !hasWidth &&
        !hasWidthFactor &&
        !hasOblique) {
      return const CommandResult.failed(
        'Specify text, height, colour, justification, rotation, style, '
        'width, width factor or oblique.',
      );
    }

    final first = targets.first;
    final text = hasText ? (context.args.text('text') ?? '') : null;
    final height = hasHeight
        ? await context.resolveNumber(
            'height',
            'Specify new height:',
            defaultValue: textHeightOf(first) ?? 2.5,
          )
        : null;
    if (hasHeight && (height == null || height <= 0)) {
      return const CommandResult.failed('Text height must be positive.');
    }
    final color = hasColor
        ? cadColorFromJson(context.args.text('color'))
        : null;
    var justify = hasJustify ? (context.args.text('justify') ?? '').trim() : null;
    if (hasJustify && (justify == null || justify.isEmpty)) {
      justify = (await context.resolveText(
        'justify',
        'Enter justification [Left/Center/Right/TL/TC/TR/ML/MC/MR/BL/BC/BR]:',
        defaultValue: textJustifyKeyOf(first) ?? 'left',
      )).trim();
    }
    final rotationDegrees = hasRotation
        ? await context.resolveNumber(
            'rotation',
            'Specify rotation angle:',
            defaultValue:
                (textRotationOf(first) ?? 0) * 180 / math.pi,
          )
        : null;
    if (hasRotation && rotationDegrees == null) {
      return const CommandResult.failed('Rotation must be a number of degrees.');
    }
    var styleName = hasStyle ? (context.args.text('style') ?? '').trim() : null;
    if (hasStyle && (styleName == null || styleName.isEmpty)) {
      styleName = (await context.resolveText(
        'style',
        'Enter text style name:',
        defaultValue: textStyleNameOf(first) ?? context.document.currentTextStyle,
      )).trim();
    }
    TextStyleDef? styleDef;
    if (hasStyle) {
      if (styleName == null || styleName.isEmpty) {
        return const CommandResult.failed('A text style needs a name.');
      }
      styleDef = context.document.namedTextStyle(styleName);
      if (styleDef == null) {
        return CommandResult.failed('There is no text style named "$styleName".');
      }
    }
    final width = hasWidth
        ? await context.resolveNumber(
            'width',
            'Specify column width:',
            defaultValue: textColumnWidthOf(first) ?? 0,
          )
        : null;
    if (hasWidth && (width == null || width < 0)) {
      return const CommandResult.failed('Text width cannot be negative.');
    }
    final widthFactor = hasWidthFactor
        ? await context.resolveNumber(
            'widthFactor',
            'Specify width factor:',
            defaultValue: textWidthFactorOf(first) ?? 1,
          )
        : null;
    if (hasWidthFactor && (widthFactor == null || widthFactor <= 0)) {
      return const CommandResult.failed('Width factor must be positive.');
    }
    final obliqueDegrees = hasOblique
        ? await context.resolveNumber(
            'oblique',
            'Specify oblique angle:',
            defaultValue: (textObliqueOf(first) ?? 0) * 180 / math.pi,
          )
        : null;
    if (hasOblique && obliqueDegrees == null) {
      return const CommandResult.failed(
        'Oblique must be a number of degrees.',
      );
    }
    if (hasJustify &&
        (justify == null ||
            Construct.parseTextJustify(
                  justify,
                  currentH: TextHAlign.left,
                  currentV: TextVAlign.baseline,
                ) ==
                null ||
            _alignFit.contains(
              justify.toLowerCase().replaceAll(RegExp(r'[\s_-]+'), ''),
            ))) {
      return CommandResult.failed(
        '"$justify" is not a justification. Use Left, Center, Right or '
        'a corner code such as TL.',
      );
    }
    if (text != null &&
        targets.any(textEditRequiresContent) &&
        text.isEmpty) {
      return const CommandResult.failed('Text cannot be empty.');
    }

    final committed = context.edit('Edit Text', (transaction) {
      for (final entity in targets) {
        var next = entity;
        if (text != null) {
          next = entityWithEditedText(next, text) ?? next;
        }
        if (height != null) {
          next = entityWithHeight(next, height) ?? next;
        }
        if (justify != null && justify.isNotEmpty) {
          next = entityWithJustify(next, justify) ?? next;
        }
        if (rotationDegrees != null) {
          next =
              entityWithRotation(next, rotationDegrees * math.pi / 180) ?? next;
        }
        if (styleDef != null) {
          next =
              entityWithStyle(
                next,
                styleDef.name,
                fixedHeight: styleDef.height > 0 ? styleDef.height : null,
              ) ??
              next;
        }
        if (width != null) {
          next = entityWithColumnWidth(next, width) ?? next;
        }
        if (widthFactor != null) {
          next = entityWithWidthFactor(next, widthFactor) ?? next;
        }
        if (obliqueDegrees != null) {
          next =
              entityWithOblique(next, obliqueDegrees * math.pi / 180) ?? next;
        }
        if (color != null && next.props.color != color) {
          next = next.withProps(next.props.copyWith(color: color));
        }
        if (!identical(next, entity)) transaction.modify(next);
      }
    });
    if (committed == null) {
      return const CommandResult.failed(
        'Nothing changed; the objects already have those values, or '
        'they are on a locked layer.',
      );
    }
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Edited ${committed.change.modified.length} text object(s).',
      transaction: committed,
    );
  }
}

String _fieldKey(String raw) =>
    raw.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
