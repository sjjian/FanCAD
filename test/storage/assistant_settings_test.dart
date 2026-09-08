import 'package:fancad/fancad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a leftover flat model key becomes one default profile', () {
    final settings = SettingsStore.inMemory({
      SettingsKeys.aiModel: 'deepseek-chat',
      SettingsKeys.aiBaseUrl: 'https://api.deepseek.com/v1',
      SettingsKeys.aiApiKey: 'sk-leftover',
    });
    final assistant = AssistantSettings(settings);
    final profiles = assistant.loadProfiles();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, AssistantProfile.defaultId);
    expect(profiles.single.model, 'deepseek-chat');
    expect(profiles.single.baseUrl, 'https://api.deepseek.com/v1');
    expect(profiles.single.apiKey, 'sk-leftover');
    expect(profiles.single.displayName, 'deepseek-chat');
    expect(assistant.activeProfile.id, AssistantProfile.defaultId);
  });
}
