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
}
