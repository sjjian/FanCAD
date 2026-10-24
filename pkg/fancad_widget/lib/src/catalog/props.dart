import 'package:fancad_core/fancad_core.dart';
import 'package:flutter/material.dart';

import '../tokens.dart';

double? fanCadJsonNum(Object? value) => value is num ? value.toDouble() : null;

String fanCadJsonString(Object? value) => value is String ? value : '';

/// Named chrome icons a plugin may place. Unknown names use the extension icon.
IconData fanCadNamedIcon(String? name) => switch (name) {
  'layers' => Icons.layers_outlined,
  'tune' => Icons.tune_outlined,
  'list' => Icons.list_alt_outlined,
  'edit' => Icons.edit_outlined,
  'search' => Icons.search,
  'add' => Icons.add,
  'info' => Icons.info_outline,
  'warning' => Icons.warning_amber_outlined,
  _ => Icons.extension_outlined,
};

class FanCadButtonProps {
  const FanCadButtonProps({required this.label});

  final String label;

  factory FanCadButtonProps.fromJson(Map<String, Object?> json) =>
      FanCadButtonProps(label: fanCadJsonString(json['label']));
}

class FanCadFormFieldProps {
  const FanCadFormFieldProps({
    this.value = '',
    this.placeholder,
    this.number = false,
  });

  final String value;
  final String? placeholder;
  final bool number;

  factory FanCadFormFieldProps.fromJson(
    Map<String, Object?> json, {
    bool number = false,
  }) => FanCadFormFieldProps(
    value: '${json['value'] ?? ''}',
    placeholder: json['placeholder'] is String
        ? json['placeholder'] as String
        : null,
    number: number,
  );
}

class FanCadCheckboxProps {
  const FanCadCheckboxProps({required this.label, required this.value});

  final String label;
  final bool value;

  factory FanCadCheckboxProps.fromJson(Map<String, Object?> json) =>
      FanCadCheckboxProps(
        label: fanCadJsonString(json['label']),
        value: json['value'] == true,
      );
}

class FanCadDropdownProps {
  const FanCadDropdownProps({
    required this.options,
    this.value,
    this.placeholder,
  });

  final List<String> options;
  final String? value;
  final String? placeholder;

  factory FanCadDropdownProps.fromJson(
    Map<String, Object?> json, {
    List<String>? options,
  }) {
    final raw = options ?? json['options'];
    return FanCadDropdownProps(
      options: [
        if (raw is List)
          for (final value in raw) '$value',
      ],
      value: json['value'] is String ? json['value'] as String : null,
      placeholder: json['placeholder'] is String
          ? json['placeholder'] as String
          : null,
    );
  }
}

class FanCadSliderProps {
  const FanCadSliderProps({
    required this.value,
    required this.min,
    required this.max,
  });

  final double value;
  final double min;
  final double max;

  factory FanCadSliderProps.fromJson(Map<String, Object?> json) {
    final min = fanCadJsonNum(json['min']) ?? 0;
    final max = fanCadJsonNum(json['max']) ?? 1;
    final high = max < min ? min : max;
    final value = (fanCadJsonNum(json['value']) ?? min).clamp(min, high);
    return FanCadSliderProps(value: value, min: min, max: high);
  }
}

class FanCadTextProps {
  const FanCadTextProps({required this.text});

  final String text;

  factory FanCadTextProps.fromJson(Map<String, Object?> json) =>
      FanCadTextProps(text: '${json['text'] ?? ''}');
}

class FanCadIconProps {
  const FanCadIconProps({required this.name});

  final String name;

  factory FanCadIconProps.fromJson(Map<String, Object?> json) =>
      FanCadIconProps(name: '${json['name'] ?? ''}');
}

class FanCadImageProps {
  const FanCadImageProps({required this.asset});

  final String asset;

  factory FanCadImageProps.fromJson(Map<String, Object?> json) =>
      FanCadImageProps(asset: fanCadJsonString(json['asset']));
}

class FanCadEntityChipProps {
  const FanCadEntityChipProps({required this.label, this.id});

  final String label;
  final Object? id;

  factory FanCadEntityChipProps.fromJson(Map<String, Object?> json) =>
      FanCadEntityChipProps(
        label: '${json['label'] ?? json['id'] ?? ''}',
        id: json['id'],
      );
}

class FanCadPreviewProps {
  const FanCadPreviewProps({this.shapes, this.caption, this.height = 180});

  final Object? shapes;
  final String? caption;
  final double height;

  factory FanCadPreviewProps.fromJson(Map<String, Object?> json) =>
      FanCadPreviewProps(
        shapes: json['shapes'],
        caption: json['caption'] is String ? json['caption'] as String : null,
        height: fanCadJsonNum(json['height']) ?? 180,
      );
}

class FanCadViewerProps {
  const FanCadViewerProps({
    required this.canvas,
    this.height = 220,
    this.caption,
  });

  final String canvas;
  final double height;
  final String? caption;

  factory FanCadViewerProps.fromJson(Map<String, Object?> json) =>
      FanCadViewerProps(
        canvas: fanCadJsonString(json['canvas']),
        height: fanCadJsonNum(json['height']) ?? 220,
        caption: json['caption'] is String ? json['caption'] as String : null,
      );
}

class FanCadColorFieldProps {
  const FanCadColorFieldProps({
    required this.color,
    this.caption,
    this.byLayerLabel = 'ByLayer',
    this.tooltip,
    this.width = 92,
  });

  final CadColor color;
  final String? caption;
  final String byLayerLabel;
  final String? tooltip;
  final double width;

  String get label =>
      caption ?? fanCadColorLabel(color, byLayerLabel: byLayerLabel);

  factory FanCadColorFieldProps.fromJson(Map<String, Object?> json) =>
      FanCadColorFieldProps(color: fanCadColorFromJson(json['value']));
}

class FanCadColumnProps {
  const FanCadColumnProps({this.gap = FanCadTokens.space2});

  final double gap;

  factory FanCadColumnProps.fromJson(Map<String, Object?> json) =>
      FanCadColumnProps(gap: fanCadJsonNum(json['gap']) ?? FanCadTokens.space2);
}

class FanCadNodeRowProps {
  const FanCadNodeRowProps({this.gap = FanCadTokens.space2});

  final double gap;

  factory FanCadNodeRowProps.fromJson(Map<String, Object?> json) =>
      FanCadNodeRowProps(
        gap: fanCadJsonNum(json['gap']) ?? FanCadTokens.space2,
      );
}

class FanCadPaddingProps {
  const FanCadPaddingProps({this.all = FanCadTokens.space2});

  final double all;

  factory FanCadPaddingProps.fromJson(Map<String, Object?> json) =>
      FanCadPaddingProps(
        all: fanCadJsonNum(json['all']) ?? FanCadTokens.space2,
      );
}

CadColor fanCadColorFromJson(Object? raw) {
  final text = raw == null ? '' : '$raw'.trim();
  final lower = text.toLowerCase();
  if (text.isEmpty || lower == 'bylayer' || lower == 'by layer') {
    return const CadColor.byLayer();
  }
  if (lower == 'byblock' || lower == 'by block') {
    return const CadColor.byBlock();
  }
  if (text.startsWith('#') && text.length > 1) {
    final hex = int.tryParse(text.substring(1), radix: 16);
    if (hex != null) return CadColor.rgb(hex);
  }
  final index = int.tryParse(text);
  if (index != null && index >= 1 && index <= 255) {
    return CadColor.indexed(index);
  }
  return const CadColor.byLayer();
}

String fanCadColorToJson(CadColor color) => switch (color.kind) {
  ColorKind.byLayer => 'bylayer',
  ColorKind.byBlock => 'byblock',
  ColorKind.indexed => '${color.value}',
  ColorKind.trueColor => '#${color.value.toRadixString(16).padLeft(6, '0')}',
};

String fanCadColorLabel(CadColor color, {required String byLayerLabel}) =>
    switch (color.kind) {
      ColorKind.byLayer => byLayerLabel,
      ColorKind.byBlock => 'ByBlock',
      ColorKind.indexed => '${color.value}',
      ColorKind.trueColor =>
        '#${color.value.toRadixString(16).padLeft(6, '0')}',
    };
