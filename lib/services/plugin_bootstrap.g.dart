// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_bootstrap.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pluginBootstrapHash() => r'94fefa221fc70036887262e9ea7dd5cbf4860c31';

/// Owns the bootstrap for the application's lifetime.
///
/// Copied from [pluginBootstrap].
@ProviderFor(pluginBootstrap)
final pluginBootstrapProvider = Provider<PluginBootstrap>.internal(
  pluginBootstrap,
  name: r'pluginBootstrapProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pluginBootstrapHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PluginBootstrapRef = ProviderRef<PluginBootstrap>;
String _$bundledPluginDirectoriesHash() =>
    r'db1e925ec8fc367f0a701cdd4436b0a08b9e416f';

/// Folders of extensions shipped with the application.
///
/// Copied from [bundledPluginDirectories].
@ProviderFor(bundledPluginDirectories)
final bundledPluginDirectoriesProvider = Provider<List<String>>.internal(
  bundledPluginDirectories,
  name: r'bundledPluginDirectoriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bundledPluginDirectoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BundledPluginDirectoriesRef = ProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
