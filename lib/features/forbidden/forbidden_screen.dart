import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/strings.dart';
import '../../ui/widgets/common.dart';

/// Minimal stand-in for a route the signed-in user may not open.
///
/// The shell redirects here from [permissionRedirect]. Layout polish stays
/// with the UI developer; this screen only has to show [ForbiddenPane].
class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  static const screenKey = Key('screen-forbidden');
  static const homeKey = Key('forbidden-home');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: screenKey,
      appBar: AppBar(
        leading: IconButton(
          key: homeKey,
          tooltip: AppStrings.homeTitle,
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: const ForbiddenPane(),
    );
  }
}
