import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/settings.dart';
import '../../services/settings.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// Pages inside the settings dialog.
enum SettingsTab { general, assistant, models, mcp }

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
    'preferences:models' => SettingsTab.models,
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
    useSafeArea: false,
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
class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key, required this.tab});

  final ValueListenable<SettingsTab> tab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bounds = Size(constraints.maxWidth, constraints.maxHeight);
        if (!bounds.isFinite || bounds.isEmpty) {
          return const SizedBox.shrink();
        }
        const size = Size(800, 640);
        void close() {
          final navigator = Navigator.maybeOf(context);
          if (navigator != null && navigator.canPop()) navigator.pop();
        }

        return SizedBox.expand(
          key: const Key('settings-dialog'),
          child: Stack(
            children: [
              FanCadCanvasWindow(
                name: 'settings',
                title: l10n.settings,
                origin: Offset(
                  (bounds.width - size.width) / 2,
                  (bounds.height - size.height) / 2,
                ),
                bounds: bounds,
                initialSize: size,
                minSize: const Size(520, 400),
                onClose: close,
                onBarrierTap: close,
                child: _SettingsBody(tab: tab),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  const _SettingsBody({required this.tab});

  final ValueListenable<SettingsTab> tab;

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late final TextEditingController _label;
  late final TextEditingController _model;
  late final TextEditingController _endpoint;
  late final TextEditingController _apiKey;
  late final TextEditingController _mcpPort;
  late final TextEditingController _mcpAllowlist;
  late final AssistantAccountsNotifier _ai;
  late final McpNotifier _mcp;

  @override
  void initState() {
    super.initState();
    _ai = ref.read(assistantAccountsNotifierProvider.notifier);
    _mcp = ref.read(mcpNotifierProvider.notifier);
    final profile = ref.read(assistantAccountsNotifierProvider).activeProfile;
    _label = TextEditingController(text: profile.label);
    _model = TextEditingController(text: profile.model);
    _endpoint = TextEditingController(text: profile.baseUrl);
    _apiKey = TextEditingController(text: profile.apiKey);
    final bind = ref.read(mcpNotifierProvider).bind;
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
    _ai.setModel(_model.text);
    _ai.setBaseUrl(_endpoint.text);
    _ai.setApiKey(_apiKey.text);
  }

  void _syncAssistantFields() {
    final profile = ref.read(assistantAccountsNotifierProvider).activeProfile;
    _label.text = profile.label;
    _model.text = profile.model;
    _endpoint.text = profile.baseUrl;
    _apiKey.text = profile.apiKey;
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

  void _removeProfile(String id) {
    _ai.removeProfile(id);
    _syncAssistantFields();
    setState(() {});
  }

  void _setTab(SettingsTab next) {
    final tab = widget.tab;
    if (tab is ValueNotifier<SettingsTab>) {
      tab.value = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tab = widget.tab.value;
    // Watch so a language or theme write rebuilds this surface in place.
    ref.watch(appearanceNotifierProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 120,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space2,
              FanCadTokens.space1,
              FanCadTokens.space2,
              FanCadTokens.space3,
            ),
            child: Column(
              children: [
                _SettingsNavItem(
                  tabKey: const Key('settings-tab-general'),
                  label: l10n.settings_tab_general,
                  selected: tab == SettingsTab.general,
                  onTap: () => _setTab(SettingsTab.general),
                ),
                _SettingsNavItem(
                  tabKey: const Key('settings-tab-assistant'),
                  label: l10n.settings_tab_assistant,
                  selected: tab == SettingsTab.assistant,
                  onTap: () => _setTab(SettingsTab.assistant),
                ),
                _SettingsNavItem(
                  tabKey: const Key('settings-tab-models'),
                  label: l10n.settings_tab_models,
                  selected: tab == SettingsTab.models,
                  onTap: () => _setTab(SettingsTab.models),
                ),
                _SettingsNavItem(
                  tabKey: const Key('settings-tab-mcp'),
                  label: l10n.settings_tab_mcp,
                  selected: tab == SettingsTab.mcp,
                  onTap: () => _setTab(SettingsTab.mcp),
                ),
              ],
            ),
          ),
        ),
        const FanCadHairline(axis: Axis.vertical, strong: false),
        Expanded(
          child: IndexedStack(
            index: switch (tab) {
              SettingsTab.general => 0,
              SettingsTab.assistant => 1,
              SettingsTab.models => 2,
              SettingsTab.mcp => 3,
            },
            children: [
              _GeneralPage(),
              _AssistantPage(onSelectProfile: _selectProfile),
              _ModelsPage(
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
    );
  }
}

class _SettingsNavItem extends StatefulWidget {
  const _SettingsNavItem({
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
  State<_SettingsNavItem> createState() => _SettingsNavItemState();
}

class _SettingsNavItemState extends State<_SettingsNavItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: FanCadTokens.space1),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (show) => setState(() => _hovered = show),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            key: widget.tabKey,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: 32,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space2,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? tokens.pressed
                  : _hovered
                  ? tokens.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: tokens.pressed,
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: tokens.bodyStyle.copyWith(
                color: selected ? tokens.text : tokens.textMuted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appearance = ref.watch(appearanceNotifierProvider);
    final language = appearance.language;
    final themePref = appearance.theme;
    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        SettingsSection(
          title: l10n.settings_appearance,
          children: [
            SettingsLabeledRow(
              label: l10n.language,
              child: SettingsDropdown<String>(
                key: const Key('settings-language'),
                value: language,
                onChanged: (value) => ref
                    .read(appearanceNotifierProvider.notifier)
                    .setLanguage(value),
                options: const [
                  SettingsDropdownOption(
                    key: Key('settings-language-en'),
                    value: FanCadLanguage.english,
                    label: 'English',
                  ),
                  SettingsDropdownOption(
                    key: Key('settings-language-zh'),
                    value: FanCadLanguage.chinese,
                    label: '简体中文',
                  ),
                ],
              ),
            ),
            SettingsLabeledRow(
              label: l10n.theme,
              child: SettingsDropdown<ThemePreference>(
                key: const Key('settings-theme'),
                value: themePref,
                onChanged: (value) => ref
                    .read(appearanceNotifierProvider.notifier)
                    .setPreference(value),
                options: [
                  SettingsDropdownOption(
                    key: const Key('settings-theme-dark'),
                    value: ThemePreference.dark,
                    label: l10n.theme_dark,
                  ),
                  SettingsDropdownOption(
                    key: const Key('settings-theme-light'),
                    value: ThemePreference.light,
                    label: l10n.theme_light,
                  ),
                  SettingsDropdownOption(
                    key: const Key('settings-theme-system'),
                    value: ThemePreference.system,
                    label: l10n.theme_system,
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
    final mcp = ref.watch(
      mcpNotifierProvider.select((s) => (bind: s.bind, endpoint: s.endpoint)),
    );
    final bind = mcp.bind;
    final endpoint = mcp.endpoint;
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
              onChanged: ref.read(mcpNotifierProvider.notifier).setEnabled,
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
              onChanged: ref.read(mcpNotifierProvider.notifier).setLocal,
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

  final McpClientEndpointModel endpoint;

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
          FanCadIconButton(
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
  const _AssistantPage({required this.onSelectProfile});

  final ValueChanged<String> onSelectProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    ref.watch(
      assistantAccountsNotifierProvider.select(
        (s) => (s.autoApprove, s.activeProfileId, s.profiles),
      ),
    );
    final ai = ref.read(assistantAccountsNotifierProvider.notifier);
    final model = ref.read(assistantAccountsNotifierProvider);
    final approveHint = model.autoApprove
        ? l10n.edits_without_asking
        : l10n.ask_before_edits;
    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        SettingsSection(
          title: l10n.settings_tab_assistant,
          children: [
            SettingsToggle(
              label: l10n.auto_approve,
              value: model.autoApprove,
              onChanged: ai.setAutoApprove,
              description: approveHint,
              tooltip: approveHint,
            ),
            SettingsLabeledRow(
              label: l10n.settings_current_model,
              child: SettingsDropdown<String>(
                key: const Key('settings-current-model'),
                value: model.activeProfile.id,
                onChanged: onSelectProfile,
                options: [
                  for (final profile in model.profiles)
                    SettingsDropdownOption(
                      key: Key('settings-current-model-${profile.id}'),
                      value: profile.id,
                      label: profile.displayName,
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

class _ModelsPage extends ConsumerStatefulWidget {
  const _ModelsPage({
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
  final ValueChanged<String> onRemoveProfile;

  @override
  ConsumerState<_ModelsPage> createState() => _ModelsPageState();
}

class _ModelsPageState extends ConsumerState<_ModelsPage> {
  String? _editingId;
  String? _testingId;

  void _selectProfile(String id) {
    if (_editingId != null && _editingId != id) _editingId = null;
    widget.onSelectProfile(id);
    setState(() {});
  }

  void _toggleEdit(String id) {
    if (_editingId == id) {
      widget.onCommit();
      setState(() => _editingId = null);
      return;
    }
    widget.onSelectProfile(id);
    setState(() => _editingId = id);
  }

  void _addProfile() {
    widget.onAddProfile();
    setState(() {
      _editingId = ref.read(assistantAccountsNotifierProvider).activeProfile.id;
    });
  }

  void _removeProfile(String id) {
    final wasEditing = _editingId == id;
    widget.onRemoveProfile(id);
    setState(() {
      if (wasEditing) _editingId = null;
    });
  }

  Future<void> _testProfile(String id) async {
    if (_testingId != null) return;
    if (_editingId == id) widget.onCommit();
    final ai = ref.read(assistantAccountsNotifierProvider.notifier);
    AssistantProfileModel? profile;
    for (final item in ref.read(assistantAccountsNotifierProvider).profiles) {
      if (item.id == id) {
        profile = item;
        break;
      }
    }
    if (profile == null) return;
    setState(() => _testingId = id);
    try {
      await ai.testProfile(profile);
    } finally {
      if (mounted) setState(() => _testingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(
      assistantAccountsNotifierProvider.select(
        (s) => (s.profiles, s.activeProfileId),
      ),
    );
    final ai = ref.read(assistantAccountsNotifierProvider.notifier);
    final model = ref.read(assistantAccountsNotifierProvider);
    final canDelete = model.profiles.length > 1;
    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        SettingsSection(
          title: context.l10n.assistant_profiles,
          trailing: FanCadIconButton(
            key: const Key('settings-add-profile'),
            icon: Icons.add,
            tooltip: context.l10n.add_assistant_profile,
            iconSize: FanCadTokens.iconSmall,
            onPressed: _addProfile,
          ),
          children: [
            for (final profile in model.profiles)
              _ModelProfileCard(
                profile: profile,
                ai: ai,
                selected: profile.id == model.activeProfile.id,
                expanded: profile.id == _editingId,
                testing: profile.id == _testingId,
                canDelete: canDelete,
                label: widget.label,
                model: widget.model,
                endpoint: widget.endpoint,
                apiKey: widget.apiKey,
                onSelect: () => _selectProfile(profile.id),
                onEdit: () => _toggleEdit(profile.id),
                onTest: _testingId == null
                    ? () => _testProfile(profile.id)
                    : null,
                onRemove: () => _removeProfile(profile.id),
                onCommit: widget.onCommit,
              ),
          ],
        ),
      ],
    );
  }
}

class _ModelProfileCard extends StatelessWidget {
  const _ModelProfileCard({
    required this.profile,
    required this.ai,
    required this.selected,
    required this.expanded,
    required this.testing,
    required this.canDelete,
    required this.label,
    required this.model,
    required this.endpoint,
    required this.apiKey,
    required this.onSelect,
    required this.onEdit,
    required this.onTest,
    required this.onRemove,
    required this.onCommit,
  });

  final AssistantProfileModel profile;
  final AssistantAccountsNotifier ai;
  final bool selected;
  final bool expanded;
  final bool testing;
  final bool canDelete;
  final TextEditingController label;
  final TextEditingController model;
  final TextEditingController endpoint;
  final TextEditingController apiKey;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback? onTest;
  final VoidCallback onRemove;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return GestureDetector(
      onTap: onSelect,
      behavior: HitTestBehavior.opaque,
      child: Container(
        key: Key('settings-profile-${profile.id}'),
        decoration: BoxDecoration(
          color: tokens.surfaceRaised,
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          border: Border.all(
            color: selected ? tokens.accent : tokens.borderStrong,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FanCadTokens.space3,
                FanCadTokens.space2,
                FanCadTokens.space1,
                FanCadTokens.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: tokens.bodyStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _profileDescription(profile),
                          style: tokens.labelStyle.copyWith(
                            color: tokens.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  FanCadIconButton(
                    key: Key('settings-profile-edit-${profile.id}'),
                    icon: Icons.edit_outlined,
                    iconSize: FanCadTokens.iconSmall,
                    isActive: expanded,
                    onPressed: onEdit,
                  ),
                  FanCadIconButton(
                    key: Key('settings-profile-test-${profile.id}'),
                    icon: Icons.wifi_tethering,
                    tooltip: l10n.settings_test_model,
                    iconSize: FanCadTokens.iconSmall,
                    enabled: !testing,
                    onPressed: onTest,
                  ),
                  FanCadIconButton(
                    key: Key('settings-profile-remove-${profile.id}'),
                    icon: Icons.delete_outline,
                    tooltip: l10n.remove_assistant_profile,
                    iconSize: FanCadTokens.iconSmall,
                    destructive: true,
                    enabled: canDelete,
                    onPressed: canDelete ? onRemove : null,
                  ),
                ],
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FanCadTokens.space3,
                  0,
                  FanCadTokens.space3,
                  FanCadTokens.space3,
                ),
                child: Column(
                  children: [
                    SettingsLabeledRow(
                      label: l10n.assistant_profile_name,
                      child: SettingsTextField(
                        key: const Key('settings-profile-label'),
                        controller: label,
                        onChanged: ai.setProfileLabel,
                        onSubmitted: (_) => onCommit(),
                      ),
                    ),
                    const SizedBox(height: SettingsSection.itemGap),
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
                    const SizedBox(height: SettingsSection.itemGap),
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
                    const SizedBox(height: SettingsSection.itemGap),
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
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _profileDescription(AssistantProfileModel profile) {
  final host = Uri.tryParse(profile.baseUrl)?.host;
  final endpoint = (host != null && host.isNotEmpty) ? host : profile.baseUrl;
  return '${profile.model} · $endpoint';
}
