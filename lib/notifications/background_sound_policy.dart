import 'package:flutter/widgets.dart';

/// What the phone can do about a notification sound without a server push.
///
/// The realtime socket lives in the Flutter engine. A foreground service can
/// keep that process runnable while the activity is paused or the screen is
/// locked. It cannot keep the engine after the activity is destroyed, and it
/// cannot start itself after a reboot: Android 12+ blocks a foreground
/// service start from `BOOT_COMPLETED` unless the app is exempt, and this
/// app has no push token path that would deliver a sound with the process
/// dead. That case needs server push (FCM).
abstract final class BackgroundSoundPolicy {
  /// Keep the SSE connection. Signed out and `detached` stop it. Paused and
  /// hidden (home button, screen lock) keep it.
  static bool keepRealtime({
    required bool signedIn,
    required AppLifecycleState? phase,
  }) {
    if (!signedIn) return false;
    return phase != AppLifecycleState.detached;
  }

  /// Ask Android to hold the process with a low-priority ongoing
  /// notification. Same window as [keepRealtime]: while the activity exists.
  static bool holdProcess({
    required bool signedIn,
    required AppLifecycleState? phase,
  }) {
    return keepRealtime(signedIn: signedIn, phase: phase);
  }
}

/// One row of the delivery report. Tests lock the wording.
class BackgroundSoundState {
  const BackgroundSoundState({
    required this.name,
    required this.socket,
    required this.sound,
    required this.why,
  });

  final String name;
  final String socket;
  final String sound;
  final String why;
}

const backgroundSoundStates = <BackgroundSoundState>[
  BackgroundSoundState(
    name: 'التطبيق مفتوح',
    socket: 'SSE يعمل',
    sound: 'قناة الأهمية العالية مع صوت الجهاز',
    why: 'اللافتة داخل التطبيق والنطق، وصوت شريط النظام.',
  ),
  BackgroundSoundState(
    name: 'في الخلفية أو الشاشة مقفلة',
    socket: 'SSE يبقى والعملية في خدمة أمامية',
    sound: 'صوت القناة العالية إن وصل الحدث والعملية حية',
    why:
        'الخدمة تطلب من أندرويد ألا يجمّد العملية. Doze قد يؤخر الشبكة لاحقًا.',
  ),
  BackgroundSoundState(
    name: 'أُزيل من الأخيرة أو أُغلق بالقوة',
    socket: 'المحرك يموت مع النشاط',
    sound: 'لا يصل في وقته',
    why: 'الخدمة لا تشغّل محرك Flutter. التسليم الموثوق يحتاج FCM.',
  ),
  BackgroundSoundState(
    name: 'بعد إعادة التشغيل',
    socket: 'لا يبدأ وحده',
    sound: 'لا يصل حتى يفتح المستخدم التطبيق',
    why: 'لا BOOT_COMPLETED. بدء خدمة أمامية من الإقلاع مقيّد منذ أندرويد 12.',
  ),
];
