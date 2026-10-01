import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:fancad_render/fancad_render.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart';

import '../models/assistant.dart';

/// Chat pictures on disk, or in memory when settings have no directory.
class AssistantImageFiles {
  AssistantImageFiles({this.directory});

  final String? directory;
  final Map<String, Uint8List> _memory = {};
  var _sequence = 0;

  Future<AssistantImageModel> save(
    Uint8List bytes, {
    String mime = 'image/png',
  }) async {
    final fitted = fitChatImage(bytes, mime);
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';
    final root = directory;
    if (root == null) {
      _memory[id] = fitted.bytes;
    } else {
      await Directory(root).create(recursive: true);
      await File(p.join(root, id)).writeAsBytes(fitted.bytes);
    }
    return AssistantImageModel(id: id, mime: fitted.mime);
  }

  Future<Uint8List?> read(String id) async {
    final cached = _memory[id];
    if (cached != null) return cached;
    final root = directory;
    if (root == null) return null;
    final file = File(p.join(root, id));
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }
}

/// Shrinks an upload so its long edge matches a plot image.
({Uint8List bytes, String mime}) fitChatImage(Uint8List bytes, String mime) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return (bytes: bytes, mime: mime);
  final edge = math.max(decoded.width, decoded.height);
  final scaled = edge <= plotImageLongEdge
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? plotImageLongEdge : null,
          height: decoded.height > decoded.width ? plotImageLongEdge : null,
        );
  if (mime == 'image/jpeg' || mime == 'image/jpg') {
    return (
      bytes: Uint8List.fromList(img.encodeJpg(scaled, quality: 90)),
      mime: 'image/jpeg',
    );
  }
  return (bytes: Uint8List.fromList(img.encodePng(scaled)), mime: 'image/png');
}

const _clipboardPictures = <(FileFormat, String)>[
  (Formats.png, 'image/png'),
  (Formats.jpeg, 'image/jpeg'),
  (Formats.webp, 'image/webp'),
  (Formats.gif, 'image/gif'),
];

/// First picture on the system clipboard, or null when the paste is not one.
Future<({Uint8List bytes, String mime})?> readClipboardPicture() async {
  final clipboard = SystemClipboard.instance;
  if (clipboard == null) return null;
  final reader = await clipboard.read();
  for (final (format, mime) in _clipboardPictures) {
    if (!reader.canProvide(format)) continue;
    final done = Completer<DataReaderFile?>();
    final progress = reader.getFile(
      format,
      (file) {
        if (!done.isCompleted) done.complete(file);
      },
      onError: (error) {
        if (!done.isCompleted) done.complete(null);
      },
    );
    if (progress == null) continue;
    final file = await done.future;
    if (file == null) continue;
    final bytes = await file.readAll();
    if (bytes.isEmpty) continue;
    return (bytes: bytes, mime: mime);
  }
  return null;
}

/// Drops a picture from the system clipboard and leaves any text in place.
///
/// Copying objects does not put them on the system clipboard, so a picture
/// copied earlier would still be what a later paste reads. Replacing the
/// clipboard with its text clears every other type, including that picture.
///
/// This does not read the picture. A promised pasteboard item can stall the
/// read, and COPYCLIP must not stay running while that happens.
Future<void> clearClipboardPicture() async {
  try {
    final text = await Clipboard.getData(Clipboard.kTextPlain);
    await Clipboard.setData(ClipboardData(text: text?.text ?? ''));
  } catch (_) {}
}
