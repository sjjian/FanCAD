// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_editor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$pluginEditorNotifierHash() =>
    r'819d1abcc0154abd1849088d788e5a4c0e78cf1b';

/// The built-in extension editor: which file to open, and a request counter so
/// a second edit of the same file still reloads it.
///
/// Global and independent of the workspace service. `plugins.edit` writes
/// here; the panel listens.
///
/// Copied from [PluginEditorNotifier].
@ProviderFor(PluginEditorNotifier)
final pluginEditorNotifierProvider =
    NotifierProvider<PluginEditorNotifier, PluginEditorModel>.internal(
      PluginEditorNotifier.new,
      name: r'pluginEditorNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$pluginEditorNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$PluginEditorNotifier = Notifier<PluginEditorModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
