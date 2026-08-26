import '../models/assistant_chat.dart';
import '../models/assistant_profile.dart';
import 'settings.dart';

/// The assistant's slice of `settings.json`.
///
/// Workspace and the shell never see these keys. The controller loads models
/// here and writes them back; leftover flat `ai.model` rows still become one
/// profile until `ai.profiles` exists.
class AssistantSettings {
  AssistantSettings(this._store);

  final SettingsStore _store;

  static const int chatCap = 20;

  List<AssistantChat> loadChats() {
    final raw = _store.values[SettingsKeys.aiChats];
    if (raw is List && raw.isNotEmpty) {
      final parsed = <AssistantChat>[];
      for (final item in raw) {
        if (item is Map) parsed.add(AssistantChat.fromJson(item));
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return [AssistantChat(id: AssistantChat.defaultId)];
  }

  String activeChatId(List<AssistantChat> chats) {
    final id = _store.getString(SettingsKeys.aiActiveChat);
    if (chats.any((chat) => chat.id == id)) return id;
    return chats.first.id;
  }

  void saveChats(List<AssistantChat> chats, {required String activeId}) {
    _store.set(SettingsKeys.aiChats, [
      for (final chat in chats) chat.toJson(),
    ]);
    _store.set(SettingsKeys.aiActiveChat, activeId);
  }

  List<AssistantProfile> loadProfiles() {
    final raw = _store.values[SettingsKeys.aiProfiles];
    if (raw is List && raw.isNotEmpty) {
      final parsed = <AssistantProfile>[];
      for (final item in raw) {
        if (item is Map) {
          parsed.add(
            AssistantProfile.fromJson({
              for (final entry in item.entries) entry.key: entry.value,
            }),
          );
        }
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return [_fromFlat()];
  }

  AssistantProfile _fromFlat() {
    final model = _store.getString(
      SettingsKeys.aiModel,
      fallback: AssistantProfile.defaultModel,
    );
    final baseUrl = _store.getString(
      SettingsKeys.aiBaseUrl,
      fallback: AssistantProfile.defaultBaseUrl,
    );
    return AssistantProfile(
      id: AssistantProfile.defaultId,
      model: model.trim().isEmpty ? AssistantProfile.defaultModel : model,
      baseUrl: baseUrl.trim().isEmpty
          ? AssistantProfile.defaultBaseUrl
          : baseUrl,
      apiKey: _store.getString(SettingsKeys.aiApiKey),
    );
  }

  String activeProfileId(List<AssistantProfile> profiles) {
    final id = _store.getString(SettingsKeys.aiActiveProfile);
    if (profiles.any((profile) => profile.id == id)) return id;
    return profiles.first.id;
  }

  AssistantProfile get activeProfile {
    final profiles = loadProfiles();
    final id = activeProfileId(profiles);
    return profiles.firstWhere((profile) => profile.id == id);
  }

  void saveProfiles(
    List<AssistantProfile> profiles, {
    required String activeId,
  }) {
    _store.set(SettingsKeys.aiProfiles, [
      for (final profile in profiles) profile.toJson(),
    ]);
    _store.set(SettingsKeys.aiActiveProfile, activeId);
    final current = profiles.firstWhere(
      (profile) => profile.id == activeId,
      orElse: () => profiles.first,
    );
    _store.set(SettingsKeys.aiModel, current.model);
    _store.set(SettingsKeys.aiBaseUrl, current.baseUrl);
    _store.set(SettingsKeys.aiApiKey, current.apiKey);
  }

  String get apiKeyRef =>
      _store.getString(SettingsKeys.aiApiKeyRef, fallback: 'OPENAI_API_KEY');

  void setApiKeyRef(String value) =>
      _store.set(SettingsKeys.aiApiKeyRef, value);

  bool get autoApprove => _store.getBool(SettingsKeys.aiAutoApprove);

  void setAutoApprove(bool value) =>
      _store.set(SettingsKeys.aiAutoApprove, value);
}
