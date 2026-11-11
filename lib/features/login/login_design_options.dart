import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'login_preview_045.dart';

/// Preview-only login layouts. The live [LoginScreen] is unchanged.
class LoginDesignGallery extends StatelessWidget {
  const LoginDesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final option in [1, 2, 3, 4, 5, 6, 7, 8]) ...[
          Text('خيار $option', style: cairo(14, 800)),
          const SizedBox(height: 8),
          SizedBox(height: 640, child: LoginDesignOption(option: option)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class LoginDesignOption extends StatelessWidget {
  const LoginDesignOption({super.key, required this.option});

  final int option;

  @override
  Widget build(BuildContext context) {
    return switch (option) {
      2 => const _SplitHero(),
      3 => const _CreamMinimal(),
      4 => const _BlackLines(),
      5 || 6 || 7 || 8 => LoginPreview045(option: option),
      _ => const _GlassParticles(),
    };
  }
}

class _GlassParticles extends StatelessWidget {
  const _GlassParticles();

  @override
  Widget build(BuildContext context) {
    return _Frame(
      background: const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFF0B1020), Color(0xFF1A1408), Color(0xFF071018)],
      ),
      particles: true,
      child: _GlassCard(dark: true),
    );
  }
}

class _SplitHero extends StatelessWidget {
  const _SplitHero();

  @override
  Widget build(BuildContext context) {
    return _Frame(
      background: const LinearGradient(
        colors: [Color(0xFF070B16), Color(0xFF111827)],
      ),
      child: Column(
        children: [
          const Expanded(child: Center(child: _Mark(size: 92))),
          _GlassCard(dark: true),
        ],
      ),
    );
  }
}

class _CreamMinimal extends StatelessWidget {
  const _CreamMinimal();

  @override
  Widget build(BuildContext context) {
    return _Frame(
      background: const LinearGradient(
        colors: [Color(0xFFFFF8EC), Color(0xFFF3E6C4)],
      ),
      child: _GlassCard(dark: false),
    );
  }
}

class _BlackLines extends StatelessWidget {
  const _BlackLines();

  @override
  Widget build(BuildContext context) {
    return _Frame(
      background: const LinearGradient(
        colors: [Color(0xFF050505), Color(0xFF14110A)],
      ),
      lines: true,
      child: _GlassCard(dark: true),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.background,
    required this.child,
    this.particles = false,
    this.lines = false,
  });

  final Gradient background;
  final Widget child;
  final bool particles;
  final bool lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: background),
      child: Stack(
        children: [
          if (particles)
            const Positioned.fill(child: CustomPaint(painter: _Dots())),
          if (lines)
            const Positioned.fill(child: CustomPaint(painter: _Lines())),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final ink = dark ? const Color(0xFFF8F1DE) : const Color(0xFF211600);
    final muted = dark ? const Color(0xFFD6C7A1) : const Color(0xFF78716C);
    final field = dark ? const Color(0x66111111) : const Color(0xFFFFFFFF);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: dark ? const Color(0xAA121826) : const Color(0xF2FFFFFF),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFE7AE12).withValues(alpha: 0.7),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66E7AE12), blurRadius: 28),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Mark(size: 64),
              const SizedBox(height: 8),
              Text('تسجيل الدخول', style: cairo(20, 800, color: ink)),
              Text('منظومة VIB', style: cairo(12, 600, color: muted)),
              const SizedBox(height: 16),
              _Field(label: 'اسم المستخدم', fill: field, ink: ink),
              const SizedBox(height: 8),
              _Field(
                label: 'كلمة المرور',
                fill: field,
                ink: ink,
                trailing: Icons.visibility_outlined,
              ),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF6E7A8), Color(0xFFE7AE12)],
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(
                    child: Text(
                      'دخول',
                      style: cairo(16, 800, color: const Color(0xFF211600)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.fill,
    required this.ink,
    this.trailing,
  });

  final String label;
  final Color fill;
  final Color ink;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66E7AE12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: cairo(13, 600, color: ink)),
            ),
            if (trailing != null) Icon(trailing, color: ink, size: 18),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFF3C4), Color(0xFFE7AE12), Color(0xFF8A6A12)],
        ),
        boxShadow: const [BoxShadow(color: Color(0xAAE7AE12), blurRadius: 18)],
      ),
      child: Text(
        'VIB',
        style: cairo(size * 0.28, 800, color: const Color(0xFF211600)),
      ),
    );
  }
}

class _Dots extends CustomPainter {
  const _Dots();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x55E7AE12);
    for (var i = 0; i < 18; i++) {
      canvas.drawCircle(
        Offset((i * 47) % size.width, (i * 73) % size.height),
        2 + (i % 3),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Lines extends CustomPainter {
  const _Lines();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33E7AE12)
      ..strokeWidth = 1;
    for (var y = 24.0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y * 0.92), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
