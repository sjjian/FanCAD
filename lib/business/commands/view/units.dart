import 'package:fancad_core/fancad_core.dart';

import '../command_base.dart';

const _view = 'View';

class ViewUnitsCommand extends FanCadCommand {
  const ViewUnitsCommand();

  @override
  String get id => 'view.units';
  @override
  String get title => 'Units';
  @override
  String get category => _view;
  @override
  List<String> get aliases => const ['units', 'insunits'];
  @override
  String get description =>
      'Sets the drawing insertion units written to \$INSUNITS. '
      'Coordinates stay in these units; the value is what importers and '
      'queries use to convert.';
  @override
  List<ParamSpec> get params => const [
    ParamSpec(
      name: 'units',
      type: ParamType.text,
      description: 'Unit name or DXF code: mm, cm, m, in, ft, 4, …',
      required: false,
    ),
  ];

  @override
  Future<CommandResult> run(CommandContext context) async {
    final current = context.document.insUnits;
    final raw = await context.resolveText(
      'units',
      'UNITS  Enter insertion units <${current.label}>:',
      defaultValue: current.label,
    );
    final parsed = InsUnits.parse(raw);
    if (parsed == null) {
      return CommandResult.failed(
        '"$raw" is not a drawing unit. Use mm, cm, m, in, ft, or a '
        'DXF code 0–7.',
      );
    }
    if (parsed == current) {
      return CommandResult.ok(
        message: 'Insertion units are already ${parsed.label}.',
      );
    }
    final committed = context.edit('Units', (transaction) {
      transaction.setHeaderVariable(r'$INSUNITS', '${parsed.code}');
    });
    return CommandResult(
      status: CommandStatus.ok,
      message: 'Insertion units set to ${parsed.label}.',
      transaction: committed,
    );
  }
}
