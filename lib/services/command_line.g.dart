// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'command_line.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$commandLineHistoryLimitOverrideHash() =>
    r'b67517cfb9311a3ba54960fccbeca67b510baf05';

/// Optional history cap used by headless tests that check truncation.
///
/// Copied from [commandLineHistoryLimitOverride].
@ProviderFor(commandLineHistoryLimitOverride)
final commandLineHistoryLimitOverrideProvider = Provider<int?>.internal(
  commandLineHistoryLimitOverride,
  name: r'commandLineHistoryLimitOverrideProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$commandLineHistoryLimitOverrideHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CommandLineHistoryLimitOverrideRef = ProviderRef<int?>;
String _$commandLineNotifierHash() =>
    r'abc17807a51cba445f05c055bd1e9548f6e2c089';

/// The state behind the command line and command history.
///
/// Modelled as a notifier rather than as widget state because commands,
/// plugins and the AI agent all write to it, and none of them should need a
/// [BuildContext] to do so.
///
/// Copied from [CommandLineNotifier].
@ProviderFor(CommandLineNotifier)
final commandLineNotifierProvider =
    NotifierProvider<CommandLineNotifier, CommandLineModel>.internal(
      CommandLineNotifier.new,
      name: r'commandLineNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$commandLineNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CommandLineNotifier = Notifier<CommandLineModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
