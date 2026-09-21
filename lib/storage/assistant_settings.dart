import '../models/assistant.dart';
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

  List<AssistantChatModel> loadChats() {
    final raw = _store.values[SettingsKeys.aiChats];
    if (raw is List && raw.isNotEmpty) {
      final parsed = <AssistantChatModel>[];
      for (final item in raw) {
        if (item is Map) parsed.add(AssistantChatModel.fromJson(item));
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return [AssistantChatModel(id: AssistantChatModel.defaultId)];
  }

  String activeChatId(List<AssistantChatModel> chats) {
    final id = _store.getString(SettingsKeys.aiActiveChat);
    if (chats.any((chat) => chat.id == id)) return id;
    return chats.first.id;
  }

  void saveChats(List<AssistantChatModel> chats, {required String activeId}) {
    _store.set(SettingsKeys.aiChats, [
      for (final chat in chats) chat.toJson(),
    ]);
    _store.set(SettingsKeys.aiActiveChat, activeId);
  }

  List<AssistantProfileModel> loadProfiles() {
    final raw = _store.values[SettingsKeys.aiProfiles];
    if (raw is List && raw.isNotEmpty) {
      final parsed = <AssistantProfileModel>[];
      for (final item in raw) {
        if (item is Map) {
          parsed.add(
            AssistantProfileModel.fromJson({
              for (final entry in item.entries) entry.key: entry.value,
            }),
          );
        }
      }
      if (parsed.isNotEmpty) return parsed;
    }
    return [_fromFlat()];
  }

  AssistantProfileModel _fromFlat() {
    final model = _store.getString(
      SettingsKeys.aiModel,
      fallback: AssistantProfileModel.defaultModel,
    );
    final baseUrl = _store.getString(
      SettingsKeys.aiBaseUrl,
      fallback: AssistantProfileModel.defaultBaseUrl,
    );
    return AssistantProfileModel(
      id: AssistantProfileModel.defaultId,
      model: model.trim().isEmpty ? AssistantProfileModel.defaultModel : model,
      baseUrl: baseUrl.trim().isEmpty
          ? AssistantProfileModel.defaultBaseUrl
          : baseUrl,
      apiKey: _store.getString(SettingsKeys.aiApiKey),
    );
  }

  String activeProfileId(List<AssistantProfileModel> profiles) {
    final id = _store.getString(SettingsKeys.aiActiveProfile);
    if (profiles.any((profile) => profile.id == id)) return id;
    return profiles.first.id;
  }

  AssistantProfileModel get activeProfile {
    final profiles = loadProfiles();
    final id = activeProfileId(profiles);
    return profiles.firstWhere((profile) => profile.id == id);
  }

  void saveProfiles(
    List<AssistantProfileModel> profiles, {
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
