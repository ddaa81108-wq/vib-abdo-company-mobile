import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:vib_abdo_company_mobile/features/masraweya/masraweya_share.dart';

/// Records the [ShareParams] the app would hand to Android's share sheet.
/// This does not open a device chooser and is not a device verification.
class _RecordingShare extends SharePlatform {
  ShareParams? params;

  @override
  Future<ShareResult> share(ShareParams params) async {
    this.params = params;
    return const ShareResult('', ShareResultStatus.success);
  }
}

void main() {
  test('summary share sends one png and no other payload', () async {
    final platform = _RecordingShare();
    final bytes = Uint8List.fromList(const [1, 2, 3, 4, 5]);

    await shareMasraweyaSummary(
      bytes,
      'masraweya-summary.png',
      sharePlus: SharePlus.custom(platform),
    );

    final params = platform.params;
    expect(params, isNotNull);
    expect(params!.text, isNull);
    expect(params.uri, isNull);
    expect(params.files, hasLength(1));
    // Android uses fileNameOverrides for XFile.fromData. The XFile name
    // field itself stays empty in share_plus 12.
    expect(params.fileNameOverrides, ['masraweya-summary.png']);
    final file = params.files!.single;
    expect(file.mimeType, 'image/png');
    expect(await file.readAsBytes(), bytes);
  });
}
