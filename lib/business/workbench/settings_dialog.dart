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
        const size = Size(680, 560);
        void close() {
          final navigator = Navigator.maybeOf(context);
          if (navigator != null && navigator.canPop()) navigator.pop();
        }

        return SizedBox.expand(
          key: const Key('settings-dialog'),
          child: Stack(
            children: [
              ShellCanvasWindow(
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
    if (endpoint.isNotEmpty && endpoint != _ai.baseUrl) {
      _ai.setBaseUrl(endpoint);
    }
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
    ref.watch(languageProvider);
    ref.watch(themeBrightnessProvider);
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
                  tabKey: const Key('settings-tab-mcp'),
                  label: l10n.settings_tab_mcp,
                  selected: tab == SettingsTab.mcp,
                  onTap: () => _setTab(SettingsTab.mcp),
                ),
              ],
            ),
          ),
        ),
        const ShellHairline(axis: Axis.vertical, strong: false),
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
    final language = ref.watch(languageProvider);
    ref.watch(themeBrightnessProvider);
    final themePref = ref.read(themeBrightnessProvider.notifier).preference;
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
                onChanged: (value) =>
                    ref.read(languageProvider.notifier).setLanguage(value),
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
              child: SettingsDropdown<String>(
                key: const Key('settings-theme'),
                value: themePref,
                onChanged: (value) => ref
                    .read(themeBrightnessProvider.notifier)
                    .setPreference(value),
                options: [
                  SettingsDropdownOption(
                    key: const Key('settings-theme-dark'),
                    value: 'dark',
                    label: l10n.theme_dark,
                  ),
                  SettingsDropdownOption(
                    key: const Key('settings-theme-light'),
                    value: 'light',
                    label: l10n.theme_light,
                  ),
                  SettingsDropdownOption(
                    key: const Key('settings-theme-system'),
                    value: 'system',
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = FanCadTokens.space2;
                    final width = (constraints.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final profile in ai.profiles)
                          SizedBox(
                            width: width,
                            child: _ProfileCard(
                              key: Key('settings-profile-${profile.id}'),
                              title: profile.displayName,
                              model: profile.model,
                              hasKey: profile.apiKey.trim().isNotEmpty,
                              selected: profile.id == ai.activeProfile.id,
                              onTap: () => onSelectProfile(profile.id),
                              onRemove:
                                  profile.id == ai.activeProfile.id &&
                                      ai.profiles.length > 1
                                  ? onRemoveProfile
                                  : null,
                            ),
                          ),
                        SizedBox(
                          width: width,
                          child: _AddProfileCard(onTap: onAddProfile),
                        ),
                      ],
                    );
                  },
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
            const SizedBox(height: SettingsSection.itemGap),
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

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    super.key,
    required this.title,
    required this.model,
    required this.hasKey,
    required this.selected,
    required this.onTap,
    this.onRemove,
  });

  final String title;
  final String model;
  final bool hasKey;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return FocusableActionDetector(
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
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: 76,
          padding: const EdgeInsets.fromLTRB(
            FanCadTokens.space3,
            FanCadTokens.space2,
            FanCadTokens.space1,
            FanCadTokens.space2,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? tokens.selection
                : _hovered
                ? tokens.hover
                : tokens.surfaceRaised,
            borderRadius: BorderRadius.circular(FanCadTokens.radius),
            border: Border.all(
              color: widget.selected ? tokens.accent : tokens.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: FanCadTokens.space1),
                    Text(
                      widget.model,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.monoStyle.copyWith(
                        fontSize: 11,
                        color: tokens.textMuted,
                      ),
                    ),
                    const Spacer(),
                    ShellDot(
                      color: widget.hasKey ? tokens.success : tokens.textFaint,
                    ),
                  ],
                ),
              ),
              if (widget.onRemove != null)
                ShellIconButton(
                  key: const Key('settings-remove-profile'),
                  icon: Icons.delete_outline,
                  tooltip: l10n.remove_assistant_profile,
                  iconSize: FanCadTokens.iconSmall,
                  destructive: true,
                  onPressed: widget.onRemove,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 4.0;
      const gap = 3.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _AddProfileCard extends StatefulWidget {
  const _AddProfileCard({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AddProfileCard> createState() => _AddProfileCardState();
}

class _AddProfileCardState extends State<_AddProfileCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return FocusableActionDetector(
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
        key: const Key('settings-add-profile'),
        onTap: widget.onTap,
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: tokens.border,
            radius: FanCadTokens.radius,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            height: 76,
            decoration: BoxDecoration(
              color: _hovered ? tokens.hover : Colors.transparent,
              borderRadius: BorderRadius.circular(FanCadTokens.radius),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add,
                  size: FanCadTokens.iconLarge,
                  color: tokens.textMuted,
                ),
                const SizedBox(height: FanCadTokens.space1),
                Text(
                  l10n.add_assistant_profile,
                  style: tokens.labelStyle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
