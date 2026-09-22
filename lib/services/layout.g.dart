// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'layout.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$layoutNotifierHash() => r'a08098199becfdbcb35ada5e4d476f10ff6f453e';

/// Workbench chrome: open panes, the sidebar view, and the three sizes.
///
/// Dragging a sash updates [state] only. The file is written when the drag
/// ends, and when a pane is opened, closed, or switched.
///
/// Copied from [LayoutNotifier].
@ProviderFor(LayoutNotifier)
final layoutNotifierProvider =
    NotifierProvider<LayoutNotifier, LayoutModel>.internal(
      LayoutNotifier.new,
      name: r'layoutNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$layoutNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$LayoutNotifier = Notifier<LayoutModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
