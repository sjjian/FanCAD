import '../models/assistant.dart';
import '../models/settings.dart';
import 'settings.dart';

/// The assistant's slice of `settings.json`.
///
/// Chat and profile keys stay separate from the dock. Whether the dock is
/// open, and how wide it is, live on the workbench layout. Leftover flat
/// `ai.model` rows still become one profile until `ai.profiles` exists.
abstract interface class AssistantStore {
  AssistantAccountsModel loadAccounts();

  void saveAccounts(AssistantAccountsModel value);

  List<AssistantChatModel> loadChats();

  String activeChatId(List<AssistantChatModel> chats);

  void saveChats(List<AssistantChatModel> chats, {required String activeId});
}

class AssistantSettings implements AssistantStore {
  AssistantSettings(this._store);

  final SettingsStore _store;

  static const int chatCap = 20;

  @override
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

  @override
  String activeChatId(List<AssistantChatModel> chats) {
    final id = _store.getString(SettingsKeys.aiActiveChat);
    if (chats.any((chat) => chat.id == id)) return id;
    return chats.first.id;
  }

  @override
  void saveChats(List<AssistantChatModel> chats, {required String activeId}) {
    _store.set(SettingsKeys.aiChats, [for (final chat in chats) chat.toJson()]);
    _store.set(SettingsKeys.aiActiveChat, activeId);
  }

  @override
  AssistantAccountsModel loadAccounts() {
    final profiles = _loadProfiles();
    return AssistantAccountsModel(
      profiles: profiles,
      activeProfileId: activeProfileId(profiles),
      apiKeyRef: _store.getString(
        SettingsKeys.aiApiKeyRef,
        fallback: 'OPENAI_API_KEY',
      ),
      autoApprove: _store.getBool(SettingsKeys.aiAutoApprove),
    );
  }

  @override
  void saveAccounts(AssistantAccountsModel value) {
    _writeProfiles(value.profiles, activeId: value.activeProfileId);
    _store.set(SettingsKeys.aiApiKeyRef, value.apiKeyRef);
    _store.set(SettingsKeys.aiAutoApprove, value.autoApprove);
  }

  List<AssistantProfileModel> _loadProfiles() {
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

  void _writeProfiles(
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
}
