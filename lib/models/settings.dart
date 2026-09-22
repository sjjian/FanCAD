// ignore_for_file: invalid_annotation_target

import 'package:fancad_ops/fancad_ops.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// Supported UI languages, stored the same way OpenHare does: `en` and `zh`.
class FanCadLanguage {
  const FanCadLanguage._();

  static const String english = 'en';
  static const String chinese = 'zh';

  static const List<String> supported = [english, chinese];

  /// Maps leftover or regional tags onto a supported language.
  ///
  /// `zh_CN`, `zh-Hans` and `ZH` are Chinese. `en-US` is English. Anything
  /// else, including a blank leftover, falls back to English so the window
  /// still has strings.
  static String parse(String? raw, {String fallback = english}) {
    final value = (raw ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('_', '-')
        .replaceAll(' ', '');
    if (value.isEmpty) return fallback;
    final language = value.split('-').first;
    if (language == chinese) return chinese;
    if (language == english) return english;
    return fallback;
  }
}

/// Stored theme choice. `system` follows the OS; the other two pin a scheme.
enum ThemePreference {
  dark,
  light,
  system;

  static const ThemePreference fallback = ThemePreference.dark;

  /// Maps a leftover settings string onto a known choice.
  static ThemePreference parse(
    String? raw, {
    ThemePreference fallback = fallback,
  }) {
    return switch ((raw ?? '').trim().toLowerCase()) {
      'light' => ThemePreference.light,
      'system' => ThemePreference.system,
      'dark' => ThemePreference.dark,
      _ => fallback,
    };
  }

  /// Wire value written to `settings.json`.
  String get id => name;
}

/// Drafting toggles written to `settings.json`.
///
/// Snap chrome on screen lives on the workspace store. This is only the saved
/// copy, and it is not a Riverpod state.
@freezed
abstract class DrawingModel with _$DrawingModel {
  const factory DrawingModel({
    @Default([]) List<String> recentFiles,
    @Default(true) bool showGrid,
    @Default(true) bool snapEnabled,
    @Default([]) List<String> snapModes,
    @Default(false) bool ortho,
    @Default(true) bool polar,

    /// 45 degrees. The HUD offers a few other steps; this is the stored one.
    @Default(0.7853981633974483) double polarIncrement,
  }) = _DrawingModel;
}

/// Theme and language. Layout panes live on their own stores.
@freezed
abstract class AppearanceModel with _$AppearanceModel {
  const factory AppearanceModel({
    @Default(ThemePreference.fallback) ThemePreference theme,
    @Default(FanCadLanguage.english) String language,
  }) = _AppearanceModel;
}

/// Application-layer store of MCP bind settings.
@freezed
abstract class McpModel with _$McpModel {
  const McpModel._();

  const factory McpModel({
    required McpBindModel bind,
    @Default('') String token,
  }) = _McpModel;

  McpClientEndpointModel get endpoint => McpClientEndpointModel(
    url: fancadMcpUrl(host: bind.advertisedHost, port: bind.port),
    token: token,
  );
}

/// Bind settings the MCP tab writes and the host reads.
@freezed
abstract class McpBindModel with _$McpBindModel {
  const McpBindModel._();

  const factory McpBindModel({
    required bool enabled,
    required int port,
    required bool local,
    required List<String> allowlist,
  }) = _McpBindModel;

  String get bindHost => local ? '127.0.0.1' : '0.0.0.0';

  /// Cursor on this machine always uses loopback; remote clients replace the host.
  String get advertisedHost => '127.0.0.1';
}

/// URL and token a Cursor MCP config should use.
@freezed
abstract class McpClientEndpointModel with _$McpClientEndpointModel {
  const McpClientEndpointModel._();

  const factory McpClientEndpointModel({
    required String url,
    required String token,
  }) = _McpClientEndpointModel;

  String get clientConfig => fancadMcpClientConfig(url: url, token: token);
}

/// One assistant connection: model, endpoint and key.
@freezed
abstract class AssistantProfileModel with _$AssistantProfileModel {
  const AssistantProfileModel._();

  @JsonSerializable()
  const factory AssistantProfileModel({
    required String id,
    @Default('') String label,
    @Default('gpt-4o-mini') String model,
    @Default('https://api.openai.com/v1') String baseUrl,
    @Default('') String apiKey,
  }) = _AssistantProfileModel;

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

  factory AssistantProfileModel.fromJson(Map<Object?, Object?> raw) =>
      _$AssistantProfileModelFromJson(_assistantProfileWire(raw));
}

/// Saved assistant connections, and whether edits are approved automatically.
@freezed
abstract class AssistantAccountsModel with _$AssistantAccountsModel {
  const AssistantAccountsModel._();

  const factory AssistantAccountsModel({
    @Default([]) List<AssistantProfileModel> profiles,
    @Default(AssistantProfileModel.defaultId) String activeProfileId,
    @Default('OPENAI_API_KEY') String apiKeyRef,
    @Default(false) bool autoApprove,
  }) = _AssistantAccountsModel;

  AssistantProfileModel get activeProfile {
    for (final profile in profiles) {
      if (profile.id == activeProfileId) return profile;
    }
    return profiles.first;
  }
}

Map<String, dynamic> _assistantProfileWire(Map<Object?, Object?> raw) {
  String read(String key, [String fallback = '']) {
    final value = raw[key];
    return value is String ? value : fallback;
  }

  final id = read('id').trim();
  return {
    'id': id.isEmpty ? AssistantProfileModel.defaultId : id,
    'label': read('label'),
    'model': read('model', AssistantProfileModel.defaultModel),
    'baseUrl': read('baseUrl', AssistantProfileModel.defaultBaseUrl),
    'apiKey': read('apiKey'),
  };
}
