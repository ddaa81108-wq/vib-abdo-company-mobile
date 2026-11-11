import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Preview-only gateways 5–8. The live login screen does not use these.
const kPreviewFont = 'Cairo';

const _gold = Color(0xFFE7AE12);
const _goldSoft = Color(0xFFF6E7A8);
const _navy = Color(0xFF071525);
const _navyMid = Color(0xFF12304F);
const _ink = Color(0xFF16130C);
const _paper = Color(0xFFF4EFE4);
const _error = Color(0xFF9F1C14);
const _errorFill = Color(0xFFFFE8E4);

TextStyle previewType(
  double size,
  double weight, {
  Color? color,
  double height = 1.25,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: kPreviewFont,
    fontSize: size,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontWeight: weight >= 700
        ? FontWeight.w700
        : weight >= 600
        ? FontWeight.w600
        : weight >= 500
        ? FontWeight.w500
        : FontWeight.w400,
  );
}

/// One of the four new login compositions. [showError] paints the Arabic
/// refusal the server already returns for a wrong password.
class LoginPreview045 extends StatefulWidget {
  const LoginPreview045({
    super.key,
    required this.option,
    this.showError = false,
  });

  final int option;
  final bool showError;

  @override
  State<LoginPreview045> createState() => _LoginPreview045State();
}

class _LoginPreview045State extends State<LoginPreview045> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _obscure = !_obscure);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: switch (widget.option) {
        6 => _SplitPanel(gate: this),
        7 => _BoldType(gate: this),
        8 => _WaveCard(gate: this),
        _ => _GlassDock(gate: this),
      },
    );
  }
}

class _GlassDock extends StatelessWidget {
  const _GlassDock({required this.gate});

  final _LoginPreview045State gate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF04101F), Color(0xFF0E3A5C), Color(0xFF8A6A22)],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _Aurora())),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _NumberBadge(option: gate.widget.option, light: true),
                ),
                const Spacer(),
                Text(
                  'VIB',
                  textAlign: TextAlign.right,
                  style: previewType(
                    64,
                    700,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'إدارة أسهل .. لعمل أكثر نجاحًا',
                  textAlign: TextAlign.right,
                  style: previewType(14, 500, color: _goldSoft),
                ),
                const SizedBox(height: 28),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0xCC0B1524),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    border: Border.fromBorderSide(
                      BorderSide(color: Color(0x99E7AE12)),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'بوابة المنظومة',
                          style: previewType(18, 700, color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        _GateFields(
                          gate: gate,
                          fill: const Color(0x331C2C44),
                          ink: Colors.white,
                          hint: const Color(0xFFD9C89A),
                          line: const Color(0x66E7AE12),
                        ),
                        const SizedBox(height: 14),
                        _SubmitBar(
                          option: gate.widget.option,
                          fill: _gold,
                          ink: _ink,
                          radius: 14,
                        ),
                      ],
                    ),
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

class _SplitPanel extends StatelessWidget {
  const _SplitPanel({required this.gate});

  final _LoginPreview045State gate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _paper,
      child: Row(
        children: [
          SizedBox(
            width: 132,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: _navy,
                border: BorderDirectional(
                  end: BorderSide(color: _gold, width: 3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 18, 14, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NumberBadge(option: gate.widget.option, light: true),
                    const Spacer(),
                    Text(
                      'VIB',
                      style: previewType(28, 700, color: _gold, height: 1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'بوابة\nالدخول',
                      style: previewType(
                        22,
                        700,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(width: 36, height: 2, color: _gold),
                    const SizedBox(height: 12),
                    Text(
                      'حسابات الإدارة فقط',
                      style: previewType(
                        11,
                        500,
                        color: _goldSoft,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(
                      width: double.infinity,
                      height: 72,
                      child: CustomPaint(painter: _Diamonds()),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'ادخل إلى عملك',
                    style: previewType(26, 700, color: _ink, height: 1.15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اسم المستخدم وكلمة المرور.',
                    style: previewType(13, 500, color: const Color(0xFF6B6256)),
                  ),
                  const Spacer(),
                  _GateFields(
                    gate: gate,
                    fill: Colors.white,
                    ink: _ink,
                    hint: const Color(0xFF8A8174),
                    line: const Color(0xFFE4D8C4),
                  ),
                  const SizedBox(height: 16),
                  _SubmitBar(
                    option: gate.widget.option,
                    fill: _navy,
                    ink: _goldSoft,
                    radius: 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoldType extends StatelessWidget {
  const _BoldType({required this.gate});

  final _LoginPreview045State gate;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFFAF7F2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _NumberBadge(option: gate.widget.option, light: false),
                const Spacer(),
                Text(
                  'VIB',
                  style: previewType(14, 700, color: _gold, letterSpacing: 3),
                ),
              ],
            ),
            const SizedBox(height: 36),
            Text('دخول', style: previewType(72, 700, color: _ink, height: 0.9)),
            Text(
              'المنظومة',
              style: previewType(40, 700, color: _navyMid, height: 1.1),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(width: 72, height: 4, color: _gold),
            ),
            const Spacer(),
            _GateFields(
              gate: gate,
              fill: Colors.transparent,
              ink: _ink,
              hint: const Color(0xFF7A7166),
              line: _ink,
              underline: true,
            ),
            const SizedBox(height: 22),
            _SubmitBar(
              option: gate.widget.option,
              fill: _ink,
              ink: _goldSoft,
              radius: 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveCard extends StatelessWidget {
  const _WaveCard({required this.gate});

  final _LoginPreview045State gate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF07111C)),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _Waves())),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            child: Column(
              children: [
                const Spacer(flex: 3),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F4EC),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(36),
                    ),
                    border: Border.all(
                      color: const Color(0xFFE7AE12),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      const Positioned(top: 10, right: 10, child: _Corner()),
                      const Positioned(
                        bottom: 10,
                        left: 10,
                        child: _Corner(flip: true),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                _NumberBadge(
                                  option: gate.widget.option,
                                  light: false,
                                ),
                                const Spacer(),
                                Text(
                                  'VIB',
                                  style: previewType(
                                    20,
                                    700,
                                    color: _navy,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'أهلًا بك',
                              style: previewType(
                                26,
                                700,
                                color: _ink,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _GateFields(
                              gate: gate,
                              fill: const Color(0xFFF1EBE0),
                              ink: _ink,
                              hint: const Color(0xFF7D7468),
                              line: const Color(0x00000000),
                            ),
                            const SizedBox(height: 14),
                            _SubmitBar(
                              option: gate.widget.option,
                              fill: _navy,
                              ink: _goldSoft,
                              radius: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GateFields extends StatelessWidget {
  const _GateFields({
    required this.gate,
    required this.fill,
    required this.ink,
    required this.hint,
    required this.line,
    this.underline = false,
  });

  final _LoginPreview045State gate;
  final Color fill;
  final Color ink;
  final Color hint;
  final Color line;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final option = gate.widget.option;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          fieldKey: Key('login-preview-$option-user'),
          controller: gate._username,
          label: 'اسم المستخدم',
          fill: fill,
          ink: ink,
          hint: hint,
          line: line,
          underline: underline,
        ),
        const SizedBox(height: 12),
        _Field(
          fieldKey: Key('login-preview-$option-password'),
          controller: gate._password,
          label: 'كلمة المرور',
          fill: fill,
          ink: ink,
          hint: hint,
          line: line,
          underline: underline,
          obscure: gate._obscure,
          toggleKey: Key('login-preview-$option-toggle'),
          onToggle: gate._toggle,
        ),
        if (gate.widget.showError) ...[
          const SizedBox(height: 12),
          _ErrorNote(
            option: option,
            onDark: fill.computeLuminance() < 0.2 && !underline,
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.fill,
    required this.ink,
    required this.hint,
    required this.line,
    required this.underline,
    this.obscure = false,
    this.toggleKey,
    this.onToggle,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final Color fill;
  final Color ink;
  final Color hint;
  final Color line;
  final bool underline;
  final bool obscure;
  final Key? toggleKey;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final radius = underline ? BorderRadius.zero : BorderRadius.circular(12);
    final field = TextField(
      key: fieldKey,
      controller: controller,
      obscureText: obscure,
      showCursor: false,
      enableInteractiveSelection: false,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      style: previewType(15, 600, color: ink),
      cursorColor: ink,
      decoration: InputDecoration(
        isDense: true,
        hintText: label,
        hintStyle: previewType(14, 500, color: hint),
        filled: !underline,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: _edge(radius, line, underline),
        enabledBorder: _edge(radius, line, underline),
        focusedBorder: _edge(radius, _gold, underline),
      ),
    );
    if (onToggle == null) return field;
    return Row(
      children: [
        Expanded(child: field),
        IconButton(
          key: toggleKey,
          tooltip: obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور',
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: ink,
            size: 20,
          ),
        ),
      ],
    );
  }

  InputBorder _edge(BorderRadius radius, Color color, bool under) {
    if (under) {
      return UnderlineInputBorder(
        borderSide: BorderSide(color: color, width: 1.4),
      );
    }
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.option, required this.onDark});

  final int option;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? const Color(0xFFFFD2CC) : _error;
    final bg = onDark ? const Color(0x33B42318) : _errorFill;
    return DecoratedBox(
      key: Key('login-preview-$option-error'),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: onDark ? const Color(0xFFFFB4AA) : _error),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'بيانات الدخول غير صحيحة',
                style: previewType(13, 700, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.option,
    required this.fill,
    required this.ink,
    required this.radius,
  });

  final int option;
  final Color fill;
  final Color ink;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        key: Key('login-preview-$option-submit'),
        borderRadius: BorderRadius.circular(radius),
        onTap: () {},
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              'تسجيل الدخول',
              style: previewType(16, 700, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.option, required this.light});

  final int option;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? _goldSoft : _ink;
    final border = light ? _gold : _ink;
    return Container(
      key: Key('login-preview-number-$option'),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border, width: 1.4),
        color: light ? const Color(0x33110A00) : const Color(0x14E7AE12),
      ),
      child: Text('$option', style: previewType(16, 700, color: fg, height: 1)),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({this.flip = false});

  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: flip ? math.pi : 0,
      child: const SizedBox(
        width: 16,
        height: 16,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _gold, width: 1.6),
              right: BorderSide(color: _gold, width: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _Aurora extends CustomPainter {
  const _Aurora();

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x55E7AE12), Color(0x00000000)],
          ).createShader(
            Rect.fromCircle(center: Offset(size.width * 0.2, 80), radius: 180),
          );
    canvas.drawCircle(Offset(size.width * 0.2, 80), 180, glow);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x55F6E7A8);
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width, 40), radius: 80 + i * 46),
        math.pi * 0.45,
        math.pi * 0.7,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Diamonds extends CustomPainter {
  const _Diamonds();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x99E7AE12);
    for (var i = 0; i < 3; i++) {
      final c = Offset(18.0 + i * 28, size.height / 2);
      final path = Path()
        ..moveTo(c.dx, c.dy - 10)
        ..lineTo(c.dx + 8, c.dy)
        ..lineTo(c.dx, c.dy + 10)
        ..lineTo(c.dx - 8, c.dy)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Waves extends CustomPainter {
  const _Waves();

  @override
  void paint(Canvas canvas, Size size) {
    void stroke(double y, double amp, double phase, Color color, double width) {
      final path = Path();
      for (var x = 0.0; x <= size.width; x += 3) {
        final dy = amp * math.sin((x / size.width) * math.pi * 3 + phase);
        final p = Offset(x, y + dy);
        if (x == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color,
      );
    }

    stroke(size.height * 0.18, 16, 0.4, const Color(0x332C5F8A), 18);
    stroke(size.height * 0.28, 22, 1.2, const Color(0x441E4E78), 10);
    stroke(size.height * 0.22, 12, 2.1, const Color(0x99E7AE12), 1.2);
    stroke(size.height * 0.78, 18, 0.8, const Color(0x66E7AE12), 1.1);

    final geo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xAAE7AE12);
    final origin = Offset(size.width * 0.72, 54);
    final diamond = Path()
      ..moveTo(origin.dx, origin.dy - 22)
      ..lineTo(origin.dx + 22, origin.dy)
      ..lineTo(origin.dx, origin.dy + 22)
      ..lineTo(origin.dx - 22, origin.dy)
      ..close();
    canvas.drawPath(diamond, geo);
    canvas.drawCircle(Offset(48, 70), 16, geo);
    canvas.drawLine(const Offset(28, 96), Offset(size.width * 0.42, 120), geo);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
