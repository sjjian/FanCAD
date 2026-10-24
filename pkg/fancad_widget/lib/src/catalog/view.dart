import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../schema.dart';
import '../empty.dart';
import '../hairline.dart';
import '../tokens.dart';
import 'controls.dart';
import 'props.dart';

/// What a view tree can ask the shell for. Events stay out of the JSON.
class FanCadViewHost {
  const FanCadViewHost({
    required this.onEvent,
    this.layers = const [],
    this.imageFile,
    this.viewer,
    this.flashEntity,
    this.closedViewerLabel = '',
  });

  final void Function(String nodeId, String event, Object? value) onEvent;
  final List<String> layers;
  final File? Function(String asset)? imageFile;
  final FanCadViewerBinding? Function(String canvasId)? viewer;
  final void Function(int id)? flashEntity;
  final String closedViewerLabel;
}

/// Paints one validated view tree. State stays with the caller; this widget
/// only sends events keyed by node id.
class FanCadView extends StatefulWidget {
  const FanCadView({
    super.key,
    required this.tree,
    required this.host,
    this.invalidLabel = '',
  });

  /// A JSON object, or a JSON string of one.
  final Object? tree;
  final FanCadViewHost host;
  final String invalidLabel;

  @override
  State<FanCadView> createState() => _FanCadViewState();
}

class _FanCadField {
  _FanCadField(String value)
    : controller = TextEditingController(text: value),
      focus = FocusNode();

  final TextEditingController controller;
  final FocusNode focus;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _FanCadViewState extends State<FanCadView> {
  final Map<String, _FanCadField> _fields = {};

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  _FanCadField _field(String id, String value) {
    final existing = _fields[id];
    if (existing != null) {
      _syncField(id, existing, value);
      return existing;
    }
    final created = _FanCadField(value);
    _fields[id] = created;
    return created;
  }

  /// Writes the plugin's value after this frame. Assigning the controller
  /// during build notifies the field immediately, and that callback asks the
  /// plugin to rebuild the dialog while the dialog is still building.
  void _syncField(String id, _FanCadField field, String value) {
    if (field.focus.hasFocus || field.controller.text == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!identical(_fields[id], field)) return;
      if (field.focus.hasFocus || field.controller.text == value) return;
      field.controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final node = _decode(widget.tree);
    if (node == null) {
      return FanCadEmpty(message: widget.invalidLabel);
    }
    // A preview at the top of a dialog stays put while the controls scroll.
    // Otherwise the picture scrolls away and the only geometry left on screen
    // is the drawing, which is how a preview gets mistaken for a real entity.
    final pinned = _takePinnedPreview(node);
    if (pinned != null) {
      return LayoutBuilder(
        builder: (context, constraints) {
          // The picture keeps its own height until the card is too short to
          // show both it and the controls. A fixed picture taller than the
          // card paints the yellow overflow stripe and hides the sliders.
          final available = constraints.maxHeight;
          final controlsFloor = available > 160 ? 96.0 : available * 0.45;
          final maxPreview = available.isFinite
              ? (available - controlsFloor).clamp(0.0, available)
              : double.infinity;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxPreview),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FanCadTokens.space2,
                    FanCadTokens.space2,
                    FanCadTokens.space2,
                    0,
                  ),
                  child: _node(pinned.preview),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(FanCadTokens.space2),
                  child: _node(pinned.rest),
                ),
              ),
            ],
          );
        },
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FanCadTokens.space2),
      child: _node(node),
    );
  }

  Map<String, Object?>? _decode(Object? raw) {
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return null;
      return parseViewTree(decoded);
    } on FormatException {
      return null;
    } on ViewTreeException {
      return null;
    }
  }

  ({Map<String, Object?> preview, Map<String, Object?> rest})?
  _takePinnedPreview(Map<String, Object?> node) {
    if (node['type'] != 'column') return null;
    final children = node['children'];
    if (children is! List || children.isEmpty) return null;
    final first = children.first;
    if (first is! Map) return null;
    final pinnedType = first['type'];
    if (pinnedType != 'preview' && pinnedType != 'viewer') return null;
    return (
      preview: Map<String, Object?>.from(first),
      rest: {
        'type': 'column',
        'id': '${node['id']}-rest',
        'props': node['props'],
        'children': [
          for (final child in children.skip(1))
            if (child is Map) Map<String, Object?>.from(child),
        ],
      },
    );
  }

  Widget _node(Map<String, Object?> node) {
    final type = node['type'];
    final id = node['id'] is String ? node['id'] as String : '';
    final props = node['props'] is Map
        ? Map<String, Object?>.from(node['props'] as Map)
        : const <String, Object?>{};
    final children = [
      if (node['children'] is List)
        for (final child in node['children'] as List)
          if (child is Map) _node(Map<String, Object?>.from(child)),
    ];
    final host = widget.host;
    final built = switch (type) {
      'column' => FanCadColumn(
        props: FanCadColumnProps.fromJson(props),
        children: children,
      ),
      'row' => FanCadNodeRow(
        props: FanCadNodeRowProps.fromJson(props),
        children: children,
      ),
      'scroll' => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
      'padding' => FanCadNodePadding(
        props: FanCadPaddingProps.fromJson(props),
        children: children,
      ),
      'spacer' => const SizedBox(height: FanCadTokens.space2),
      'divider' => const FanCadHairline(),
      'expanded' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
      'text' => FanCadNodeText(props: FanCadTextProps.fromJson(props)),
      'icon' => FanCadNodeIcon(props: FanCadIconProps.fromJson(props)),
      'image' => FanCadNodeImage(
        file: host.imageFile?.call(FanCadImageProps.fromJson(props).asset),
      ),
      'button' => Align(
        alignment: Alignment.centerLeft,
        child: FanCadButton(
          props: FanCadButtonProps.fromJson(props),
          onPressed: () =>
              host.onEvent(id, 'tap', FanCadButtonProps.fromJson(props).label),
        ),
      ),
      'textField' ||
      'numberField' => _formField(id, props, type == 'numberField'),
      'checkbox' => FanCadCheckbox(
        props: FanCadCheckboxProps.fromJson(props),
        onChanged: (value) => host.onEvent(id, 'change', value),
      ),
      'dropdown' => FanCadDropdown(
        props: FanCadDropdownProps.fromJson(props),
        onChanged: (value) => host.onEvent(id, 'change', value),
      ),
      'layerPicker' => FanCadDropdown(
        props: FanCadDropdownProps.fromJson(props, options: host.layers),
        onChanged: (value) => host.onEvent(id, 'change', value),
      ),
      'slider' => FanCadSlider(
        props: FanCadSliderProps.fromJson(props),
        onChanged: (value) => host.onEvent(id, 'change', value),
      ),
      'colorField' => FanCadColorField(
        props: FanCadColorFieldProps.fromJson(props),
        onChanged: (color) =>
            host.onEvent(id, 'change', fanCadColorToJson(color)),
      ),
      'preview' => FanCadPreview(props: FanCadPreviewProps.fromJson(props)),
      'viewer' => FanCadViewer(
        props: FanCadViewerProps.fromJson(props),
        binding: host.viewer?.call(FanCadViewerProps.fromJson(props).canvas),
        closedLabel: host.closedViewerLabel,
      ),
      'entityChip' => FanCadEntityChip(
        props: FanCadEntityChipProps.fromJson(props),
        onPressed: () => _entityTap(id, props),
      ),
      _ => const SizedBox.shrink(),
    };
    final keyed = KeyedSubtree(key: ValueKey(id), child: built);
    // Expanded has to be the flex child itself. A key wrapped around it is
    // not a flex child, so the slot lives outside the key.
    if (type == 'expanded') return Expanded(child: keyed);
    return keyed;
  }

  Widget _formField(String id, Map<String, Object?> props, bool number) {
    final fieldProps = FanCadFormFieldProps.fromJson(props, number: number);
    final field = _field(id, fieldProps.value);
    return FanCadFormField(
      props: fieldProps,
      controller: field.controller,
      focusNode: field.focus,
      onChanged: (value) => widget.host.onEvent(id, 'change', value),
      onSubmitted: (value) => widget.host.onEvent(id, 'submit', value),
    );
  }

  void _entityTap(String id, Map<String, Object?> props) {
    final chip = FanCadEntityChipProps.fromJson(props);
    final raw = chip.id;
    final entityId = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (entityId != null) widget.host.flashEntity?.call(entityId);
    widget.host.onEvent(id, 'tap', entityId);
  }
}

class FanCadColumn extends StatelessWidget {
  const FanCadColumn({super.key, required this.props, required this.children});

  final FanCadColumnProps props;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _gapped(children, props.gap),
    );
  }
}

class FanCadNodeRow extends StatelessWidget {
  const FanCadNodeRow({super.key, required this.props, required this.children});

  final FanCadNodeRowProps props;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(children: _gapped(children, props.gap, row: true));
  }
}

class FanCadNodePadding extends StatelessWidget {
  const FanCadNodePadding({
    super.key,
    required this.props,
    required this.children,
  });

  final FanCadPaddingProps props;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(props.all),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

List<Widget> _gapped(List<Widget> children, double space, {bool row = false}) {
  if (children.isEmpty) return children;
  final spaced = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) {
      spaced.add(row ? SizedBox(width: space) : SizedBox(height: space));
    }
    spaced.add(row ? _rowChild(children[i]) : children[i]);
  }
  return spaced;
}

Widget _rowChild(Widget child) {
  // The node key sits outside the control, so the row has to look through it.
  final keyed = child is KeyedSubtree ? child : null;
  final inner = keyed?.child ?? child;
  // The number next to a slider is a value, not a second half of the row.
  // Sharing the width leaves the track too short to drag.
  if (inner is FanCadFormField) {
    final box = SizedBox(width: 88, child: inner);
    return keyed == null ? box : KeyedSubtree(key: keyed.key, child: box);
  }
  // A button or chip already has a width. Stretching it across the spare
  // space clips the label in a narrow sidebar.
  if (inner is Align || child is Flexible) return child;
  return Flexible(child: child);
}
