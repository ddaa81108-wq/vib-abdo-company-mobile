import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/theme_controller.dart';
import '../strings.dart';
import 'common.dart';

/// Proposed PDF control. Shown only for full access while the fake client is
/// in use. Real mode hides it and never calls GET /api/statements/pdf.
class ExportPdfButton extends ConsumerStatefulWidget {
  const ExportPdfButton({super.key});

  static const buttonKey = Key('export-pdf');
  static const busyKey = Key('export-pdf-busy');

  @override
  ConsumerState<ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends ConsumerState<ExportPdfButton> {
  var _busy = false;

  @override
  Widget build(BuildContext context) {
    final layer = ref.watch(apiLayerProvider);
    if (!layer.useFakeApi || !permissionsOf(ref).canExportPdf) {
      return const SizedBox.shrink();
    }
    return TextButton(
      key: ExportPdfButton.buttonKey,
      onPressed: _busy ? null : _export,
      child: _busy
          ? const SizedBox(
              key: ExportPdfButton.busyKey,
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text(AppStrings.exportPdf),
    );
  }

  Future<void> _export() async {
    final layer = ref.read(apiLayerProvider);
    if (!layer.useFakeApi || _busy) return;
    setState(() => _busy = true);
    try {
      // Proposed endpoint. Fake mode only; there is no file to save or share.
      await layer.reports.statementPdf();
    } catch (error) {
      if (!mounted) return;
      final failure = ref.read(errorHandlerProvider).toFailure(error);
      ref.read(errorHandlerProvider).report(error);
      showFailureSnackBar(context, failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
