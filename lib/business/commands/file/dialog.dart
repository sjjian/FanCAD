import 'dart:io';

// Prefixed because this file has its own `openFile`, which is the injected
// workspace callback rather than the platform dialog.
import 'package:file_selector/file_selector.dart' as picker;
import 'package:flutter/services.dart';

const List<String> _drawingExtensions = ['dwg', 'dxf', 'fcb'];

const MethodChannel _macDialog = MethodChannel('fancad/file_dialog');

/// Shows the platform open dialog, restricted to the formats we can read.
Future<String?> openFileDialog() async {
  if (Platform.isMacOS) {
    try {
      final path = await _macDialog.invokeMethod<String>('open', {
        'extensions': _drawingExtensions,
      });
      if (path != null) return path;
    } on MissingPluginException {
      // Fall through to file_selector when the macOS channel is absent
      // (a widget test, or a build that has not been rebuilt).
    }
  }
  final file = await picker.openFile(
    acceptedTypeGroups: const [
      picker.XTypeGroup(
        label: 'Drawings',
        extensions: _drawingExtensions,
        uniformTypeIdentifiers: [
          'com.autodesk.dwg',
          'com.autodesk.dxf',
          'app.fancad.fcb',
          'public.data',
        ],
      ),
    ],
  );
  return file?.path;
}

Future<String?> saveFileDialog({String suggestedName = 'Drawing'}) async {
  final name =
      suggestedName.toLowerCase().endsWith('.dwg') ||
          suggestedName.toLowerCase().endsWith('.dxf') ||
          suggestedName.toLowerCase().endsWith('.fcb')
      ? suggestedName
      : '$suggestedName.dwg';
  if (Platform.isMacOS) {
    try {
      final path = await _macDialog.invokeMethod<String>('save', {
        'extensions': _drawingExtensions,
        'suggestedName': name,
      });
      if (path != null) return path;
    } on MissingPluginException {
      // Same fallback as the open dialog.
    }
  }
  final location = await picker.getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: const [
      picker.XTypeGroup(
        label: 'Drawings',
        extensions: _drawingExtensions,
        uniformTypeIdentifiers: [
          'com.autodesk.dwg',
          'com.autodesk.dxf',
          'app.fancad.fcb',
        ],
      ),
    ],
  );
  return location?.path;
}
