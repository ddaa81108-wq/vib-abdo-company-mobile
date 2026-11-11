import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_api_layer/api_layer.dart';

import '../../ui/section_labels.dart';
import '../../ui/theme.dart';

/// Review-only icon sets on the home grid Ali kept. The live home is unchanged.
class HomeDesignOption extends StatelessWidget {
  const HomeDesignOption({required this.option, super.key});

  /// 1 duotone, 2 glass, 3 depth, 4 iOS gradient square.
  final int option;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF0B1020) : const Color(0xFFF4F1EA),
      child: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(14),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.15,
        children: [
          for (final section in SectionKey.values)
            DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF151C2C) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: dark
                      ? const Color(0xFF2A3348)
                      : const Color(0xFFE7E0D2),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Mark(option: option, section: section),
                  const SizedBox(height: 8),
                  Text(
                    sectionLabel(section),
                    textAlign: TextAlign.center,
                    style: cairo(
                      13,
                      800,
                      color: dark ? Colors.white : const Color(0xFF1C1917),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Set 1 from the icon review: gold stroke on a navy tile. No preview number.
class HomeIconMark extends StatelessWidget {
  const HomeIconMark({super.key, required this.section, this.size = 72})
    : settings = false;

  const HomeIconMark.settings({super.key, this.size = 72})
    : section = null,
      settings = true;

  final SectionKey? section;
  final bool settings;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = CustomPaint(
      size: Size(size * 0.58, size * 0.58),
      painter: settings
          ? const _SettingsGlyphPainter()
          : _GlyphPainter(section: section!, light: false),
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF14213D),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: const Color(0xFFE7AE12), width: 1.4),
      ),
      child: glyph,
    );
  }
}

class _SettingsGlyphPainter extends CustomPainter {
  const _SettingsGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF6E7A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width * 0.18, paint);
    for (var i = 0; i < 4; i++) {
      final angle = i * 1.5708;
      final inner = size.width * 0.28;
      final outer = size.width * 0.42;
      canvas.drawLine(
        c + Offset(inner * math.cos(angle), inner * math.sin(angle)),
        c + Offset(outer * math.cos(angle), outer * math.sin(angle)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Mark extends StatelessWidget {
  const _Mark({required this.option, required this.section});

  final int option;
  final SectionKey section;

  @override
  Widget build(BuildContext context) {
    final glyph = CustomPaint(
      size: const Size(46, 46),
      painter: _GlyphPainter(
        section: section,
        light: option == 4 || option == 3,
      ),
    );
    return switch (option) {
      2 => _glass(glyph),
      3 => _depth(glyph),
      4 => _ios(glyph),
      _ => HomeIconMark(section: section),
    };
  }

  Widget _glass(Widget glyph) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE6FFFFFF), Color(0x66C4B5FD), Color(0x6693C5FD)],
        ),
        border: Border.all(color: const Color(0xCCFFFFFF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x553B82F6),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ShaderMask(
        shaderCallback: (rect) =>
            const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF2563EB)])
                .createShader(rect),
        child: glyph,
      ),
    );
  }

  Widget _depth(Widget glyph) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 8,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF7C2D12),
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFBBF24), Color(0xFFB45309)],
                ),
              ),
              child: glyph,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ios(Widget glyph) {
    return Container(
      width: 68,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), Color(0xFF059669), Color(0xFF064E3B)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66064E3B),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: glyph,
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({required this.section, required this.light});

  final SectionKey section;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = light ? Colors.white : const Color(0xFFF6E7A8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = (light ? Colors.white : const Color(0xFFE7AE12)).withValues(
        alpha: 0.9,
      )
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    switch (section) {
      case SectionKey.customers:
        canvas.drawCircle(Offset(w * 0.5, h * 0.32), w * 0.16, paint);
        final body = Path()
          ..moveTo(w * 0.22, h * 0.82)
          ..quadraticBezierTo(w * 0.5, h * 0.48, w * 0.78, h * 0.82);
        canvas.drawPath(body, paint);
      case SectionKey.collections:
        canvas.drawCircle(Offset(w * 0.4, h * 0.48), w * 0.2, paint);
        canvas.drawCircle(Offset(w * 0.6, h * 0.48), w * 0.2, fill);
      case SectionKey.companies:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.22, h * 0.28, w * 0.56, h * 0.52),
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.4, h * 0.42),
          Offset(w * 0.4, h * 0.52),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.6, h * 0.42),
          Offset(w * 0.6, h * 0.52),
          paint,
        );
      case SectionKey.libyanDeposits:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.16, h * 0.32, w * 0.68, h * 0.4),
            const Radius.circular(6),
          ),
          paint,
        );
        canvas.drawCircle(Offset(w * 0.72, h * 0.52), 3, fill);
      case SectionKey.egyptianDeposits:
        canvas.drawLine(
          Offset(w * 0.2, h * 0.35),
          Offset(w * 0.7, h * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.7, h * 0.35),
          Offset(w * 0.55, h * 0.22),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.3, h * 0.68),
          Offset(w * 0.8, h * 0.68),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.3, h * 0.68),
          Offset(w * 0.45, h * 0.8),
          paint,
        );
      case SectionKey.masraweya:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.25, h * 0.2, w * 0.5, h * 0.6),
            const Radius.circular(3),
          ),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.36, h * 0.38),
          Offset(w * 0.64, h * 0.38),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.36, h * 0.5),
          Offset(w * 0.64, h * 0.5),
          paint,
        );
      case SectionKey.purchases:
        final bag = Path()
          ..moveTo(w * 0.28, h * 0.4)
          ..lineTo(w * 0.72, h * 0.4)
          ..lineTo(w * 0.64, h * 0.82)
          ..lineTo(w * 0.36, h * 0.82)
          ..close();
        canvas.drawPath(bag, paint);
        canvas.drawArc(
          Rect.fromLTWH(w * 0.34, h * 0.16, w * 0.32, h * 0.28),
          3.4,
          2.6,
          false,
          paint,
        );
      case SectionKey.treasury:
        canvas.drawLine(
          Offset(w * 0.18, h * 0.4),
          Offset(w * 0.5, h * 0.18),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.5, h * 0.18),
          Offset(w * 0.82, h * 0.4),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.28, h * 0.4),
          Offset(w * 0.28, h * 0.78),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.5, h * 0.4),
          Offset(w * 0.5, h * 0.78),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.72, h * 0.4),
          Offset(w * 0.72, h * 0.78),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.2, h * 0.78),
          Offset(w * 0.8, h * 0.78),
          paint,
        );
      case SectionKey.reports:
        canvas.drawLine(
          Offset(w * 0.22, h * 0.75),
          Offset(w * 0.22, h * 0.45),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.42, h * 0.75),
          Offset(w * 0.42, h * 0.3),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.62, h * 0.75),
          Offset(w * 0.62, h * 0.5),
          paint,
        );
        canvas.drawLine(
          Offset(w * 0.78, h * 0.75),
          Offset(w * 0.78, h * 0.22),
          fill,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter oldDelegate) =>
      oldDelegate.section != section || oldDelegate.light != light;
}
