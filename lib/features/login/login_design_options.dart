import 'package:flutter/material.dart';

import '../../ui/strings.dart';
import '../../ui/theme.dart';

/// Review-only login layouts. The live screen stays [LoginScreen].
class LoginDesignOption extends StatelessWidget {
  const LoginDesignOption({required this.option, super.key});

  final int option;

  @override
  Widget build(BuildContext context) {
    return switch (option) {
      1 => const _SplitGold(),
      2 => const _GlassCard(),
      3 => const _PillFields(),
      _ => const _NightLedger(),
    };
  }
}

class _Fields extends StatelessWidget {
  const _Fields({this.lightOnDark = false});

  final bool lightOnDark;

  @override
  Widget build(BuildContext context) {
    final ink = lightOnDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final fill = lightOnDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);
    InputDecoration box(String label) => InputDecoration(
      labelText: label,
      labelStyle: cairo(13, 700, color: ink.withValues(alpha: 0.7)),
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(decoration: box(AppStrings.username)),
        const SizedBox(height: 12),
        TextField(obscureText: true, decoration: box(AppStrings.password)),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE7AE12),
            foregroundColor: const Color(0xFF211600),
            minimumSize: const Size.fromHeight(48),
            textStyle: cairo(16, 800),
          ),
          onPressed: () {},
          child: const Text(AppStrings.signIn),
        ),
      ],
    );
  }
}

class _SplitGold extends StatelessWidget {
  const _SplitGold();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0B1020),
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFF1E3A8A), Color(0xFF0B1020)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.brandMark,
                  style: cairo(64, 800, color: const Color(0xFFF5C542)),
                ),
                Text(
                  AppStrings.slogan,
                  style: cairo(14, 600, color: const Color(0xFFE2E8F0)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBF0),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: const SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: _Fields(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF172554), Color(0xFF4C1D95)],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0xCC0F172A),
            borderRadius: BorderRadius.all(Radius.circular(24)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFF5C542))),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'VIB',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFF5C542),
                  ),
                ),
                SizedBox(height: 16),
                _Fields(lightOnDark: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillFields extends StatelessWidget {
  const _PillFields();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFF5F7FB),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 48, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مرحبًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E3A8A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppStrings.slogan,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 14,
                color: Color(0xFF475569),
              ),
            ),
            SizedBox(height: 36),
            _Fields(),
          ],
        ),
      ),
    );
  }
}

class _NightLedger extends StatelessWidget {
  const _NightLedger();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF111111),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(20)),
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFFE7AE12), width: 1.6),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  AppStrings.brandWord,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE7AE12),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  AppStrings.organization,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 13,
                    color: Color(0xFFE7E5E4),
                  ),
                ),
                SizedBox(height: 24),
                _Fields(lightOnDark: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
