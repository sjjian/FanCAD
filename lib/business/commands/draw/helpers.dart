import 'package:fancad_core/fancad_core.dart';

const ParamSpec dimStyleParam = ParamSpec(
  name: 'style',
  type: ParamType.text,
  description: 'Dimension style. Defaults to the current DIMSTYLE.',
  required: false,
);

String dimStyleName(CommandContext context) {
  final name = context.args.text('style')?.trim() ?? '';
  return name.isEmpty ? context.document.currentDimStyle : name;
}

List<String> vertexKeywords(int count) => [
  if (count >= 1) 'Undo',
  if (count >= 3) 'Close',
];

Future<bool> acceptPointPlacement(
  CommandContext context,
  String message,
  List<Vec2> points,
) async {
  if (!context.input.isInteractive) return true;
  context.input
    ..setMarkers(List.of(points))
    ..setPreview((_) => [for (final at in points) OverlayPoint(at)]);
  final accepted = await context.input.confirm(message, defaultValue: true);
  context.input
    ..setPreview(null)
    ..setMarkers(const []);
  return accepted;
}

/// Adds [entities] in one transaction and reports what happened.
///
/// Returning the transaction on the result is what lets an AI turn be
/// summarised and undone as a unit, and what lets the UI select what was just
/// drawn without guessing at ids.
CommandResult commitDraw(
  CommandContext context,
  String label,
  List<CadEntity> entities, {
  String? message,
}) {
  if (entities.isEmpty) return const CommandResult.cancelled();
  final committed = context.edit(label, (transaction) {
    transaction.addAll(entities);
  });
  if (committed == null) {
    return const CommandResult.failed('Nothing was created.');
  }
  context.selection.replace(committed.change.added);
  return CommandResult(
    status: CommandStatus.ok,
    message:
        message ??
        '$label: ${committed.change.added.length} object(s) created.',
    data: {'ids': committed.change.added},
    transaction: committed,
  );
}

List<Vec2> pointList(Object? value) => CommandArgs.parsePoints(value);

List<OverlayShape> dimLinearOverlay(Vec2 first, Vec2 second, Vec2 cursor) {
  final mid = first.lerp(second, 0.5);
  final horizontal = (cursor - mid).y.abs() >= (cursor - mid).x.abs();
  final a = horizontal ? Vec2(first.x, cursor.y) : Vec2(cursor.x, first.y);
  final b = horizontal ? Vec2(second.x, cursor.y) : Vec2(cursor.x, second.y);
  return [OverlayLine(first, a), OverlayLine(second, b), OverlayLine(a, b)];
}

List<OverlayShape> dimAlignedOverlay(Vec2 first, Vec2 second, Vec2 cursor) {
  final length = first.distanceTo(second);
  if (length < 1e-9) return const [];
  final unit = (second - first) / length;
  final normal = unit.perpendicular;
  var offset = (cursor - first).dot(normal);
  if (offset.abs() < 1e-6) offset = length * 0.15;
  final a = first + normal * offset;
  final b = second + normal * offset;
  return [OverlayLine(first, a), OverlayLine(second, b), OverlayLine(a, b)];
}
