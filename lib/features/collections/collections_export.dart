import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_providers.dart';
import '../../state/session_providers.dart';
import '../../ui/strings.dart';
import '../../ui/widgets/environment_badge.dart';
import 'collections_pdf.dart';

/// Hands a finished PDF to the system share sheet (save to files, send…).
typedef CollectionsPdfSharer = Future<void> Function(
  Uint8List bytes,
  String fileName,
);

Future<void> sharePdfWithSystem(Uint8List bytes, String fileName) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf'),
      ],
      fileNameOverrides: [fileName],
      title: CollectionsPdfText.title,
      subject: CollectionsPdfText.title,
    ),
  );
}

final collectionsPdfSharerProvider = Provider<CollectionsPdfSharer>(
  (ref) => sharePdfWithSystem,
);

/// Export clock; tests pin it.
final collectionsExportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The server the data came from, as the environment badge names it.
final collectionsExportSourceProvider = Provider<String>((ref) {
  if (ref.watch(apiLayerProvider).useFakeApi) return AppStrings.envFake;
  final env = kBuildEnvironment;
  final label = env.label ?? env.host;
  return env.host.isEmpty || label == env.host ? label : '$label (${env.host})';
});

/// «تصدير PDF» on the collections screen. Builds the report on the device
/// from the overview already on screen; it sends no request.
class CollectionsExportButton extends ConsumerStatefulWidget {
  const CollectionsExportButton({
    required this.data,
    required this.admin,
    this.batchId,
    this.label = AppStrings.exportPdf,
    this.icon = true,
    super.key,
  });

  final CollectionsOverviewDto data;
  final bool admin;

  /// The batch the statement is for (an `openBatches` id), when known.
  final String? batchId;
  final String label;

  /// False inside the collections action bar (text-only pills).
  final bool icon;

  static const buttonKey = Key('collections-export-pdf');
  static const busyKey = Key('collections-export-busy');

  @override
  ConsumerState<CollectionsExportButton> createState() =>
      _CollectionsExportButtonState();
}

class _CollectionsExportButtonState
    extends ConsumerState<CollectionsExportButton> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    const spinner = SizedBox(
      key: CollectionsExportButton.busyKey,
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    final text = Text(widget.label, maxLines: 2, textAlign: TextAlign.center);
    if (!widget.icon) {
      return OutlinedButton(
        key: CollectionsExportButton.buttonKey,
        onPressed: _busy ? null : _export,
        child: _busy ? spinner : text,
      );
    }
    return OutlinedButton.icon(
      key: CollectionsExportButton.buttonKey,
      onPressed: _busy ? null : _export,
      icon: _busy
          ? spinner
          : const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: text,
    );
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final session = ref.read(sessionStateProvider);
      final name = session is SessionAuthenticated
          ? session.profile.displayName
          : '';
      final at = ref.read(collectionsExportClockProvider)();
      final bytes = await buildCollectionsPdf(
        data: widget.data,
        admin: widget.admin,
        userName: name,
        environmentLabel: ref.read(collectionsExportSourceProvider),
        exportedAt: at,
        money: ref.read(apiLayerProvider).money,
        fonts: await CollectionsPdfFonts.load(),
      );
      await ref.read(collectionsPdfSharerProvider)(
        bytes,
        collectionsPdfFileName(at),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(CollectionsPdfText.failed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
