// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'updater.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$buildInfoHash() => r'a48c33958b5490165dbb70fc3e1d9da5a05dd7cf';

/// See also [buildInfo].
@ProviderFor(buildInfo)
final buildInfoProvider = Provider<BuildInfo>.internal(
  buildInfo,
  name: r'buildInfoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$buildInfoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BuildInfoRef = ProviderRef<BuildInfo>;
String _$updateStartupDelayHash() =>
    r'48e60bf14a52b7efd9ec6ebde8eec5eb3a73c978';

/// How long the app waits after the first frame before checking. Tests set
/// this to zero so no timer outlives the widget tree.
///
/// Copied from [updateStartupDelay].
@ProviderFor(updateStartupDelay)
final updateStartupDelayProvider = Provider<Duration>.internal(
  updateStartupDelay,
  name: r'updateStartupDelayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateStartupDelayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdateStartupDelayRef = ProviderRef<Duration>;
String _$updateClientHash() => r'4c83b8113aac3215f69dd5becde056c9bb8d9658';

/// See also [updateClient].
@ProviderFor(updateClient)
final updateClientProvider = Provider<UpdateClient>.internal(
  updateClient,
  name: r'updateClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updateClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdateClientRef = ProviderRef<UpdateClient>;
String _$updatesDirectoryHash() => r'c66315f5fcad2ab9a0a6e5417e9d60b454009b27';

/// `<support>/updates`. Empty for an in-memory store (tests).
///
/// Copied from [updatesDirectory].
@ProviderFor(updatesDirectory)
final updatesDirectoryProvider = Provider<String>.internal(
  updatesDirectory,
  name: r'updatesDirectoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$updatesDirectoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UpdatesDirectoryRef = ProviderRef<String>;
String _$updateNotifierHash() => r'6453a4c79de31f2e78a3c7f517d6d3421903d766';

/// Checks, downloads and hands the update to the platform.
///
/// The feed is only a directory; the package refuses to download without a
/// signed manifest, so an unconfigured key leaves the UI in
/// [UpdatePhase.unconfigured] instead of offering an unsafe update.
///
/// Copied from [UpdateNotifier].
@ProviderFor(UpdateNotifier)
final updateNotifierProvider =
    NotifierProvider<UpdateNotifier, UpdateStateModel>.internal(
      UpdateNotifier.new,
      name: r'updateNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$updateNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UpdateNotifier = Notifier<UpdateStateModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
