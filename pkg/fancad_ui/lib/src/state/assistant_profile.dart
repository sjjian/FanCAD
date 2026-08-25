import 'package:meta/meta.dart';

import 'settings.dart';

/// One assistant connection: model, endpoint and key.
@immutable
class AssistantProfile {
  const AssistantProfile({
    required this.id,
    this.label = '',
    this.model = defaultModel,
    this.baseUrl = defaultBaseUrl,
    this.apiKey = '',
  });

  static const String defaultId = 'default';
  static const String defaultModel = 'gpt-4o-mini';
  static const String defaultBaseUrl = 'https://api.openai.com/v1';

  final String id;
  final String label;
  final String model;
  final String baseUrl;
  final String apiKey;

  /// Settings list and the composer chip use this, not the raw model id.
  String get displayName {
    final named = label.trim();
    if (named.isNotEmpty) return named;
    final modelName = model.trim();
    return modelName.isEmpty ? defaultModel : modelName;
  }

  AssistantProfile copyWith({
    String? label,
    String? model,
    String? baseUrl,
    String? apiKey,
  }) {
    return AssistantProfile(
      id: id,
      label: label ?? this.label,
      model: model ?? this.model,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'model': model,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
  };

  factory AssistantProfile.fromJson(Map<Object?, Object?> raw) {
    String read(String key, [String fallback = '']) {
      final value = raw[key];
      return value is String ? value : fallback;
    }

    final id = read('id').trim();
    return AssistantProfile(
      id: id.isEmpty ? defaultId : id,
      label: read('label'),
      model: read('model', defaultModel),
      baseUrl: read('baseUrl', defaultBaseUrl),
      apiKey: read('apiKey'),
    );
  }
}

/// Reads leftover flat `ai.model` keys as one profile until `ai.profiles` exists.
class AssistantProfiles {
  const AssistantProfiles._();

  static List<AssistantProfile> read(SettingsStore settings) {
    final raw = settings.values[SettingsKeys.aiProfiles];
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
    return [fromFlat(settings)];
  }

  static AssistantProfile fromFlat(SettingsStore settings) {
    final model = settings.getString(
      SettingsKeys.aiModel,
      fallback: AssistantProfile.defaultModel,
    );
    final baseUrl = settings.getString(
      SettingsKeys.aiBaseUrl,
      fallback: AssistantProfile.defaultBaseUrl,
    );
    return AssistantProfile(
      id: AssistantProfile.defaultId,
      model: model.trim().isEmpty ? AssistantProfile.defaultModel : model,
      baseUrl: baseUrl.trim().isEmpty
          ? AssistantProfile.defaultBaseUrl
          : baseUrl,
      apiKey: settings.getString(SettingsKeys.aiApiKey),
    );
  }

  static String activeId(
    SettingsStore settings,
    List<AssistantProfile> profiles,
  ) {
    final id = settings.getString(SettingsKeys.aiActiveProfile);
    if (profiles.any((profile) => profile.id == id)) return id;
    return profiles.first.id;
  }

  static AssistantProfile activeOf(SettingsStore settings) {
    final profiles = read(settings);
    final id = activeId(settings, profiles);
    return profiles.firstWhere((profile) => profile.id == id);
  }
}

/// Compact token label for the composer ring, leftover `12400` → `12.4k`.
String formatAssistantTokens(int tokens) {
  if (tokens < 1000) return '$tokens';
  final tenths = (tokens / 100).round() / 10;
  if (tenths >= 100 || tenths == tenths.roundToDouble()) {
    return '${tenths.round()}k';
  }
  return '${tenths}k';
}
