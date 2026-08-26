import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AiController controller() {
    final settings = SettingsStore.inMemory();
    settings.set(SettingsKeys.aiApiKeyRef, 'FANCAD_TEST_MISSING_KEY');
    settings.set(SettingsKeys.aiApiKey, '');
    final workspace = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      drawing: DrawingSettings(settings),
    );
    final created = AiController(workspace: workspace, assistant: AssistantSettings(settings));
    addTearDown(created.dispose);
    addTearDown(workspace.dispose);
    return created;
  }

  PendingChangeSet leftoverPending() => const PendingChangeSet(
    calls: [
      LlmToolCall(
        id: '1',
        name: 'draw_ellipse',
        arguments: {
          'center': [0, 55],
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
      CommandDescriptor(id: 'draw.ellipse', title: 'Ellipse', handler: _noop),
      CommandDescriptor(id: 'draw.ellipse', title: 'Ellipse', handler: _noop),
    ],
  );

  testWidgets(
    'leftover pending args stay off the card; a click outside does not decline',
    (tester) async {
      final ai = controller();
      await tester.pumpWidget(
        MaterialApp(
          theme: FanCadTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Row(
              children: [
                const Expanded(child: SizedBox.expand()),
                SizedBox(width: 360, child: AiPanel(controller: ai)),
              ],
            ),
          ),
        ),
      );

      ai.conversation.addUser('画个小乌龟');
      final decision = ai.debugAskApproval(leftoverPending());
      await tester.pump();

      expect(find.text('画个小乌龟'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byKey(const Key('assistant-approval-card')),
        ),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Allow 2 changes?'), findsOneWidget);
      expect(find.text('Ellipse ×2'), findsOneWidget);
      expect(find.textContaining('center'), findsNothing);
      expect(find.textContaining('mystery'), findsNothing);
      expect(find.textContaining('leftover'), findsNothing);

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(ai.pendingApproval, isNotNull);
      expect(find.byKey(const Key('assistant-approval-card')), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-approval-continue')));
      await tester.pump();
      expect(await decision, isTrue);
      expect(find.byKey(const Key('assistant-approval-card')), findsNothing);
    },
  );
}

Future<CommandResult> _noop(CommandContext context) async =>
    const CommandResult.ok();
