import 'dart:async';
import 'dart:io';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_plugin_host/fancad_plugin_host.dart';
import 'package:flutter/foundation.dart';

import 'settings.dart';
import 'workspace.dart';

/// Owns the assistant session for the application.
///
/// The controller is a [ChangeNotifier] so the panel can rebuild on every
/// streamed token without the rest of the shell knowing an agent exists.
class AiController extends ChangeNotifier {
  AiController({
    required this.workspace,
    required this.settings,
    this.host,
  });

  final Workspace workspace;
  final SettingsStore settings;
  final PluginHost? host;

  final Conversation conversation = Conversation();

  bool _busy = false;
  String? _error;
  String _draft = '';

  bool get isBusy => _busy;
  String? get error => _error;
  String get draft => _draft;
  List<ChatMessage> get messages => conversation.visible;

  bool get isConfigured => _provider() != null;

  String get model =>
      settings.getString(SettingsKeys.aiModel, fallback: 'gpt-4o-mini');

  String get baseUrl => settings.getString(
    SettingsKeys.aiBaseUrl,
    fallback: 'https://api.openai.com/v1',
  );

  void setDraft(String value) {
    _draft = value;
    notifyListeners();
  }

  void setModel(String value) {
    settings.set(SettingsKeys.aiModel, value);
    notifyListeners();
  }

  void setBaseUrl(String value) {
    settings.set(SettingsKeys.aiBaseUrl, value);
    notifyListeners();
  }

  void setAutoApprove(bool value) {
    settings.set(SettingsKeys.aiAutoApprove, value);
    notifyListeners();
  }

  bool get autoApprove => settings.getBool(SettingsKeys.aiAutoApprove);

  void clear() {
    conversation.clear();
    _error = null;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Sends the draft, or [text] when supplied, and runs the agent loop.
  Future<void> send([String? text]) async {
    final message = (text ?? _draft).trim();
    if (message.isEmpty || _busy) return;
    final provider = _provider();
    if (provider == null) {
      _error =
          'No API key. Set the ${settings.getString(SettingsKeys.aiApiKeyRef, fallback: 'OPENAI_API_KEY')} '
          'environment variable, or point the assistant at a local endpoint.';
      notifyListeners();
      return;
    }
    final session = workspace.active?.session;
    if (session == null) {
      _error = 'Open a drawing first.';
      notifyListeners();
      return;
    }

    _draft = '';
    _busy = true;
    _error = null;
    notifyListeners();

    final typings = host == null
        ? null
        : buildTypeDeclarations(
            commands: workspace.commands.all,
            hostVersion: host!.hostVersion,
          );

    final agent = AgentLoop(
      provider: provider,
      registry: workspace.commands,
      execute: (id, args) => workspace.runHeadless(
        id,
        args: args,
        source: ChangeSource.ai,
        session: session,
      ),
      document: session.document,
      conversation: conversation,
      history: session.history,
      typings: typings,
      policy: ApprovalPolicy(autoApproveEdits: autoApprove),
      askApproval: (pending) => workspace.requestApprovalFor(
        pending.title,
        pending.details,
        pending.highlightIds,
      ),
      onDelta: (_) => notifyListeners(),
    );

    try {
      final turn = await agent.run(message);
      if (turn.error != null) _error = turn.error;
    } catch (error) {
      _error = '$error';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  LlmProvider? _provider() {
    final keyVar = settings.getString(
      SettingsKeys.aiApiKeyRef,
      fallback: 'OPENAI_API_KEY',
    );
    return OpenAiCompatibleProvider.fromEnvironment(
      baseUrl: baseUrl,
      model: model,
      apiKeyEnvVar: keyVar,
      environment: Platform.environment,
    );
  }
}
