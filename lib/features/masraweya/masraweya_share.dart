import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Shares the summary-card PNG only. Callers must pass bytes captured from
/// the totals card, not the work table or the app shell.
typedef MasraweyaSummarySharer = Future<void> Function(
  Uint8List png,
  String fileName,
);

/// Hands the summary PNG to the platform share sheet.
///
/// [sharePlus] exists so tests can pass [SharePlus.custom]. The default is
/// the process share plugin. A unit test of this function does not open an
/// Android share sheet.
Future<void> shareMasraweyaSummary(
  Uint8List png,
  String fileName, {
  SharePlus? sharePlus,
}) {
  return (sharePlus ?? SharePlus.instance).share(
    ShareParams(
      files: [XFile.fromData(png, name: fileName, mimeType: 'image/png')],
      fileNameOverrides: [fileName],
    ),
  );
}

final masraweyaSummarySharerProvider = Provider<MasraweyaSummarySharer>(
  (ref) => shareMasraweyaSummary,
);

typedef MasraweyaBoundaryCapture = Future<Uint8List> Function(
  RenderRepaintBoundary boundary,
);

/// Null uses [captureBoundaryPng]. Tests inject a capture so they do not
/// depend on the raster thread.
final masraweyaBoundaryCaptureProvider = Provider<MasraweyaBoundaryCapture?>(
  (ref) => null,
);

Future<Uint8List> captureBoundaryPng(RenderRepaintBoundary boundary) async {
  final image = await boundary.toImage(pixelRatio: 2);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('summary image was empty');
    }
    return bytes.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
