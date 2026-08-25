import 'package:fancad_ui/fancad_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a leftover flat model key becomes one default profile', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.aiModel: 'deepseek-chat',
      SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
      SettingsKeys.aiApiKey: 'sk-leftover',
    });
    final profiles = AssistantProfiles.read(settings);
    expect(profiles, hasLength(1));
    expect(profiles.single.id, AssistantProfile.defaultId);
    expect(profiles.single.model, 'deepseek-chat');
    expect(profiles.single.baseUrl, 'https://api.deepseek.com/v1');
    expect(profiles.single.apiKey, 'sk-leftover');
    expect(profiles.single.displayName, 'deepseek-chat');
    expect(AssistantProfiles.activeOf(settings).id, AssistantProfile.defaultId);
  });

  test('a leftover token count is compact, not a raw integer dump', () {
    expect(formatAssistantTokens(500), '500');
    expect(formatAssistantTokens(12400), '12.4k');
    expect(formatAssistantTokens(128000), '128k');
    expect(formatAssistantTokens(12400), isNot(contains('12400')));
  });
}
