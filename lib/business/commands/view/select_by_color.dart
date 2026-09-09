import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _select = 'Select';

class SelectByColorCommand extends FanCadCommand {
  const SelectByColorCommand();

  @override
  String get id => 'select.byColor';
  @override
  String get title => 'Select by Colour';
  @override
  String get category => _select;
  @override
  List<String> get aliases => const ['selcolor'];
  @override
  String get description =>
      'Selects every object whose stored colour matches an ACI, #rrggbb, '
      'ByLayer or ByBlock. Layer-inherited red is not the same as ACI 1.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'color',
      type: ParamType.text,
      description: 'ACI index, #rrggbb, ByLayer or ByBlock',
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final raw = await context.resolveText(
      'color',
      'Enter a colour (1-255, #rrggbb or ByLayer):',
    );
    final color = _tryCadColor(raw);
    if (color == null) {
      return CommandResult.failed(
        '"$raw" is not a colour. Use 1-255, #rrggbb, ByLayer or ByBlock.',
      );
    }
    final ids = [
      for (final entity in context.document.activeEntities)
        if (entity.props.color == color &&
            context.document.isSelectable(entity))
          entity.id,
    ];
    context.selection.replace(ids);
    return CommandResult.ok(
      message: '${ids.length} object(s) selected with colour $color.',
    );
  }
}

/// Same tokens as [edit.changeColor], but unknown text is rejected instead
/// of silently becoming ByLayer.
CadColor? _tryCadColor(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  if (lower == 'bylayer') return const CadColor.byLayer();
  if (lower == 'byblock') return const CadColor.byBlock();
  if (trimmed.startsWith('#')) {
    final hex = trimmed.substring(1);
    if (hex.length != 6) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return CadColor.rgb(parsed);
  }
  final parsed = int.tryParse(trimmed);
  if (parsed == null || parsed < 1 || parsed > 255) return null;
  return CadColor.indexed(parsed);
}
