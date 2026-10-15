import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../widgets/tokens.dart';
import '../widgets/widgets.dart';

/// One row in the attribute dialog.
class AttributeEditField {
  const AttributeEditField({
    required this.tag,
    required this.label,
    required this.value,
    this.constant = false,
  });

  final String tag;
  final String label;
  final String value;
  final bool constant;
}

/// Prompt when the definition has one, otherwise the tag, with text codes expanded.
String attributeEditLabel(AttdefEntity def) {
  final raw = def.prompt.isEmpty ? def.tag : def.prompt;
  return decodeMTextPlain(expandDxfTextCodes(raw));
}

/// Rows for [insert], in block-definition order.
List<AttributeEditField> attributeEditFields(
  CadDocument document,
  InsertEntity insert,
) => [
  for (final def in document.attdefsOf(insert.blockName))
    AttributeEditField(
      tag: def.tag,
      label: attributeEditLabel(def),
      value: insert.attributeValue(def.tag, def.defaultValue),
      constant: def.constant,
    ),
];

/// Changed tag → value, or null when the dialog is dismissed.
Future<Map<String, String>?> showAttributeEditDialog(
  BuildContext context, {
  required String blockName,
  required List<AttributeEditField> fields,
}) {
  final tokens = context.tokens;
  return showDialog<Map<String, String>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (context) => AttributeEditDialog(
      blockName: blockName,
      fields: fields,
      tokens: tokens,
      onSave: (values) => Navigator.of(context).pop(values),
      onCancel: () => Navigator.of(context).pop(),
    ),
  );
}

/// Edits the values on one block reference. Constant rows stay as written.
class AttributeEditDialog extends StatefulWidget {
  const AttributeEditDialog({
    super.key,
    required this.blockName,
    required this.fields,
    required this.onSave,
    required this.onCancel,
    this.tokens,
  });

  final String blockName;
  final List<AttributeEditField> fields;
  final ValueChanged<Map<String, String>> onSave;
  final VoidCallback onCancel;

  /// Captured by [showAttributeEditDialog] so the route still paints in the
  /// shell theme. Tests pass the theme through [MaterialApp] instead.
  final FanCadTokens? tokens;

  @override
  State<AttributeEditDialog> createState() => _AttributeEditDialogState();
}

class _AttributeEditDialogState extends State<AttributeEditDialog> {
  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      _controllers[field.tag] = TextEditingController(text: field.value);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final changed = <String, String>{};
    for (final field in widget.fields) {
      if (field.constant) continue;
      final text = _controllers[field.tag]?.text ?? field.value;
      if (text != field.value) changed[field.tag] = text;
    }
    widget.onSave(changed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens ?? context.tokens;
    final l10n = context.l10n;
    return AlertDialog(
      backgroundColor: tokens.surfaceOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FanCadTokens.radiusLarge),
        side: BorderSide(color: tokens.borderStrong),
      ),
      title: Text(
        l10n.command_edit_attedit,
        style: tokens.bodyStyle.copyWith(fontSize: 15),
      ),
      content: SizedBox(
        width: 480,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 360),
          child: ListView(
            shrinkWrap: true,
            children: [
              SettingsSection(
                title: widget.blockName,
                children: [
                  for (final field in widget.fields)
                    SettingsLabeledRow(
                      label: field.label,
                      child: SettingsTextField(
                        key: Key('attribute-edit-${field.tag}'),
                        controller: _controllers[field.tag]!,
                        readOnly: field.constant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(l10n.cancel, style: tokens.bodyStyle),
        ),
        FilledButton(
          key: const Key('attribute-edit-save'),
          onPressed: _save,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
