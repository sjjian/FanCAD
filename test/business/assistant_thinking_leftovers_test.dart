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
      settings: settings,
    );
    final created = AiController(workspace: workspace, settings: settings);
    addTearDown(created.dispose);
    addTearDown(workspace.dispose);
    return created;
  }

  testWidgets('leftover reasoning paints a thinking card, not the reply', (
    tester,
  ) async {
    final ai = controller();
    ai.conversation.appendReasoningDelta('plan the tail');
    ai.conversation.appendAssistantDelta('Drew it.');

    await tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 360, child: AiPanel(controller: ai)),
        ),
      ),
    );

    expect(find.byKey(const Key('assistant-thinking-card')), findsOneWidget);
    expect(find.text('Thinking'), findsOneWidget);
    expect(find.text('plan the tail'), findsNothing);
    expect(find.textContaining('Drew it.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assistant-thinking-card')));
    await tester.pump();
    expect(find.text('plan the tail'), findsOneWidget);
    expect(find.text('Working…'), findsNothing);

    final list = tester.widget<ListView>(
      find.byWidgetPredicate(
        (widget) =>
            widget is ListView && widget.scrollDirection == Axis.vertical,
      ),
    );
    final padding = list.padding!.resolve(TextDirection.ltr);
    expect(padding.bottom, greaterThan(FanCadTokens.space2));
    expect(
      padding.bottom,
      assistantTranscriptTail(tester.getSize(find.byWidget(list)).height),
    );
  });
}
