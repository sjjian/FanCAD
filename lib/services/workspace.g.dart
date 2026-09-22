// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$workspaceFileCommandsOverrideHash() =>
    r'017f164703ead4bb3b6f1213843f156cbec995ec';

/// Optional [FileCommands] used by headless tests that stub open / save.
///
/// Copied from [workspaceFileCommandsOverride].
@ProviderFor(workspaceFileCommandsOverride)
final workspaceFileCommandsOverrideProvider =
    Provider<WorkspaceFileCommandsFactory?>.internal(
      workspaceFileCommandsOverride,
      name: r'workspaceFileCommandsOverrideProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$workspaceFileCommandsOverrideHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WorkspaceFileCommandsOverrideRef =
    ProviderRef<WorkspaceFileCommandsFactory?>;
String _$workspaceNotifierHash() => r'ebff9bc2096cbe0262db916da3e498505e52e3df';

/// The application state: open documents, the command registry, and the wiring
/// that lets a command reach the UI.
///
/// This is the object that owns the "one write path" guarantee. Every mutation —
/// from a toolbar button, a typed command, a plugin, or the model — is a
/// [CommandRegistry.run] call routed through here, so there is exactly one place
/// where a change can be observed, logged, undone or refused.
///
/// Copied from [WorkspaceNotifier].
@ProviderFor(WorkspaceNotifier)
final workspaceNotifierProvider =
    NotifierProvider<WorkspaceNotifier, WorkspaceModel>.internal(
      WorkspaceNotifier.new,
      name: r'workspaceNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$workspaceNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$WorkspaceNotifier = Notifier<WorkspaceModel>;
String _$documentTabNotifierHash() =>
    r'484080755382eefbd0d2772f28a1cb042de8a581';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$DocumentTabNotifier
    extends BuildlessNotifier<DocumentTabModel> {
  late final String sessionId;

  DocumentTabModel build(String sessionId);
}

/// One open drawing, with everything that is per-tab rather than per-app.
///
/// A tab bundles the three controllers that have to agree about which drawing
/// is being looked at: the document session (content and undo), the viewport
/// (camera) and the tool controller (interaction). Keeping them together is
/// what makes switching tabs a single assignment rather than a resynchronisation
/// of three independent pieces of state.
///
/// [state] is only the tool prompt. Pan and tool frames tick [Listenable]
/// listeners and must not write Riverpod state.
///
/// Copied from [DocumentTabNotifier].
@ProviderFor(DocumentTabNotifier)
const documentTabNotifierProvider = DocumentTabNotifierFamily();

/// One open drawing, with everything that is per-tab rather than per-app.
///
/// A tab bundles the three controllers that have to agree about which drawing
/// is being looked at: the document session (content and undo), the viewport
/// (camera) and the tool controller (interaction). Keeping them together is
/// what makes switching tabs a single assignment rather than a resynchronisation
/// of three independent pieces of state.
///
/// [state] is only the tool prompt. Pan and tool frames tick [Listenable]
/// listeners and must not write Riverpod state.
///
/// Copied from [DocumentTabNotifier].
class DocumentTabNotifierFamily extends Family<DocumentTabModel> {
  /// One open drawing, with everything that is per-tab rather than per-app.
  ///
  /// A tab bundles the three controllers that have to agree about which drawing
  /// is being looked at: the document session (content and undo), the viewport
  /// (camera) and the tool controller (interaction). Keeping them together is
  /// what makes switching tabs a single assignment rather than a resynchronisation
  /// of three independent pieces of state.
  ///
  /// [state] is only the tool prompt. Pan and tool frames tick [Listenable]
  /// listeners and must not write Riverpod state.
  ///
  /// Copied from [DocumentTabNotifier].
  const DocumentTabNotifierFamily();

  /// One open drawing, with everything that is per-tab rather than per-app.
  ///
  /// A tab bundles the three controllers that have to agree about which drawing
  /// is being looked at: the document session (content and undo), the viewport
  /// (camera) and the tool controller (interaction). Keeping them together is
  /// what makes switching tabs a single assignment rather than a resynchronisation
  /// of three independent pieces of state.
  ///
  /// [state] is only the tool prompt. Pan and tool frames tick [Listenable]
  /// listeners and must not write Riverpod state.
  ///
  /// Copied from [DocumentTabNotifier].
  DocumentTabNotifierProvider call(String sessionId) {
    return DocumentTabNotifierProvider(sessionId);
  }

  @override
  DocumentTabNotifierProvider getProviderOverride(
    covariant DocumentTabNotifierProvider provider,
  ) {
    return call(provider.sessionId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'documentTabNotifierProvider';
}

/// One open drawing, with everything that is per-tab rather than per-app.
///
/// A tab bundles the three controllers that have to agree about which drawing
/// is being looked at: the document session (content and undo), the viewport
/// (camera) and the tool controller (interaction). Keeping them together is
/// what makes switching tabs a single assignment rather than a resynchronisation
/// of three independent pieces of state.
///
/// [state] is only the tool prompt. Pan and tool frames tick [Listenable]
/// listeners and must not write Riverpod state.
///
/// Copied from [DocumentTabNotifier].
class DocumentTabNotifierProvider
    extends NotifierProviderImpl<DocumentTabNotifier, DocumentTabModel> {
  /// One open drawing, with everything that is per-tab rather than per-app.
  ///
  /// A tab bundles the three controllers that have to agree about which drawing
  /// is being looked at: the document session (content and undo), the viewport
  /// (camera) and the tool controller (interaction). Keeping them together is
  /// what makes switching tabs a single assignment rather than a resynchronisation
  /// of three independent pieces of state.
  ///
  /// [state] is only the tool prompt. Pan and tool frames tick [Listenable]
  /// listeners and must not write Riverpod state.
  ///
  /// Copied from [DocumentTabNotifier].
  DocumentTabNotifierProvider(String sessionId)
    : this._internal(
        () => DocumentTabNotifier()..sessionId = sessionId,
        from: documentTabNotifierProvider,
        name: r'documentTabNotifierProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$documentTabNotifierHash,
        dependencies: DocumentTabNotifierFamily._dependencies,
        allTransitiveDependencies:
            DocumentTabNotifierFamily._allTransitiveDependencies,
        sessionId: sessionId,
      );

  DocumentTabNotifierProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sessionId,
  }) : super.internal();

  final String sessionId;

  @override
  DocumentTabModel runNotifierBuild(covariant DocumentTabNotifier notifier) {
    return notifier.build(sessionId);
  }

  @override
  Override overrideWith(DocumentTabNotifier Function() create) {
    return ProviderOverride(
      origin: this,
      override: DocumentTabNotifierProvider._internal(
        () => create()..sessionId = sessionId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sessionId: sessionId,
      ),
    );
  }

  @override
  NotifierProviderElement<DocumentTabNotifier, DocumentTabModel>
  createElement() {
    return _DocumentTabNotifierProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentTabNotifierProvider && other.sessionId == sessionId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sessionId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin DocumentTabNotifierRef on NotifierProviderRef<DocumentTabModel> {
  /// The parameter `sessionId` of this provider.
  String get sessionId;
}

class _DocumentTabNotifierProviderElement
    extends NotifierProviderElement<DocumentTabNotifier, DocumentTabModel>
    with DocumentTabNotifierRef {
  _DocumentTabNotifierProviderElement(super.provider);

  @override
  String get sessionId => (origin as DocumentTabNotifierProvider).sessionId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
