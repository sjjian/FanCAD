// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appearanceNotifierHash() =>
    r'388b693deabed9760ac68e888b46921166af7637';

/// Theme and language. Not a layout pane.
///
/// Copied from [AppearanceNotifier].
@ProviderFor(AppearanceNotifier)
final appearanceNotifierProvider =
    NotifierProvider<AppearanceNotifier, AppearanceModel>.internal(
      AppearanceNotifier.new,
      name: r'appearanceNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$appearanceNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AppearanceNotifier = Notifier<AppearanceModel>;
String _$assistantAccountsNotifierHash() =>
    r'f488fc1280dc8825499920af25b80d40f84d08e2';

/// Saved assistant connections: model, endpoint, key, and auto-approve.
///
/// Copied from [AssistantAccountsNotifier].
@ProviderFor(AssistantAccountsNotifier)
final assistantAccountsNotifierProvider =
    NotifierProvider<
      AssistantAccountsNotifier,
      AssistantAccountsModel
    >.internal(
      AssistantAccountsNotifier.new,
      name: r'assistantAccountsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$assistantAccountsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AssistantAccountsNotifier = Notifier<AssistantAccountsModel>;
String _$mcpNotifierHash() => r'72d43619c0831d57931b7670f0e649a3fabecc5f';

/// MCP bind settings plus the localhost listener the stdio proxy connects to.
///
/// An in-memory settings store has no support directory. Starting a listener
/// then would write `~/.fancad/mcp.lock` from a test and steal the real app's
/// slot. Production always opens a file-backed store.
///
/// Copied from [McpNotifier].
@ProviderFor(McpNotifier)
final mcpNotifierProvider = NotifierProvider<McpNotifier, McpModel>.internal(
  McpNotifier.new,
  name: r'mcpNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$mcpNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$McpNotifier = Notifier<McpModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
