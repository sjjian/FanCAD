import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai_controller.dart';
import '../../services/ops_host.dart';
import '../../services/providers.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// Pages inside the settings dialog.
enum SettingsTab { general, assistant, mcp }

const _settingsRouteName = 'fancad.settings';

ValueNotifier<SettingsTab>? _openSettingsTab;

/// Whether the settings dialog is already on screen.
@visibleForTesting
bool get settingsDialogIsOpen => _openSettingsTab != null;

@visibleForTesting
void debugResetSettingsDialog() {
  _openSettingsTab = null;
}

SettingsTab settingsTabFromPanelId(String panelId) {
  return switch (panelId) {
    'preferences:assistant' => SettingsTab.assistant,
    'preferences:mcp' => SettingsTab.mcp,
    _ => SettingsTab.general,
  };
}

bool isPreferencesPanel(String panelId) =>
    panelId == 'preferences' || panelId.startsWith('preferences:');

/// Opens the settings dialog, or switches its page if it is already up.
///
/// A second call must not stack another modal: the title bar, the assistant
/// pane and `workbench.preferences` all share this entry, and two dialogs
/// would hide the first one's live writes.
Future<void> showSettingsDialog(
  BuildContext context, {
  SettingsTab initialTab = SettingsTab.general,
}) {
  final existing = _openSettingsTab;
  if (existing != null) {
    existing.value = initialTab;
    return Future<void>.value();
  }
  final tab = ValueNotifier(initialTab);
  _openSettingsTab = tab;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    routeSettings: const RouteSettings(name: _settingsRouteName),
    builder: (context) => SettingsDialog(tab: tab),
  ).whenComplete(() {
    if (identical(_openSettingsTab, tab)) {
      _openSettingsTab = null;
    }
    tab.dispose();
  });
}

/// The application-wide settings surface.
///
/// Writes go through the shell and assistant views so a theme or language
/// change is visible before the dialog closes. There is no Save: the store
/// already debounces to disk, and a discarded draft would fight that.
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key, required this.tab});

  final ValueListenable<SettingsTab> tab;

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late final TextEditingController _label;
  late final TextEditingController _model;
  late final TextEditingController _endpoint;
  late final TextEditingController _apiKey;
  late final TextEditingController _mcpPort;
  late final TextEditingController _mcpAllowlist;
  late final AiController _ai;
  late final McpConfig _mcp;

  @override
  void initState() {
    super.initState();
    _ai = ref.read(aiControllerProvider);
    _mcp = ref.read(mcpConfigProvider.notifier);
    _label = TextEditingController(text: _ai.activeProfile.label);
    _model = TextEditingController(text: _ai.model);
    _endpoint = TextEditingController(text: _ai.baseUrl);
    _apiKey = TextEditingController(text: _ai.apiKey);
    final bind = ref.read(mcpConfigProvider);
    _mcpPort = TextEditingController(text: '${bind.port}');
    _mcpAllowlist = TextEditingController(text: bind.allowlist.join(', '));
    widget.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    _flushAssistantFields();
    _flushMcpFields();
    _label.dispose();
    _model.dispose();
    _endpoint.dispose();
    _apiKey.dispose();
    _mcpPort.dispose();
    _mcpAllowlist.dispose();
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
  }

  void _flushMcpFields() {
    _mcp.setPortFromText(_mcpPort.text);
    _mcp.setAllowlistFromText(_mcpAllowlist.text);
  }

  void _flushAssistantFields() {
    _ai.setProfileLabel(_label.text);
    final model = _model.text.trim();
    if (model.isNotEmpty && model != _ai.model) _ai.setModel(model);
    final endpoint = _endpoint.text.trim();
    if (endpoint.isNotEmpty && endpoint != _ai.baseUrl)
      _ai.setBaseUrl(endpoint);
    _ai.setApiKey(_apiKey.text);
  }

  void _syncAssistantFields() {
    _label.text = _ai.activeProfile.label;
    _model.text = _ai.model;
    _endpoint.text = _ai.baseUrl;
    _apiKey.text = _ai.apiKey;
  }

  void _selectProfile(String id) {
    _flushAssistantFields();
    _ai.selectProfile(id);
    _syncAssistantFields();
    setState(() {});
  }

  void _addProfile() {
    _flushAssistantFields();
    _ai.addProfile();
    _syncAssistantFields();
    setState(() {});
  }

  void _removeProfile() {
    _ai.removeProfile(_ai.activeProfile.id);
    _syncAssistantFields();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final tab = widget.tab.value;
    // Watch so a language or theme write rebuilds this dialog in place.
    ref.watch(languageProvider);
    ref.watch(themeBrightnessProvider);
    return Dialog(
      key: const Key('settings-dialog'),
      backgroundColor: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
        side: BorderSide(color: tokens.borderStrong),
      ),
      child: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FanCadTokens.space4,
                FanCadTokens.space3,
                FanCadTokens.space2,
                FanCadTokens.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settings,
                      style: tokens.bodyStyle.copyWith(fontSize: 15),
                    ),
                  ),
                  ShellIconButton(
                    icon: Icons.close,
                    tooltip: l10n.close,
                    iconSize: FanCadTokens.iconSmall,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FanCadTokens.space4,
              ),
              child: Row(
                children: [
                  _SettingsTabButton(
                    tabKey: const Key('settings-tab-general'),
                    label: l10n.settings_tab_general,
                    selected: tab == SettingsTab.general,
                    onTap: () => _openSettingsTab?.value = SettingsTab.general,
                  ),
                  const SizedBox(width: FanCadTokens.space4),
                  _SettingsTabButton(
                    tabKey: const Key('settings-tab-assistant'),
                    label: l10n.settings_tab_assistant,
                    selected: tab == SettingsTab.assistant,
                    onTap: () =>
                        _openSettingsTab?.value = SettingsTab.assistant,
                  ),
                  const SizedBox(width: FanCadTokens.space4),
                  _SettingsTabButton(
                    tabKey: const Key('settings-tab-mcp'),
                    label: l10n.settings_tab_mcp,
                    selected: tab == SettingsTab.mcp,
                    onTap: () => _openSettingsTab?.value = SettingsTab.mcp,
                  ),
                ],
              ),
            ),
            const ShellHairline(),
            Expanded(
              child: IndexedStack(
                index: switch (tab) {
                  SettingsTab.general => 0,
                  SettingsTab.assistant => 1,
                  SettingsTab.mcp => 2,
                },
                children: [
                  _GeneralPage(),
                  _AssistantPage(
                    label: _label,
                    model: _model,
                    endpoint: _endpoint,
                    apiKey: _apiKey,
                    onCommit: _flushAssistantFields,
                    onSelectProfile: _selectProfile,
                    onAddProfile: _addProfile,
                    onRemoveProfile: _removeProfile,
                  ),
                  _McpPage(
                    port: _mcpPort,
                    allowlist: _mcpAllowlist,
                    onCommit: _flushMcpFields,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTabButton extends StatelessWidget {
  const _SettingsTabButton({
    required this.tabKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ShellTab(
      key: tabKey,
      style: ShellTabStyle.underline,
      selected: selected,
      onTap: onTap,
      child: Text(
        label,
        style: tokens.bodyStyle.copyWith(
          color: selected ? tokens.accent : tokens.textMuted,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _GeneralPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(languageProvider);
    final theme = ref.watch(themeBrightnessProvider);
    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        SettingsSection(
          title: l10n.settings_appearance,
          children: [
            SettingsLabeledRow(
              label: l10n.language,
              child: Row(
                children: [
                  SettingsRadioOption(
                    key: const Key('settings-language-en'),
                    label: 'English',
                    selected: language == FanCadLanguage.english,
                    onTap: () => ref
                        .read(languageProvider.notifier)
                        .setLanguage(FanCadLanguage.english),
                  ),
                  const SizedBox(width: FanCadTokens.space2),
                  SettingsRadioOption(
                    key: const Key('settings-language-zh'),
                    label: '简体中文',
                    selected: language == FanCadLanguage.chinese,
                    onTap: () => ref
                        .read(languageProvider.notifier)
                        .setLanguage(FanCadLanguage.chinese),
                  ),
                ],
              ),
            ),
            SettingsLabeledRow(
              label: l10n.theme,
              child: Row(
                children: [
                  SettingsRadioOption(
                    key: const Key('settings-theme-dark'),
                    label: l10n.theme_dark,
                    selected: theme == Brightness.dark,
                    onTap: () => ref
                        .read(themeBrightnessProvider.notifier)
                        .setBrightness(Brightness.dark),
                  ),
                  const SizedBox(width: FanCadTokens.space2),
                  SettingsRadioOption(
                    key: const Key('settings-theme-light'),
                    label: l10n.theme_light,
                    selected: theme == Brightness.light,
                    onTap: () => ref
                        .read(themeBrightnessProvider.notifier)
                        .setBrightness(Brightness.light),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _McpPage extends ConsumerWidget {
  const _McpPage({
    required this.port,
    required this.allowlist,
    required this.onCommit,
  });

  final TextEditingController port;
  final TextEditingController allowlist;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final bind = ref.watch(mcpConfigProvider);
    final endpoint = ref.watch(mcpEndpointProvider);
    final localHint = bind.local
        ? l10n.settings_mcp_local_on
        : l10n.settings_mcp_local_off;
    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        SettingsSection(
          title: l10n.settings_mcp,
          children: [
            SettingsToggle(
              key: const Key('settings-mcp-enabled'),
              label: l10n.settings_mcp_enable,
              value: bind.enabled,
              onChanged: ref.read(mcpConfigProvider.notifier).setEnabled,
              description: bind.enabled
                  ? l10n.settings_mcp_on
                  : l10n.settings_mcp_off,
              tooltip: bind.enabled
                  ? l10n.settings_mcp_on
                  : l10n.settings_mcp_off,
            ),
            SettingsToggle(
              key: const Key('settings-mcp-local'),
              label: l10n.settings_mcp_local,
              value: bind.local,
              onChanged: ref.read(mcpConfigProvider.notifier).setLocal,
              description: localHint,
              tooltip: localHint,
            ),
            SettingsLabeledRow(
              label: l10n.settings_mcp_port,
              child: SettingsTextField(
                key: const Key('settings-mcp-port'),
                controller: port,
                hintText: '17830',
                style: tokens.monoStyle,
                onSubmitted: (_) => onCommit(),
              ),
            ),
            SettingsLabeledRow(
              label: l10n.settings_mcp_allowlist,
              child: SettingsTextField(
                key: const Key('settings-mcp-allowlist'),
                controller: allowlist,
                hintText: l10n.settings_mcp_allowlist_hint,
                style: tokens.monoStyle,
                onSubmitted: (_) => onCommit(),
              ),
            ),
            _CopyableMcpUrl(endpoint: endpoint),
          ],
        ),
      ],
    );
  }
}

class _CopyableMcpUrl extends StatefulWidget {
  const _CopyableMcpUrl({required this.endpoint});

  final McpClientEndpoint endpoint;

  @override
  State<_CopyableMcpUrl> createState() => _CopyableMcpUrlState();
}

class _CopyableMcpUrlState extends State<_CopyableMcpUrl> {
  bool _copied = false;

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final url = widget.endpoint.url;
    final config = widget.endpoint.clientConfig;
    return SettingsLabeledRow(
      label: l10n.settings_mcp_url,
      child: Row(
        children: [
          Expanded(
            child: Text(
              url,
              key: const Key('settings-mcp-url'),
              style: tokens.monoStyle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ShellIconButton(
            key: const Key('settings-mcp-copy'),
            icon: Icons.copy,
            tooltip: _copied ? l10n.copied_text(url) : l10n.click_to_copy,
            iconSize: FanCadTokens.iconSmall,
            onPressed: () => _copy(config),
          ),
        ],
      ),
    );
  }
}

class _AssistantPage extends ConsumerWidget {
  const _AssistantPage({
    required this.label,
    required this.model,
    required this.endpoint,
    required this.apiKey,
    required this.onCommit,
    required this.onSelectProfile,
    required this.onAddProfile,
    required this.onRemoveProfile,
  });

  final TextEditingController label;
  final TextEditingController model;
  final TextEditingController endpoint;
  final TextEditingController apiKey;
  final VoidCallback onCommit;
  final ValueChanged<String> onSelectProfile;
  final VoidCallback onAddProfile;
  final VoidCallback onRemoveProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final ai = ref.watch(aiControllerProvider);
    return ListenableBuilder(
      listenable: ai,
      builder: (context, _) {
        final approveHint = ai.autoApprove
            ? l10n.edits_without_asking
            : l10n.ask_before_edits;
        return ListView(
          padding: const EdgeInsets.all(FanCadTokens.space4),
          children: [
            SettingsSection(
              title: l10n.assistant_profiles,
              children: [
                Wrap(
                  spacing: FanCadTokens.space2,
                  runSpacing: FanCadTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final profile in ai.profiles)
                      ShellBadge(
                        key: Key('settings-profile-${profile.id}'),
                        text: profile.displayName,
                        selected: profile.id == ai.activeProfile.id,
                        onTap: () => onSelectProfile(profile.id),
                      ),
                    ShellIconButton(
                      key: const Key('settings-add-profile'),
                      icon: Icons.add,
                      tooltip: l10n.add_assistant_profile,
                      iconSize: FanCadTokens.iconSmall,
                      onPressed: onAddProfile,
                    ),
                    if (ai.profiles.length > 1)
                      ShellIconButton(
                        key: const Key('settings-remove-profile'),
                        icon: Icons.delete_outline,
                        tooltip: l10n.remove_assistant_profile,
                        iconSize: FanCadTokens.iconSmall,
                        destructive: true,
                        onPressed: onRemoveProfile,
                      ),
                  ],
                ),
                SettingsLabeledRow(
                  label: l10n.assistant_profile_name,
                  child: SettingsTextField(
                    key: const Key('settings-profile-label'),
                    controller: label,
                    hintText: ai.activeProfile.displayName,
                    onChanged: ai.setProfileLabel,
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FanCadTokens.space4),
            SettingsSection(
              title: l10n.settings_connection,
              children: [
                SettingsLabeledRow(
                  label: l10n.model,
                  child: SettingsTextField(
                    key: const Key('settings-model-field'),
                    controller: model,
                    hintText: l10n.model_id,
                    style: tokens.monoStyle,
                    onChanged: (value) {
                      final next = value.trim();
                      if (next.isNotEmpty) ai.setModel(next);
                    },
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
                SettingsLabeledRow(
                  label: l10n.endpoint,
                  child: SettingsTextField(
                    controller: endpoint,
                    hintText: 'https://api.deepseek.com/v1',
                    style: tokens.monoStyle,
                    onChanged: (value) {
                      final next = value.trim();
                      if (next.isNotEmpty) ai.setBaseUrl(next);
                    },
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
                SettingsLabeledRow(
                  label: l10n.settings_api_key,
                  child: SettingsTextField(
                    key: const Key('settings-api-key'),
                    controller: apiKey,
                    hintText: 'sk-…',
                    obscureText: true,
                    style: tokens.monoStyle,
                    onChanged: ai.setApiKey,
                    onSubmitted: (_) => onCommit(),
                  ),
                ),
                SettingsToggle(
                  label: l10n.auto_approve,
                  value: ai.autoApprove,
                  onChanged: ai.setAutoApprove,
                  description: approveHint,
                  tooltip: approveHint,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
