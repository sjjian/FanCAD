// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$settingsHash() => r'f384c96e21ee56518feae4e992884d0e11cd89da';

/// Riverpod wiring for the application.
///
/// Leaf stores live here. Each module Notifier is in its own file; screens
/// subscribe with `select`, not a second provider tree.
/// Provided by the app at startup, after settings have been loaded from disk.
///
/// Copied from [settings].
@ProviderFor(settings)
final settingsProvider = Provider<SettingsStore>.internal(
  settings,
  name: r'settingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$settingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SettingsRef = ProviderRef<SettingsStore>;
String _$appSettingsHash() => r'b68a7105a0731a82e51b069115db299577899396';

/// Service-internal bag. Screen watches typed providers, not this.
///
/// Copied from [appSettings].
@ProviderFor(appSettings)
final appSettingsProvider = Provider<AppSettings>.internal(
  appSettings,
  name: r'appSettingsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appSettingsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppSettingsRef = ProviderRef<AppSettings>;
String _$drawingFilesHash() => r'17296ba422f53f3bc908b95ec01d385e04628eec';

/// Drawing file access. Overridden in tests with an in-memory DWG adapter.
///
/// Copied from [drawingFiles].
@ProviderFor(drawingFiles)
final drawingFilesProvider = Provider<DrawingFileService>.internal(
  drawingFiles,
  name: r'drawingFilesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$drawingFilesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DrawingFilesRef = ProviderRef<DrawingFileService>;
String _$commandRegistryHash() => r'4cd054338bd2ebf82d8d94fc3662f6f6199e0756';

/// See also [commandRegistry].
@ProviderFor(commandRegistry)
final commandRegistryProvider = Provider<CommandRegistry>.internal(
  commandRegistry,
  name: r'commandRegistryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$commandRegistryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CommandRegistryRef = ProviderRef<CommandRegistry>;
String _$pluginsDirectoryHash() => r'883437af0aa766aa7633a91eeef02ee5dec57ab0';

/// Where user extensions live. Overridden at startup with a real path, and left
/// empty in tests so that a test run never scans the user's real folder.
///
/// Copied from [pluginsDirectory].
@ProviderFor(pluginsDirectory)
final pluginsDirectoryProvider = Provider<String>.internal(
  pluginsDirectory,
  name: r'pluginsDirectoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginsDirectoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginsDirectoryRef = ProviderRef<String>;
String _$pluginTransportHash() => r'6aa1cc9005914190bf303062e87331e9ec22a5ae';

/// The transport plugins run over. Overridden in tests with [LocalTransport].
///
/// Copied from [pluginTransport].
@ProviderFor(pluginTransport)
final pluginTransportProvider = Provider<PluginTransport>.internal(
  pluginTransport,
  name: r'pluginTransportProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginTransportHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginTransportRef = ProviderRef<PluginTransport>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
