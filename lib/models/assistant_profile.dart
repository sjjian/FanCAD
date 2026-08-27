// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'assistant_profile.freezed.dart';
part 'assistant_profile.g.dart';

/// One assistant connection: model, endpoint and key.
@freezed
abstract class AssistantProfile with _$AssistantProfile {
  const AssistantProfile._();

  @JsonSerializable()
  const factory AssistantProfile({
    required String id,
    @Default('') String label,
    @Default('gpt-4o-mini') String model,
    @Default('https://api.openai.com/v1') String baseUrl,
    @Default('') String apiKey,
  }) = _AssistantProfile;

  static const String defaultId = 'default';
  static const String defaultModel = 'gpt-4o-mini';
  static const String defaultBaseUrl = 'https://api.openai.com/v1';

  /// Settings list and the composer chip use this, not the raw model id.
  String get displayName {
    final named = label.trim();
    if (named.isNotEmpty) return named;
    final modelName = model.trim();
    return modelName.isEmpty ? defaultModel : modelName;
  }

  factory AssistantProfile.fromJson(Map<Object?, Object?> raw) =>
      _$AssistantProfileFromJson(_assistantProfileWire(raw));
}

Map<String, dynamic> _assistantProfileWire(Map<Object?, Object?> raw) {
  String read(String key, [String fallback = '']) {
    final value = raw[key];
    return value is String ? value : fallback;
  }

  final id = read('id').trim();
  return {
    'id': id.isEmpty ? AssistantProfile.defaultId : id,
    'label': read('label'),
    'model': read('model', AssistantProfile.defaultModel),
    'baseUrl': read('baseUrl', AssistantProfile.defaultBaseUrl),
    'apiKey': read('apiKey'),
  };
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
