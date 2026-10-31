import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../strings.dart';
import '../theme.dart';
import '../tokens.dart';

/// Which server a build talks to. Rule 6: every test build shows it.
enum BuildEnvironmentKind { fake, staging, production, other }

/// Hosts named by the build rules. Any other host is [BuildEnvironmentKind.other].
const kStagingApiHost = 'staging.vip2100.com';
const kProductionApiHost = 'vip2100.com';

@immutable
class BuildEnvironment {
  const BuildEnvironment._(this.kind, this.host);

  final BuildEnvironmentKind kind;

  /// Lowercase API_BASE host. Empty for fake mode and for a value with no host.
  final String host;

  /// Badge text, or null when no badge is shown (production).
  String? get label => switch (kind) {
    BuildEnvironmentKind.fake => AppStrings.envFake,
    BuildEnvironmentKind.staging => AppStrings.envStaging,
    BuildEnvironmentKind.production => null,
    BuildEnvironmentKind.other =>
      host.isEmpty ? AppStrings.envUnknown : AppStrings.envOtherHost(host),
  };

  @override
  bool operator ==(Object other) =>
      other is BuildEnvironment && other.kind == kind && other.host == host;

  @override
  int get hashCode => Object.hash(kind, host);

  @override
  String toString() => 'BuildEnvironment($kind, $host)';
}

/// Pure mapping from the two defines `ApiConfig.fromEnvironment` reads.
///
/// - `USE_FAKE_API=true`: fake, whatever `API_BASE` says (fake mode ignores it).
/// - Host `staging.vip2100.com`: staging.
/// - Host `vip2100.com`: production, no badge.
/// - Any other host, including `www.vip2100.com`, localhost, or a missing or
///   unparsable value: other. It shows a badge, so a build that talks to an
///   unexpected server is never mistaken for production.
///
/// Only the host is compared. Scheme and port do not change the result.
BuildEnvironment resolveBuildEnvironment({
  required bool useFakeApi,
  required String apiBase,
}) {
  if (useFakeApi) {
    return const BuildEnvironment._(BuildEnvironmentKind.fake, '');
  }
  final host = (Uri.tryParse(apiBase.trim())?.host ?? '').toLowerCase();
  final kind = switch (host) {
    kStagingApiHost => BuildEnvironmentKind.staging,
    kProductionApiHost => BuildEnvironmentKind.production,
    _ => BuildEnvironmentKind.other,
  };
  return BuildEnvironment._(kind, host);
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

/// The pill itself. Colours are the review/critical chip tokens of the theme.
class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({required this.environment, super.key});

  final BuildEnvironment environment;

  @override
  Widget build(BuildContext context) {
    final label = environment.label;
    if (label == null) return const SizedBox.shrink();
    final status = context.statusColors;
    // Fake data is a review state. A real non-production server is critical.
    final fake = environment.kind == BuildEnvironmentKind.fake;
    final background = fake ? status.chipReviewBg : status.chipCriticalBg;
    final foreground = fake ? status.chipReviewFg : status.chipCriticalFg;
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
