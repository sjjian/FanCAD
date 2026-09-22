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
    final accounts = assistant.loadAccounts();
    expect(accounts.profiles, hasLength(1));
    expect(accounts.activeProfile.id, AssistantProfileModel.defaultId);
    expect(accounts.activeProfile.model, 'deepseek-chat');
    expect(accounts.activeProfile.baseUrl, 'https://api.deepseek.com/v1');
    expect(accounts.activeProfile.apiKey, 'sk-leftover');
    expect(accounts.activeProfile.displayName, 'deepseek-chat');
  });
}
