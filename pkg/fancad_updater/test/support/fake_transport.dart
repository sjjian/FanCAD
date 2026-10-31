import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fancad_updater/fancad_updater.dart';

/// A transport with a URL table, so no test touches the network.
class FakeTransport implements HttpTransport {
  FakeTransport({
    Map<String, HttpResponseData>? responses,
    Map<String, List<int>>? payloads,
    Map<String, Exception>? failures,
  }) : responses = responses ?? {},
       payloads = payloads ?? {},
       failures = failures ?? {};

  final Map<String, HttpResponseData> responses;
  final Map<String, List<int>> payloads;
  final Map<String, Exception> failures;

  final List<Uri> getRequests = [];
  final List<Uri> downloadRequests = [];
  bool closed = false;

  @override
  Future<HttpResponseData> get(
    Uri url, {
    Map<String, String> headers = const {},
    Duration? timeout,
  }) async {
    getRequests.add(url);
    final failure = failures[url.toString()];
    if (failure != null) throw failure;
    final response = responses[url.toString()];
    if (response == null) {
      throw UpdateTransportException('No route for $url');
    }
    return response;
  }

  @override
  Future<int> download(
    Uri url, {
    required File destination,
    Map<String, String> headers = const {},
    void Function(int received, int? total)? onProgress,
    bool Function()? isCancelled,
    Duration? timeout,
  }) async {
    downloadRequests.add(url);
    final failure = failures[url.toString()];
    if (failure != null) throw failure;
    final bytes = payloads[url.toString()];
    if (bytes == null) {
      throw UpdateTransportException('No payload for $url');
    }
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(bytes, flush: true);
    onProgress?.call(bytes.length, bytes.length);
    return bytes.length;
  }

  @override
  void close() => closed = true;
}

class FakeFeed implements ReleaseFeed {
  FakeFeed({this.sourceId = 'fake', this.release, this.error});

  @override
  final String sourceId;
  ReleaseInfo? release;
  Exception? error;
  int calls = 0;

  @override
  Future<ReleaseInfo?> latest() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return release;
  }
}

Uint8List utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));
