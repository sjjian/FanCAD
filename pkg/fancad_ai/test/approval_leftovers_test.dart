import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

Future<CommandResult> _noop(CommandContext context) async =>
    const CommandResult.ok();

void main() {
  test('leftover tool arguments do not appear in approval details', () {
    const pending = PendingChangeSet(
      calls: [
        LlmToolCall(
          id: '1',
          name: 'draw_ellipse',
          arguments: {
            'center': [0, 55],
            'axisEnd': [0, 66],
            'otherRadius': 13,
            'mystery': 'leftover',
          },
        ),
        LlmToolCall(
          id: '2',
          name: 'draw_ellipse',
          arguments: {
            'center': [10, 0],
          },
        ),
      ],
      commands: [
        CommandDescriptor(
          id: 'draw.ellipse',
          title: 'Ellipse',
          handler: _noop,
        ),
        CommandDescriptor(
          id: 'draw.ellipse',
          title: 'Ellipse',
          handler: _noop,
        ),
      ],
    );

    expect(pending.groupedTitles, ['Ellipse ×2']);
    expect(pending.details, 'Ellipse ×2');
    expect(pending.details, isNot(contains('center')));
    expect(pending.details, isNot(contains('mystery')));
    expect(pending.details, isNot(contains('otherRadius')));
  });

  test('a leftover draw batch does not wait for approval', () {
    final registry = CommandRegistry()
      ..register(
        CommandDescriptor(
          id: 'draw.ellipse',
          title: 'Ellipse',
          handler: _noop,
        ),
      )
      ..register(
        CommandDescriptor(
          id: 'edit.erase',
          title: 'Erase',
          risk: CommandRisk.destructive,
          handler: _noop,
        ),
      );

    const policy = ApprovalPolicy();
    expect(
      policy.pendingOf(
        const [
          LlmToolCall(
            id: '1',
            name: 'draw_ellipse',
            arguments: {
              'center': [0, 0],
              'leftover': true,
            },
          ),
        ],
        registry,
      ),
      isNull,
    );

    final pending = policy.pendingOf(
      const [
        LlmToolCall(id: '1', name: 'draw_ellipse', arguments: {}),
        LlmToolCall(
          id: '2',
          name: 'edit_erase',
          arguments: {
            'ids': [3],
            'mystery': 'leftover',
          },
        ),
      ],
      registry,
    )!;
    expect(pending.calls, hasLength(1));
    expect(pending.calls.single.name, 'edit_erase');
    expect(pending.details, isNot(contains('mystery')));
    expect(pending.details, isNot(contains('center')));
  });
}
