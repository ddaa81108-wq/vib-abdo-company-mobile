import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/theme_controller.dart';
import '../strings.dart';

/// Shown only for full access. Hidden for every other account, including
/// settings.manage.
class ExportPdfButton extends ConsumerWidget {
  const ExportPdfButton({super.key});

  static const buttonKey = Key('export-pdf');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canExportPdf) return const SizedBox.shrink();
    return TextButton(
      key: buttonKey,
      onPressed: () => _export(context, ref),
      child: const Text(AppStrings.exportPdf),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiLayerProvider).reports.statementPdf();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.savedReply)),
      );
    } catch (error) {
      if (!context.mounted) return;
      final message = ref.read(errorHandlerProvider).toFailure(error).message;
      ref.read(errorHandlerProvider).report(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
