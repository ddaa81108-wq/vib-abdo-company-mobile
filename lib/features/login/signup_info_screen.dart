import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/strings.dart';
import '../../ui/tokens.dart';

class SignupInfoScreen extends StatelessWidget {
  const SignupInfoScreen({super.key});

  static const screenKey = Key('signup-info-screen');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: screenKey,
      appBar: AppBar(
        leading: IconButton(
          tooltip: AppStrings.back,
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(AppStrings.createEmployee),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsetsDirectional.all(AppSpacing.xxl),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsetsDirectional.all(AppSpacing.lg),
                child: Text(
                  AppStrings.createEmployeeBody,
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
