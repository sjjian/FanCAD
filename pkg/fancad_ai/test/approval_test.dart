import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:test/test.dart';

CommandDescriptor _command({
  required String id,
  required String title,
  CommandRisk risk = CommandRisk.edit,
  AiExposure aiExposure = AiExposure.tool,
}) => CommandDescriptor(
  id: id,
  title: title,
  risk: risk,
  aiExposure: aiExposure,
  handler: (_) async => const CommandResult.ok(),
);

void main() {
  late CommandRegistry registry;

  setUp(() {
    registry = CommandRegistry()
      ..register(
        _command(
          id: 'query.summary',
          title: 'Summary',
          risk: CommandRisk.readOnly,
        ),
      )
      ..register(_command(id: 'draw.line', title: 'Line'))
      ..register(
        _command(
          id: 'edit.erase',
          title: 'Erase',
          risk: CommandRisk.destructive,
        ),
      )
      ..register(
        _command(
          id: 'file.save',
          title: 'Save',
          aiExposure: AiExposure.approvalRequired,
        ),
      );
  });

  test('read-only runs free; edits and deletes still ask by default', () {
    const policy = ApprovalPolicy();
    expect(
      policy.requiresApproval(registry.find('query.summary')!),
      isFalse,
    );
    expect(policy.requiresApproval(registry.find('draw.line')!), isTrue);
    expect(policy.requiresApproval(registry.find('edit.erase')!), isTrue);
    expect(policy.requiresApproval(registry.find('file.save')!), isTrue);

    const auto = ApprovalPolicy(autoApproveEdits: true);
    expect(auto.requiresApproval(registry.find('draw.line')!), isFalse);
    expect(auto.requiresApproval(registry.find('edit.erase')!), isTrue);
  });

  test('pendingOf keeps only the calls that need a decision', () {
    const policy = ApprovalPolicy(autoApproveEdits: true);
    expect(
      policy.pendingOf(
        const [
          LlmToolCall(id: '1', name: 'query_summary', arguments: {}),
          LlmToolCall(id: '2', name: 'draw_line', arguments: {}),
        ],
        registry,
      ),
      isNull,
    );

    final pending = policy.pendingOf(
      const [
        LlmToolCall(id: '1', name: 'query_summary', arguments: {}),
        LlmToolCall(
          id: '2',
          name: 'edit_erase',
          arguments: {
            'ids': [4, 7],
          },
        ),
        LlmToolCall(id: '3', name: 'unknown_tool', arguments: {}),
      ],
      registry,
    )!;
    expect(pending.calls, hasLength(1));
    expect(pending.title, 'Allow Erase?');
    expect(pending.details, contains('ids=[4, 7]'));
    expect(pending.highlightIds, [4, 7]);
    expect(pending.isNotEmpty, isTrue);
  });

  test('several pending calls share one title and list each command', () {
    const pending = PendingChangeSet(
      calls: [
        LlmToolCall(id: '1', name: 'edit_erase', arguments: {}),
        LlmToolCall(id: '2', name: 'file_save', arguments: {'path': '/a.dxf'}),
      ],
      commands: [
        CommandDescriptor(
          id: 'edit.erase',
          title: 'Erase',
          handler: _noop,
        ),
        CommandDescriptor(
          id: 'file.save',
          title: 'Save',
          handler: _noop,
        ),
      ],
      highlightIds: [1],
    );
    expect(pending.title, 'Allow 2 changes?');
    expect(pending.details, contains('Save (path=/a.dxf)'));
    expect(pending.details, contains('Affects 1 object(s).'));
  });
}

Future<CommandResult> _noop(CommandContext context) async =>
    const CommandResult.ok();
