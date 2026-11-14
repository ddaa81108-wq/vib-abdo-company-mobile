import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vib_abdo_company_mobile/notifications/push_payload.dart';
import 'package:vib_abdo_company_mobile/notifications/tray_notification.dart';

import 'shell_screenshots_test.dart' show loadScreenshotFonts, saveShot;

void main() {
  testWidgets('093 expanded notification shade', (tester) async {
    await tester.runAsync(loadScreenshotFonts);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(360, 640);

    final tray = trayForServer(
      notificationFromShadeData({
        'notificationId': 'n-93',
        'operationType': 'customer.payment',
        'actorName': 'أحمد',
        'actorRole': 'employee',
        'subjectName': 'سالم',
        'subjectSection': 'customers',
        'amountUnits': '1500',
        'paymentMode': 'partial',
        'createdAt': '2026-11-14T13:25:00Z',
        'systemName': 'VIB',
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF101114),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _ExpandedShade(title: tray.title, body: tray.body),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await saveShot(tester, 'fix093-expanded-shade');
  }, tags: ['screenshots']);
}

class _ExpandedShade extends StatelessWidget {
  const _ExpandedShade({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'الآن',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Color(0xFFB9BDC7),
                fontSize: 12,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
            const SizedBox(height: 6),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.notifications, color: Color(0xFFE7C35A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBMPlexSansArabic',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Color(0xFFF4F5F7),
                fontSize: 14,
                height: 1.45,
                fontFamily: 'IBMPlexSansArabic',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
