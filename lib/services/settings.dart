import 'dart:async';
import 'dart:io';

import 'package:fancad_ai/fancad_ai.dart';
import 'package:fancad_core/fancad_core.dart';
import 'package:fancad_ops/fancad_ops.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../ai/skills/bundled.dart';
import '../models/settings.dart';
import '../storage/assistant.dart';
import '../storage/settings.dart';
import 'providers.dart';
import 'workspace.dart';

part 'settings.g.dart';

/// Theme and language. Not a layout pane.
@Riverpod(keepAlive: true)
class AppearanceNotifier extends _$AppearanceNotifier {
  AppearanceStore get _settings => ref.read(appSettingsProvider).appearance;

  @override
  AppearanceModel build() => ref.watch(appSettingsProvider).appearance.load();

  void toggleTheme() {
    setPreference(
      state.theme == ThemePreference.light
          ? ThemePreference.dark
          : ThemePreference.light,
    );
  }

  void setPreference(ThemePreference value) {
    if (state.theme == value) return;
    state = state.copyWith(theme: value);
    _settings.save(state);
  }

  void setLanguage(String value) {
    final language = FanCadLanguage.parse(value);
    if (state.language == language) return;
    state = state.copyWith(language: language);
    _settings.save(state);
  }
}

/// Saved assistant connections: model, endpoint, key, and auto-approve.
@Riverpod(keepAlive: true)
class AssistantAccountsNotifier extends _$AssistantAccountsNotifier {
  AssistantStore get _assistant => ref.read(appSettingsProvider).assistant;
  Workspace get _workspace => ref.read(workspaceNotifierProvider.notifier);

  bool get _turnRunning => ref.read(workspaceNotifierProvider).assistantBusy;

  @override
  AssistantAccountsModel build() =>
      ref.read(appSettingsProvider).assistant.loadAccounts();

  void setModel(String value) {
    final next = value.trim();
    if (next.isEmpty || next == state.activeProfile.model) return;
    _writeActive((profile) => profile.copyWith(model: next));
  }

  void setBaseUrl(String value) {
    final next = value.trim();
    if (next.isEmpty || next == state.activeProfile.baseUrl) return;
    _writeActive((profile) => profile.copyWith(baseUrl: next));
  }

  void setAutoApprove(bool value) {
    if (value == state.autoApprove) return;
    state = state.copyWith(autoApprove: value);
    _assistant.saveAccounts(state);
  }

  void setApiKey(String value) {
    final next = value.trim();
    if (next == state.activeProfile.apiKey) return;
    _writeActive((profile) => profile.copyWith(apiKey: next));
  }

  void setApiKeyRef(String value) {
    final next = value.trim();
    if (next.isEmpty || next == state.apiKeyRef) return;
    state = state.copyWith(apiKeyRef: next);
    _assistant.saveAccounts(state);
  }

  void setProfileLabel(String value) {
    if (value == state.activeProfile.label) return;
    _writeActive((profile) => profile.copyWith(label: value));
  }

  void selectProfile(String id) {
    if (_turnRunning) return;
    if (id == state.activeProfile.id) return;
    final all = state.profiles;
    if (!all.any((profile) => profile.id == id)) return;
    _persist(all, activeId: id);
  }

  void addProfile() {
    if (_turnRunning) return;
    final profile = state.activeProfile;
    final created = AssistantProfileModel(
      id: 'p${DateTime.now().microsecondsSinceEpoch}',
      model: profile.model,
      baseUrl: profile.baseUrl,
    );
    _persist([...state.profiles, created], activeId: created.id);
  }

  void removeProfile(String id) {
    if (_turnRunning) return;
    final all = [...state.profiles]..removeWhere((profile) => profile.id == id);
    if (all.isEmpty) return;
    final activeId = state.activeProfile.id;
    final nextId = id == activeId ? all.first.id : activeId;
    _persist(all, activeId: nextId);
  }

  /// Hits `{baseUrl}/models` with this card's key. Notifies success or failure.
  Future<void> testProfile(AssistantProfileModel profile) async {
    final provider = OpenAiCompatibleProvider.fromEnvironment(
      baseUrl: profile.baseUrl,
      model: profile.model,
      apiKey: profile.apiKey,
      apiKeyEnvVar: state.apiKeyRef,
      environment: Platform.environment,
    );
    if (provider == null) {
      _workspace.notify(
        'No API key. Paste one in Settings, '
        'or point the endpoint at a local server.',
        isError: true,
      );
      return;
    }
    try {
      await provider.probe();
      _workspace.notify('${profile.displayName} is reachable.');
    } on LlmException catch (error) {
      _workspace.notify(error.message, isError: true);
    }
  }

  void _writeActive(
    AssistantProfileModel Function(AssistantProfileModel) update,
  ) {
    final all = [...state.profiles];
    final index = all.indexWhere(
      (profile) => profile.id == state.activeProfile.id,
    );
    final at = index < 0 ? 0 : index;
    all[at] = update(all[at]);
    _persist(all, activeId: all[at].id);
  }

  void _persist(List<AssistantProfileModel> all, {required String activeId}) {
    state = state.copyWith(profiles: all, activeProfileId: activeId);
    _assistant.saveAccounts(state);
  }
}

/// MCP bind settings plus the localhost listener the stdio proxy connects to.
///
/// An in-memory settings store has no support directory. Starting a listener
/// then would write `~/.fancad/mcp.lock` from a test and steal the real app's
/// slot. Production always opens a file-backed store.
@Riverpod(keepAlive: true)
class McpNotifier extends _$McpNotifier {
  McpStore get _mcp => ref.read(appSettingsProvider).mcp;
  Workspace get _workspace => ref.read(workspaceNotifierProvider.notifier);

  McpHttpServer? _server;
  List<String> _lockPaths = const [];

  @override
  McpModel build() {
    final mcp = ref.watch(appSettingsProvider).mcp;
    ref.onDispose(() {
      unawaited(stop());
    });
    Future<void>.microtask(_syncListen);
    return mcp.load();
  }

  String get url =>
      _server?.url ??
      fancadMcpUrl(host: state.bind.bindHost, port: state.bind.port);

  void setEnabled(bool value) {
    if (state.bind.enabled == value) return;
    state = state.copyWith(bind: state.bind.copyWith(enabled: value));
    _mcp.save(state);
    _syncListen();
  }

  void setPort(int value) {
    final port = parseMcpPort('$value', fallback: state.bind.port);
    if (state.bind.port == port) return;
    state = state.copyWith(bind: state.bind.copyWith(port: port));
    _mcp.save(state);
    _syncListen();
  }

  void setPortFromText(String raw) =>
      setPort(parseMcpPort(raw, fallback: state.bind.port));

  void setLocal(bool value) {
    if (state.bind.local == value) return;
    state = state.copyWith(bind: state.bind.copyWith(local: value));
    _mcp.save(state);
    _syncListen();
  }

  void setAllowlist(List<String> value) {
    if (_sameAllowlist(state.bind.allowlist, value)) return;
    state = state.copyWith(bind: state.bind.copyWith(allowlist: value));
    _mcp.save(state);
    _syncListen();
  }

  void setAllowlistFromText(String raw) => setAllowlist(parseMcpAllowlist(raw));

  OperationCatalog catalog() => OperationCatalog()
    ..addProvider(
      CommandOperationProvider(
        registry: _workspace.commands,
        execute: (id, args, {tab}) => _workspace.runHeadless(
          id,
          args: args,
          source: ChangeSource.mcp,
          tab: tab,
        ),
      ),
    )
    ..addProvider(
      HostOperationProvider(bundledHostTools(bundledSkillRegistry())),
    );

  /// Starts the HTTP listener. Tests pass [lockPaths] and [port] so an
  /// in-memory store can still bind without writing `~/.fancad/mcp.lock`.
  Future<void> start({List<String>? lockPaths, int? port}) async {
    await stop();
    final bind = state.bind;
    final listenPort = port ?? bind.port;
    final token = state.token;
    _lockPaths = lockPaths ?? _defaultLockPaths();
    final dispatcher = OpsDispatcher(catalog());
    final session = McpSession(
      dispatch: (request) async {
        final intercepted = await _approve(dispatcher.catalog, request);
        return intercepted ?? await dispatcher.dispatch(request);
      },
    );
    final server = McpHttpServer(
      session: session,
      token: token,
      allowlist: bind.local ? const [] : bind.allowlist,
    );
    _server = server;
    final bound = await server.start(host: bind.bindHost, port: listenPort);
    if (_lockPaths.isEmpty) return;
    final lock = McpLock(port: bound, token: token, pid: pid);
    for (final path in _lockPaths) {
      await McpLock.write(path, lock);
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.stop();
    for (final path in _lockPaths) {
      await McpLock.remove(path);
    }
    _lockPaths = const [];
  }

  void _syncListen() {
    if (!state.bind.enabled) {
      unawaited(stop());
      return;
    }
    final paths = _defaultLockPaths();
    if (paths.isEmpty) return;
    unawaited(start(lockPaths: paths));
  }

  List<String> _defaultLockPaths() {
    final support = ref.read(settingsProvider).file?.parent.path;
    if (support == null || support.isEmpty) return const [];
    return {
      defaultMcpLockPath(),
      '$support${Platform.pathSeparator}mcp.lock',
    }.toList();
  }

  Future<Map<String, Object?>?> _approve(
    OperationCatalog catalog,
    OpsRequest request,
  ) async {
    if (request.action != OpsAction.run || !request.hasPath) return null;
    final operation = catalog.find(request.path);
    if (operation == null) return null;
    if (operation.risk != CommandRisk.destructive) return null;
    final drawing = _workspace.findDrawing(request.tab);
    final drawingTitle = drawing?.title.trim() ?? '';
    final prompt = drawingTitle.isEmpty
        ? 'Allow ${operation.title}?'
        : 'Allow ${operation.title} on "$drawingTitle"?';
    final allowed = await _workspace.requestApprovalFor(
      prompt,
      operation.description.isEmpty ? operation.id : operation.description,
      highlightIdsOf(request.args),
    );
    if (allowed) return null;
    return {'status': 'cancelled', 'message': 'The user declined this change.'};
  }

  static bool _sameAllowlist(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
