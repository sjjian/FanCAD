import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ai_controller.dart';
import '../../services/providers.dart';
import '../l10n/l10n.dart';
import '../theme/tokens.dart';
import 'shell_widgets.dart';

/// Pages inside the settings dialog.
enum SettingsTab { general, assistant }

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
  return panelId == 'preferences:assistant'
      ? SettingsTab.assistant
      : SettingsTab.general;
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
  late final AiController _ai;

  @override
  void initState() {
    super.initState();
    _ai = ref.read(aiControllerProvider);
    _label = TextEditingController(text: _ai.activeProfile.label);
    _model = TextEditingController(text: _ai.model);
    _endpoint = TextEditingController(text: _ai.baseUrl);
    _apiKey = TextEditingController(text: _ai.apiKey);
    widget.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    _flushAssistantFields();
    _label.dispose();
    _model.dispose();
    _endpoint.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _onTab() {
    if (mounted) setState(() {});
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
                  ShellTab(
                    key: const Key('settings-tab-general'),
                    style: ShellTabStyle.underline,
                    selected: tab == SettingsTab.general,
                    onTap: () => _openSettingsTab?.value = SettingsTab.general,
                    child: Text(
                      l10n.settings_tab_general,
                      style: tokens.bodyStyle.copyWith(
                        color: tab == SettingsTab.general
                            ? tokens.accent
                            : tokens.textMuted,
                        fontWeight: tab == SettingsTab.general
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: FanCadTokens.space4),
                  ShellTab(
                    key: const Key('settings-tab-assistant'),
                    style: ShellTabStyle.underline,
                    selected: tab == SettingsTab.assistant,
                    onTap: () =>
                        _openSettingsTab?.value = SettingsTab.assistant,
                    child: Text(
                      l10n.settings_tab_assistant,
                      style: tokens.bodyStyle.copyWith(
                        color: tab == SettingsTab.assistant
                            ? tokens.accent
                            : tokens.textMuted,
                        fontWeight: tab == SettingsTab.assistant
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const ShellHairline(),
            Expanded(
              child: IndexedStack(
                index: tab == SettingsTab.general ? 0 : 1,
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
                ],
              ),
            ),
          ],
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
