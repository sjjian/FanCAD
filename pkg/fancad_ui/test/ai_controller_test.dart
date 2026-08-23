import 'package:fancad_dwg/fancad_dwg.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Workspace workspace({SettingsStore? settings}) {
    final created = Workspace(
      commands: CommandRegistry(),
      importer: DrawingImporter(backend: MemoryDrawingBackend()),
      settings: settings ?? SettingsStore.inMemory(),
    );
    addTearDown(created.dispose);
    return created;
  }

  AiController controller({SettingsStore? settings}) {
    final store = settings ?? SettingsStore.inMemory();
    store.set(SettingsKeys.aiApiKeyRef, 'FANCAD_TEST_MISSING_KEY');
    final created = AiController(
      workspace: workspace(settings: store),
      settings: store,
    );
    addTearDown(created.dispose);
    return created;
  }

  test('model, endpoint and auto-approve persist in settings', () {
    final ai = controller();
    var ticks = 0;
    ai.addListener(() => ticks++);

    ai.setDraft('draw a line');
    ai.setModel('gpt-test');
    ai.setBaseUrl('http://127.0.0.1:9/v1');
    ai.setAutoApprove(true);

    expect(ai.draft, 'draw a line');
    expect(ai.model, 'gpt-test');
    expect(ai.baseUrl, 'http://127.0.0.1:9/v1');
    expect(ai.autoApprove, isTrue);
    expect(ai.settings.getString(SettingsKeys.aiModel), 'gpt-test');
    expect(ticks, 4);
  });

  test(
    'an empty send is ignored and a missing key is an error, not a hang',
    () async {
      final ai = controller();
      await ai.send('   ');
      expect(ai.error, isNull);
      expect(ai.isBusy, isFalse);
      expect(ai.messages, isEmpty);

      ai.setDraft('draw a circle');
      await ai.send();
      expect(ai.isConfigured, isFalse);
      expect(ai.error, contains('FANCAD_TEST_MISSING_KEY'));
      expect(ai.isBusy, isFalse);
      expect(ai.draft, 'draw a circle');
    },
  );

  test('clear drops a leftover error so the next turn starts clean', () async {
    final ai = controller();
    await ai.send('hello');
    expect(ai.error, isNotNull);

    ai.clear();
    expect(ai.error, isNull);
    expect(ai.messages, isEmpty);
  });
}
