// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'assistant.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$assistantNotifierHash() => r'ecd06e64f64d003602457587a0a56abd076857c9';

/// Owns the assistant session for the application.
///
/// Streamed tokens mutate [Conversation] in place, so [AssistantModel.transcriptEpoch]
/// bumps on each delta and the panel can rebuild without the rest of the shell
/// knowing an agent exists.
///
/// Copied from [AssistantNotifier].
@ProviderFor(AssistantNotifier)
final assistantNotifierProvider =
    NotifierProvider<AssistantNotifier, AssistantModel>.internal(
      AssistantNotifier.new,
      name: r'assistantNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$assistantNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AssistantNotifier = Notifier<AssistantModel>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
