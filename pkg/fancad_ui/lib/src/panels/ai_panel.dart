import 'package:fancad_ai/fancad_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/ai_controller.dart';
import '../theme/tokens.dart';
import '../workbench/shell_widgets.dart';

/// The assistant sidebar.
///
/// The interesting part is what is *not* here: there is no second command
/// catalogue and no special "AI can do this" list. The model sees the same
/// registry the command palette does, and every edit it makes is an ordinary
/// command that lands on the ordinary undo stack.
class AiPanel extends StatefulWidget {
  const AiPanel({super.key, required this.controller});

  final AiController controller;

  @override
  State<AiPanel> createState() => _AiPanelState();
}

class _AiPanelState extends State<AiPanel> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
    _input.text = widget.controller.draft;
  }

  @override
  void didUpdateWidget(AiPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Column(
      children: [
        PanelHeader(
          title: 'Assistant',
          actions: [
            ShellIconButton(
              icon: Icons.delete_outline,
              tooltip: controller.messages.isEmpty
                  ? 'Nothing to clear'
                  : 'Clear conversation',
              enabled: controller.messages.isNotEmpty,
              destructive: true,
              onPressed: controller.clear,
            ),
          ],
        ),
        _SettingsRow(controller: controller),
        Expanded(
          child: controller.messages.isEmpty
              ? _EmptyAssistant(
                  configured: controller.isConfigured,
                  onUsePrompt: (prompt) {
                    _input
                      ..text = prompt
                      ..selection = TextSelection.collapsed(
                        offset: prompt.length,
                      );
                    controller.setDraft(prompt);
                  },
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FanCadTokens.space3,
                    vertical: FanCadTokens.space2,
                  ),
                  itemCount: controller.messages.length,
                  itemBuilder: (context, index) => _Bubble(
                    message: controller.messages[index],
                    onCopied: (text) =>
                        widget.controller.workspace.notify('Copied $text'),
                  ),
                ),
        ),
        if (controller.error != null)
          _ErrorBanner(
            message: controller.error!,
            onDismiss: controller.clearError,
          ),
        _Composer(
          controller: _input,
          enabled: !controller.isBusy,
          canSend: !controller.isBusy && controller.draft.trim().isNotEmpty,
          busy: controller.isBusy,
          onChanged: controller.setDraft,
          onSend: () => controller.send(_input.text),
        ),
      ],
    );
  }
}

class SettingsKeysHint {
  static const envVar = 'OPENAI_API_KEY';
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.controller});

  final AiController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FanCadTokens.space3,
        vertical: FanCadTokens.space2,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: controller.isConfigured ? tokens.success : tokens.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: FanCadTokens.space2),
          Expanded(
            child: Tooltip(
              message: 'Click to change the model or endpoint',
              child: GestureDetector(
                onTapDown: (details) =>
                    _pickModel(context, controller, details.globalPosition),
                child: Text(
                  controller.model,
                  style: tokens.monoStyle.copyWith(
                    fontSize: 10.5,
                    color: tokens.accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          Text('Auto-approve', style: tokens.labelStyle),
          const SizedBox(width: FanCadTokens.space1),
          Tooltip(
            message: controller.autoApprove
                ? 'Edits run without asking'
                : 'Ask before the assistant edits the drawing',
            child: SizedBox(
              height: 22,
              child: Switch.adaptive(
                value: controller.autoApprove,
                onChanged: controller.setAutoApprove,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _presetModels = ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1', 'o4-mini'];

Future<void> _pickModel(
  BuildContext context,
  AiController controller,
  Offset globalPosition,
) async {
  final tokens = context.tokens;
  final chosen = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    color: tokens.surfaceOverlay,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(FanCadTokens.radius),
      side: BorderSide(color: tokens.borderStrong),
    ),
    items: [
      for (final model in _presetModels)
        PopupMenuItem(
          value: model,
          height: 32,
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: model == controller.model
                    ? Icon(Icons.check, size: 14, color: tokens.accent)
                    : null,
              ),
              const SizedBox(width: FanCadTokens.space2),
              Text(model, style: tokens.monoStyle.copyWith(fontSize: 12)),
            ],
          ),
        ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'custom',
        height: 32,
        child: Text('Custom model…', style: tokens.bodyStyle),
      ),
      PopupMenuItem(
        value: 'endpoint',
        height: 32,
        child: Text('Endpoint…', style: tokens.bodyStyle),
      ),
    ],
  );
  if (chosen == null || !context.mounted) return;
  if (chosen == 'custom') {
    final typed = await _askSetting(
      context,
      title: 'Model',
      current: controller.model,
      hint: 'Model id',
    );
    if (typed != null && typed.isNotEmpty) controller.setModel(typed);
    return;
  }
  if (chosen == 'endpoint') {
    final typed = await _askSetting(
      context,
      title: 'Endpoint',
      current: controller.baseUrl,
      hint: 'https://api.openai.com/v1',
    );
    if (typed != null && typed.isNotEmpty) controller.setBaseUrl(typed);
    return;
  }
  controller.setModel(chosen);
}

Future<String?> _askSetting(
  BuildContext context, {
  required String title,
  required String current,
  required String hint,
}) async {
  final tokens = context.tokens;
  final field = TextEditingController(text: current);
  final result = await showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => AlertDialog(
      backgroundColor: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
        side: BorderSide(color: tokens.borderStrong),
      ),
      title: Text(
        title,
        style: tokens.bodyStyle.copyWith(fontSize: 15),
      ),
      content: ShellTextField(
        controller: field,
        hintText: hint,
        autofocus: true,
        style: tokens.monoStyle,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: tokens.bodyStyle),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(field.text.trim()),
          child: const Text('Use'),
        ),
      ],
    ),
  );
  field.dispose();
  return result;
}

class _EmptyAssistant extends StatelessWidget {
  const _EmptyAssistant({required this.configured, required this.onUsePrompt});

  final bool configured;
  final ValueChanged<String> onUsePrompt;

  static const _prompts = [
    'How many objects are in this drawing?',
    'Draw a 100 mm square at the origin',
    'List what is selected',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ListView(
      padding: const EdgeInsets.all(FanCadTokens.space4),
      children: [
        Text(
          configured
              ? 'Ask about the drawing, or ask the assistant to change it. '
                  'It uses the same commands you do, and one reply is one undo step.'
              : 'Set the ${SettingsKeysHint.envVar} environment variable to '
                  'talk to a model, or point the base URL at a local server.',
          style: tokens.labelStyle,
        ),
        if (configured) ...[
          const SizedBox(height: FanCadTokens.space4),
          Text('TRY', style: tokens.sectionTitleStyle),
          const SizedBox(height: FanCadTokens.space2),
          for (final prompt in _prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: FanCadTokens.space1),
              child: ShellRow(
                onTap: () => onUsePrompt(prompt),
                height: 28,
                padding: const EdgeInsets.symmetric(
                  horizontal: FanCadTokens.space1,
                ),
                child: Text(
                  prompt,
                  style: tokens.bodyStyle.copyWith(color: tokens.accent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        FanCadTokens.space2,
        0,
        FanCadTokens.space2,
        FanCadTokens.space2,
      ),
      padding: const EdgeInsets.only(left: FanCadTokens.space3),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FanCadTokens.radius),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: tokens.danger),
          const SizedBox(width: FanCadTokens.space2),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: FanCadTokens.space2),
              child: Text(
                message,
                style: tokens.labelStyle.copyWith(color: tokens.danger),
              ),
            ),
          ),
          ShellIconButton(
            icon: Icons.close,
            size: 22,
            iconSize: 13,
            tooltip: 'Dismiss',
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.onCopied});

  final ChatMessage message;
  final ValueChanged<String> onCopied;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isUser = message.role == ChatRole.user;
    final isTool = message.role == ChatRole.tool;
    final text = isTool
        ? '${message.toolName ?? 'tool'}: ${message.text}'
        : message.text;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Tooltip(
        message: 'Click to copy',
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: text));
            onCopied(text);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: FanCadTokens.space2),
            padding: const EdgeInsets.symmetric(
              horizontal: FanCadTokens.space3,
              vertical: FanCadTokens.space2,
            ),
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: isUser
                  ? tokens.accent.withValues(alpha: 0.16)
                  : tokens.surfaceRaised,
              borderRadius: BorderRadius.circular(FanCadTokens.radius),
              border: Border.all(
                color: message.isError ? tokens.danger : tokens.border,
              ),
            ),
            child: Text(
              text,
              style: isTool
                  ? tokens.monoStyle.copyWith(fontSize: 10.5)
                  : tokens.bodyStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.busy,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool canSend;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(FanCadTokens.space2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter):
                    canSend ? onSend : () {},
              },
              child: ShellTextField(
                controller: controller,
                hintText: busy
                    ? 'Working…'
                    : 'Ask the assistant  Enter to send',
                style: tokens.bodyStyle,
                onChanged: onChanged,
              ),
            ),
          ),
          ShellIconButton(
            icon: busy ? Icons.hourglass_empty : Icons.send,
            tooltip: busy ? 'Working' : 'Send  Enter',
            onPressed: canSend ? onSend : null,
          ),
        ],
      ),
    );
  }
}
