// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$mcpNotifierHash() => r'07332bd87db2bcb5d15e0318506d6907cc350111';

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
