import 'package:fancad/fancad.dart';
import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AiController controller() {
    final settings = SettingsStore.inMemory({
      SettingsKeys.aiModel: 'deepseek-chat',
      SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
      SettingsKeys.aiApiKey: 'sk-one',
    });
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

  Future<void> pumpPanel(WidgetTester tester, AiController ai) {
    return tester.pumpWidget(
      MaterialApp(
        theme: FanCadTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 360, child: AiPanel(controller: ai)),
        ),
      ),
    );
  }

  testWidgets('composer leftover shows the profile and a send key', (
    tester,
  ) async {
    final ai = controller();
    await pumpPanel(tester, ai);

    expect(find.byKey(const Key('assistant-composer-model')), findsOneWidget);
    expect(find.text('deepseek-chat'), findsWidgets);
    expect(find.byKey(const Key('assistant-composer-send')), findsOneWidget);
    expect(find.byKey(const Key('assistant-open-settings')), findsOneWidget);
    expect(find.text('ASSISTANT'), findsNothing);
    expect(find.byKey(const Key('assistant-composer-stop')), findsNothing);
    expect(find.byKey(const Key('assistant-composer-context')), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).minLines, 2);
  });

  testWidgets('picking a leftover profile swaps the live connection', (
    tester,
  ) async {
    final ai = controller();
    ai.addProfile();
    ai.setModel('gpt-4o-mini');
    ai.setBaseUrl('https://api.openai.com/v1');
    ai.setApiKey('sk-two');
    await pumpPanel(tester, ai);

    await tester.tap(find.byKey(const Key('assistant-composer-model')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('assistant-profile-${ai.profiles.first.id}')),
    );
    await tester.pumpAndSettle();

    expect(ai.model, 'deepseek-chat');
    expect(ai.baseUrl, 'https://api.deepseek.com/v1');
    expect(ai.apiKey, 'sk-one');
  });

  testWidgets('a leftover busy turn shows stop and keeps the profile pinned', (
    tester,
  ) async {
    final ai = controller();
    ai.addProfile();
    ai.debugSetBusy(true);
    await pumpPanel(tester, ai);

    expect(find.byKey(const Key('assistant-composer-stop')), findsOneWidget);
    expect(find.byKey(const Key('assistant-composer-send')), findsNothing);
    expect(find.text('Add a follow-up'), findsOneWidget);

    final pinned = ai.activeProfile.id;
    await tester.tap(find.byKey(const Key('assistant-composer-model')));
    await tester.pump();
    expect(
      find.byKey(Key('assistant-profile-${ai.profiles.first.id}')),
      findsNothing,
    );
    expect(ai.activeProfile.id, pinned);
  });

  testWidgets('a leftover usage ring tooltip is compact, not raw JSON', (
    tester,
  ) async {
    final ai = controller();
    ai.debugSetUsage(const LlmUsage(promptTokens: 12400, completionTokens: 12));
    await pumpPanel(tester, ai);

    final meter = tester.widget<AssistantContextMeter>(
      find.byType(AssistantContextMeter),
    );
    expect(meter.usage?.promptTokens, 12400);

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('assistant-composer-context')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, '12.4k / 128k');
    expect(tooltip.message, isNot(contains('prompt_tokens')));
    expect(tooltip.message, isNot(contains('12400')));
  });
}
