import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:test/test.dart';

void main() {
  test('the catalog advertises one fancad tool, not every command', () {
    final registry = CommandRegistry();
    registry.register(
      CommandDescriptor(
        id: 'draw.line',
        title: 'Line',
        description: 'Draws a segment.',
        params: const [
          ParamSpec(name: 'start', type: ParamType.point),
          ParamSpec(name: 'end', type: ParamType.point),
        ],
        handler: (_) async => const CommandResult.ok(),
      ),
    );
    registry.register(
      CommandDescriptor(
        id: 'view.zoomIn',
        title: 'Zoom In',
        aiExposure: AiExposure.hidden,
        handler: (_) async => const CommandResult.ok(),
      ),
    );

    final tools = const CommandToolCatalog().toolsOf(registry);
    expect(tools, hasLength(1));
    expect(tools.single.name, fancadToolName);
    expect(tools.single.parameters['required'], ['action']);
    expect(tools.single.description, contains(fancadCallExample));
    expect(tools.single.description, contains('never inside args'));
  });

  test('a dotted path resolves back to the original command', () {
    final registry = CommandRegistry();
    registry.register(
      CommandDescriptor(
        id: 'query.summary',
        title: 'Summary',
        risk: CommandRisk.readOnly,
        handler: (_) async => const CommandResult.ok(),
      ),
    );
    expect(
      const CommandToolCatalog().commandFor(registry, 'query.summary')?.id,
      'query.summary',
    );
    expect(const CommandToolCatalog().commandFor(registry, 'query_summary'), isNull);
  });

  test('highlight ids are collected from the usual argument names', () {
    expect(
      highlightIdsOf({
        'ids': [3, 5],
        'target': 9,
      }),
      [3, 5, 9],
    );
  });

  test('highlight ids accept strings, maps and nested lists, not junk', () {
    expect(
      highlightIdsOf({
        'id': '12',
        'selection': [
          {'id': 3.0},
          'nope',
          [4],
        ],
        'other': true,
      }),
      [12, 3, 4],
    );
  });

  test('a leftover cancel becomes a failed tool error the model can read', () {
    final command = CommandDescriptor(
      id: 'draw.polyline',
      title: 'Polyline',
      description: 'Draws a connected sequence of segments.',
      params: const [
        ParamSpec(name: 'points', type: ParamType.points, required: false),
      ],
      handler: (_) async => const CommandResult.ok(),
    );

    final leftover = encodeAssistantToolResult(
      const CommandResult.cancelled(),
      command,
    );
    expect(leftover['status'], 'failed');
    expect(
      leftover['error'],
      contains('fancad({action: run, path: draw.polyline, args: {points?}})'),
    );
    expect(leftover['error'], contains('arguments were missing'));
    expect(leftover['error'], isNot(contains('Cancelled')));
    expect(leftover['message'], leftover['error']);

    final explicit = encodeAssistantToolResult(
      const CommandResult.failed(
        'Polyline needs points as [[x, y], [x, y], ...].',
      ),
      command,
    );
    expect(explicit['status'], 'failed');
    expect(explicit['error'], contains('[[x, y]'));
    expect(explicit['error'], isNot(contains('Cancelled')));
  });
}
