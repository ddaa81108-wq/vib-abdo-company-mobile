import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/theme_controller.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';

/// Empty stand-in for an admin area the server does not feed yet.
///
/// The route is registered only as a place to land. [permissionRedirect] and
/// the check below both hide it unless `settings.manage` is allowed. There
/// is no invented list, form, or action. Whether these three routes stay is
/// a product decision for the project manager.
class AdminPlaceholderScreen extends ConsumerWidget {
  const AdminPlaceholderScreen({
    required this.title,
    required this.message,
    required this.icon,
    required this.screenKey,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Key screenKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!permissionsOf(ref).canDo(ManagementAction.settingsManage)) {
      return const ForbiddenPane();
    }
    return ListView(
      key: screenKey,
      padding: pagePadding(MediaQuery.sizeOf(context).width),
      children: [
        const SizedBox(height: AppSpacing.xxl),
        EmptyPane(title: title, message: message, icon: icon),
      ],
    );
  }
}
