// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

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
String _$pluginNotifierHash() => r'89605f10e30abf8b57b94a29331def770d0e95e3';

/// Discovered extensions and the host that loads them.
///
/// The pkg [PluginHost] stays on this notifier. [PluginModel] is the snapshot
/// the extensions panel selects.
///
/// Copied from [PluginNotifier].
@ProviderFor(PluginNotifier)
final pluginNotifierProvider =
    NotifierProvider<PluginNotifier, PluginModel>.internal(
      PluginNotifier.new,
      name: r'pluginNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pluginNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PluginNotifier = Notifier<PluginModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
