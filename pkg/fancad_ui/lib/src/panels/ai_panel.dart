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
    final tokens = context.tokens;
    final controller = widget.controller;
    return Column(
      children: [
        PanelHeader(
          title: 'Assistant',
          actions: [
            ShellIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Clear conversation',
              onPressed: controller.clear,
            ),
          ],
        ),
        _SettingsRow(controller: controller),
        Expanded(
          child: controller.messages.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(FanCadTokens.space4),
                  child: Text(
                    controller.isConfigured
                        ? 'Ask about the drawing, or ask the assistant to '
                            'change it. It uses the same commands you do, and '
                            'one reply is one undo step.'
                        : 'Set the ${SettingsKeysHint.envVar} environment '
                            'variable to talk to a model, or point the base '
                            'URL at a local server.',
                    style: tokens.labelStyle,
                  ),
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
                  ),
                ),
        ),
        if (controller.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              FanCadTokens.space3,
              0,
              FanCadTokens.space3,
              FanCadTokens.space2,
            ),
            child: Text(
              controller.error!,
              style: tokens.labelStyle.copyWith(color: tokens.danger),
            ),
          ),
        _Composer(
          controller: _input,
          enabled: !controller.isBusy,
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
          Expanded(
            child: Text(
              controller.model,
              style: tokens.monoStyle.copyWith(fontSize: 10.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Tooltip(
            message: 'Auto-approve edits',
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isUser = message.role == ChatRole.user;
    final isTool = message.role == ChatRole.tool;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: FanCadTokens.space2),
        padding: const EdgeInsets.symmetric(
          horizontal: FanCadTokens.space3,
          vertical: FanCadTokens.space2,
        ),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser ? tokens.accent.withValues(alpha: 0.16) : tokens.surfaceRaised,
          borderRadius: BorderRadius.circular(FanCadTokens.radius),
          border: Border.all(
            color: message.isError ? tokens.danger : tokens.border,
          ),
        ),
        child: Text(
          isTool
              ? '${message.toolName ?? 'tool'}: ${message.text}'
              : message.text,
          style: isTool
              ? tokens.monoStyle.copyWith(fontSize: 10.5)
              : tokens.bodyStyle,
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.onChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
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
                    enabled ? onSend : () {},
              },
              child: ShellTextField(
                controller: controller,
                hintText: busy ? 'Working…' : 'Ask the assistant',
                style: tokens.bodyStyle,
                onChanged: onChanged,
              ),
            ),
          ),
          ShellIconButton(
            icon: busy ? Icons.hourglass_empty : Icons.send,
            tooltip: 'Send',
            onPressed: enabled ? onSend : null,
          ),
        ],
      ),
    );
  }
}
