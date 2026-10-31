# تقرير النسخة: VIB <versionName> (<versionCode>)

> **نسخة تجريبية على staging.** بُنيت بـ `API_BASE=https://staging.vip2100.com` (عبر `--dart-define` فقط). ليست نسخة إنتاج، ولا تُرفع إلى Play كنسخة إنتاج.
> لا يحوي هذا التقرير أي كلمة مرور أو محتوى `key.properties` أو بيانات دخول.

## 1. الهوية

| البند | القيمة |
|---|---|
| التطبيق / `applicationId` | `com.vip2100.vib` |
| versionName / versionCode | `<1.0.0>` / `<1>` |
| commit البناء | `<sha>` (فرع `main`، بعد دمج `<PRs>`) |
| تاريخ البناء | `<YYYY-MM-DD HH:MM>` (توقيت طرابلس، UTC+2) |
| جهاز البناء | جهاز البناء المشترك (box) |
| الخادم | `https://staging.vip2100.com` (staging، تجريبي) |
| `USE_FAKE_API` | Debug: `true`؛ Release وAAB: `false` |

## 2. الأدوات

| الأداة | النسخة |
|---|---|
| Flutter / Dart | `<3.47.7>` / `<3.13.5>` |
| JDK | `<Temurin 17.0.x>` |
| Gradle / AGP / Kotlin | `<9.3.1>` / `<9.1.0>` / `<2.4.0>` |
| compileSdk / targetSdk / minSdk | `<36>` / `<36>` / `<24>` |
| build-tools / NDK | `<36.0.0>` / `<28.2.13676358>` |

## 3. المخرجات

| الملف | الحجم (بايت) | SHA-256 | التوقيع |
|---|---|---|---|
| `app-debug.apk` | `<>` | `<>` | مفتاح debug |
| `app-release.apk` | `<>` | `<>` | `vib-release` |
| `app-release.aab` | `<>` | `<>` | `vib-release` |

## 4. شهادة التوقيع

| البند | القيمة |
|---|---|
| alias | `vib-release` |
| الموضوع | `CN=VIB, O=Abdo Company, C=LY` |
| SHA-1 | `<1B:5E:...>` |
| SHA-256 | `<40:B5:...>` |
| صالحة من / حتى | `<>` / `<>` |
| `apksigner verify` | `<Verifies, v2+v3>` |
| `keytool -printcert -jarfile` (AAB) | `<الموضوع والبصمة مطابقان>` |

## 5. الفحوص

| الفحص | النتيجة | الدليل |
|---|---|---|
| CI على commit البناء: Analyze, test, and debug APK | `<>` | `<رابط>` |
| CI: Negative permission tests | `<>` | `<رابط>` |
| CI: Release build rejects fake API | `<>` | `<رابط>` |
| `tool/check_release_rejects_fake_api.sh` محليًا | `<>` | — |
| `tool/scan_release_apk.py app-release.apk` | `<>` | — |
| `aapt2 dump badging`: الحزمة والإصدار | `<>` | — |
| لا كلمة مرور في السجلات (عدد التطابقات) | `<0>` | — |
| خطة التثبيت (`INSTALL.ar.md`) | `<>` | `<>` |

## 6. التغييرات والمشاكل المعروفة

- سجل التغييرات: `docs/release/CHANGELOG.ar.md`.
- المشاكل المعروفة: `docs/release/KNOWN_ISSUES.ar.md` (مراجعة على commit البناء).

## 7. ملاحظات

- `<أي ملاحظة: إعادة محاولة 429، تحذيرات Gradle، إلخ>`
