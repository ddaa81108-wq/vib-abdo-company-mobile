part of 'collections_screen.dart';

/// Opt-in local presentation. Server data, permissions, card state and action
/// callbacks stay in collections_screen.dart and its existing view model.
class _CollectionsHeader extends StatelessWidget {
  const _CollectionsHeader({required this.groups, required this.order});
  final List<Widget> groups;
  final List<int> order;

  @override
  Widget build(BuildContext context) {
    if (!_whiteGoldLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: groups,
      );
    }
    return Theme(
      data: buildAppTheme(Brightness.light),
      child: _GoldCollectionsFrame(
        key: const Key('collections-white-gold-header'),
        white: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < order.length; i++) ...[
              if (i > 1)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Divider(height: 1, color: Color(0xFFECDCA8)),
                ),
              groups[order[i]],
            ],
          ],
        ),
      ),
    );
  }
}

class _HeaderFilterPanel extends StatelessWidget {
  const _HeaderFilterPanel({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      _whiteGoldLayout ? child : CollectionsPanel(child: child);
}

class _CollectionsListFrame extends StatelessWidget {
  const _CollectionsListFrame({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => _whiteGoldLayout
      ? _GoldCollectionsFrame(
          key: const Key('collections-gold-list-frame'),
          child: child,
        )
      : CollectionsPanel(child: child);
}

/// One continuous metallic frame with a solid lower lip, shared by the control
/// panel and the enclosing cards panel. Static paint: no pulsing or animation.
class _GoldCollectionsFrame extends StatelessWidget {
  const _GoldCollectionsFrame({
    required this.child,
    this.white = false,
    super.key,
  });
  final Widget child;
  final bool white;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(20));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFAB7915),
            Color(0xFFFFEAAA),
            Color(0xFFDAAA23),
            Color(0xFFFFE58C),
            Color(0xFFB9850E),
          ],
          stops: [0, .25, .5, .78, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1E72520D),
            blurRadius: 7,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: white
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.white, Color(0xFFFBFCFF), Colors.white],
                  )
                : null,
            color: white ? null : context.look.card,
          ),
          child: Padding(padding: const EdgeInsets.all(10), child: child),
        ),
      ),
    );
  }
}
