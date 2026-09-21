import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';
import 'helpers.dart';

const _category = 'Draw';

class DrawAttdefCommand extends FanCadCommand {
  const DrawAttdefCommand();

  @override
  String get id => 'draw.attdef';
  @override
  String get title => 'Attribute Definition';
  @override
  String get category => _category;
  @override
  List<String> get aliases => const ['att', 'attdef'];
  @override
  String? get icon => 'text';
  @override
  String get description =>
      'Places an attribute definition. Include it in a BLOCK so INSERT '
      'and ATTEDIT can fill the tag — title blocks and schedules.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(name: 'tag', type: ParamType.text, description: 'Attribute tag'),
    ParamSpec(
      name: 'prompt',
      type: ParamType.text,
      description: 'Prompt shown on INSERT',
      required: false,
    ),
    ParamSpec(
      name: 'value',
      type: ParamType.text,
      description: 'Default value',
      required: false,
    ),
    ParamSpec.point('at', description: 'Insertion point'),
    ParamSpec(
      name: 'height',
      type: ParamType.distance,
      description: 'Cap height in drawing units',
      required: false,
      defaultValue: 2.5,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final tag = (await context.resolveText(
      'tag',
      context.commandPrompt('ATTDEF', context.l10n.prompt_enter_attribute_tag),
    )).trim();
    if (tag.isEmpty) {
      return const CommandResult.failed('An attribute needs a tag.');
    }
    final prompt = (await context.resolveText(
      'prompt',
      context.commandPrompt(
        'ATTDEF',
        context.l10n.prompt_enter_attribute_prompt,
      ),
      defaultValue: tag,
    )).trim();
    final value = await context.resolveText(
      'value',
      context.commandPrompt('ATTDEF', context.l10n.prompt_enter_default_value),
      defaultValue: '',
    );
    final height =
        context.args.number('height') ??
        await context.input.number(
          context.commandPrompt('ATTDEF', context.l10n.prompt_specify_height),
          defaultValue: 2.5,
        );
    final at = await context.resolvePoint(
      'at',
      context.commandPrompt(
        'ATTDEF',
        context.l10n.prompt_specify_insertion_point,
      ),
    );
    return commitDraw(context, 'Attdef', [
      AttdefEntity(
        id: 0,
        props: EntityProps(layer: context.document.currentLayer),
        position: at,
        tag: tag,
        prompt: prompt,
        defaultValue: value,
        height: height,
      ),
    ]);
  }
}
