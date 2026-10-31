import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';

/// Which server a build talks to. Rule 6: every test build shows it.
enum BuildEnvironmentKind {
  fake,
  staging,
  production,

  /// Host `vip2100.com` without `https` on the default port. Never production.
  productionMismatch,
  other,
}

/// Hosts named by the build rules. Any other host is [BuildEnvironmentKind.other].
const kStagingApiHost = 'staging.vip2100.com';
const kProductionApiHost = 'vip2100.com';

@immutable
class BuildEnvironment {
  const BuildEnvironment._(this.kind, this.host, [this.origin = '']);

  final BuildEnvironmentKind kind;

  /// Lowercase API_BASE host. Empty for fake mode and for a value with no host.
  final String host;

  /// `scheme://host[:port]`, set only for [BuildEnvironmentKind.productionMismatch].
  final String origin;

  /// Badge text, or null when no badge is shown (production).
  String? get label => switch (kind) {
    BuildEnvironmentKind.fake => AppStrings.envFake,
    BuildEnvironmentKind.staging => AppStrings.envStaging,
    BuildEnvironmentKind.production => null,
    BuildEnvironmentKind.productionMismatch => AppStrings.envProductionMismatch,
    BuildEnvironmentKind.other =>
      host.isEmpty ? AppStrings.envUnknown : AppStrings.envOtherHost(host),
  };

  @override
  bool operator ==(Object other) =>
      other is BuildEnvironment &&
      other.kind == kind &&
      other.host == host &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(kind, host, origin);

  @override
  String toString() => 'BuildEnvironment($kind, $host, $origin)';
}

/// Pure mapping from the two defines `ApiConfig.fromEnvironment` reads.
///
/// - `USE_FAKE_API=true`: fake, whatever `API_BASE` says (fake mode ignores it).
/// - Host exactly `staging.vip2100.com`: staging.
/// - Exactly `https://vip2100.com` on the default port (none or 443):
///   production, no badge.
/// - Host `vip2100.com` with `http` or another port: production mismatch, a
///   warning badge.
/// - Any other host, including `www.vip2100.com`, lookalikes such as
///   `vip2100.com.evil.test` or `evilvip2100.com`, localhost, or a missing or
///   unparsable value: other. It shows a badge, so a build that talks to an
///   unexpected server is never mistaken for production.
///
/// Hosts are compared whole and case-insensitively, never by suffix.
BuildEnvironment resolveBuildEnvironment({
  required bool useFakeApi,
  required String apiBase,
}) {
  if (useFakeApi) {
    return const BuildEnvironment._(BuildEnvironmentKind.fake, '');
  }
  final uri = Uri.tryParse(apiBase.trim());
  final host = (uri?.host ?? '').toLowerCase();
  if (uri == null || host != kProductionApiHost) {
    final kind = host == kStagingApiHost
        ? BuildEnvironmentKind.staging
        : BuildEnvironmentKind.other;
    return BuildEnvironment._(kind, host);
  }
  final scheme = uri.scheme.toLowerCase();
  // Dart drops a default port, so `https://vip2100.com:443` has port 443 too.
  if (scheme == 'https' && uri.port == 443) {
    return const BuildEnvironment._(
      BuildEnvironmentKind.production,
      kProductionApiHost,
    );
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return BuildEnvironment._(
    BuildEnvironmentKind.productionMismatch,
    host,
    '$scheme://$host$port',
  );
}

/// This build, from the same compile-time defines as `ApiConfig.fromEnvironment`.
final BuildEnvironment kBuildEnvironment = resolveBuildEnvironment(
  useFakeApi: kUseFakeApiFromEnvironment,
  apiBase: const String.fromEnvironment('API_BASE'),
);

/// App-level wrapper that draws the environment pill over every route.
///
/// The pill straddles the bottom edge of the toolbar, at the horizontal centre
/// ([lift]). That band is empty on every screen: toolbar icons end 16px above
/// the edge, and page content starts with padding below it. It ignores pointers, so taps
/// reach whatever is underneath. Production draws nothing.
class EnvironmentBadgeOverlay extends StatelessWidget {
  const EnvironmentBadgeOverlay({
    required this.child,
    required this.environment,
    super.key,
  });

  final Widget child;
  final BuildEnvironment environment;

  static const badgeKey = Key('environment-badge');

  /// Pill height. The 1px border is painted inside it.
  static const height = 20.0;

  /// How far the pill's top sits above the toolbar's bottom edge. Toolbar
  /// icons end 16px above that edge and the title line box about 13px above
  /// it, so 12 clears both. 8px of the pill reaches into the page, which
  /// starts with padding.
  static const lift = 12.0;

  @override
  Widget build(BuildContext context) {
    final label = environment.label;
    if (label == null) return child;
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight - lift;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        PositionedDirectional(
          top: top,
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          child: IgnorePointer(
            child: Center(child: EnvironmentBadge(environment: environment)),
          ),
        ),
      ],
    );
  }
}

/// Fill and text of the pill. Fake data uses the review-status chip pair
/// (yellow, the same in both themes; a status colour, not a money colour).
/// Every real server that is not production uses the theme's neutral inverse
/// surface pair, which flips between light and dark.
(Color, Color) environmentBadgeColors(
  ThemeData theme,
  BuildEnvironmentKind kind,
) {
  if (kind == BuildEnvironmentKind.fake) {
    final status = theme.extension<AppStatusColors>()!;
    return (status.chipReviewBg, status.chipReviewFg);
  }
  final scheme = theme.colorScheme;
  return (scheme.inverseSurface, scheme.onInverseSurface);
}

/// The pill itself. Colours come from [environmentBadgeColors].
class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({required this.environment, super.key});

  final BuildEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final label = environment.label;
    if (label == null) return const SizedBox.shrink();
    final (background, foreground) = environmentBadgeColors(
      Theme.of(context),
      environment.kind,
    );
    final base = Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return Semantics(
      container: true,
      label: '${AppStrings.envSemanticsPrefix}$label',
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              key: EnvironmentBadgeOverlay.badgeKey,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: foreground, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: SizedBox(
                  height: EnvironmentBadgeOverlay.height,
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base.copyWith(
                        color: foreground,
                        fontSize: 11,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
