import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';
import 'section_providers.dart';
import 'theme_controller.dart';

final homeClosingProvider =
    FutureProvider.autoDispose<ReportClosingOverviewDto>((ref) async {
      watchSignedIn(ref);
      ref.watch(permissionRevisionProvider);
      final layer = ref.read(apiLayerProvider);
      if (!layer.permissions.canRead(SectionKey.reports)) {
        throw const ForbiddenException(
          code: 'PERMISSION_DENIED',
          message: 'لا تملك صلاحية التقارير.',
        );
      }
      return layer.reports.closingOverview();
    });

final homeActivityProvider =
    FutureProvider.autoDispose<List<ReportActivityDto>>((ref) async {
      watchSignedIn(ref);
      ref.watch(permissionRevisionProvider);
      final layer = ref.read(apiLayerProvider);
      if (!layer.permissions.canRead(SectionKey.reports)) {
        throw const ForbiddenException(
          code: 'PERMISSION_DENIED',
          message: 'لا تملك صلاحية التقارير.',
        );
      }
      return layer.reports.activity();
    });
