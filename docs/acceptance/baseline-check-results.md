# نتائج خط الأساس: `tool/check.sh`

- **المستودع:** `vib-abdo-company-mobile`
- **الفرع عند التشغيل:** `main`
- **الالتزام:** `fea12dd` (Merge pull request #2)
- **تاريخ التشغيل:** 2026-10-20
- **السكربت:** `tool/check.sh` (يحلل ويختبر التطبيق ثم `packages/api_layer`، مع `set -euo pipefail`)

## تجهيز سلسلة الأدوات

`flutter` لم يكن موجودًا في `PATH` عند بداية الجولة (`command not found`، رمز الخروج 127).

ما جُرِّب:

1. تنزيل أرشيف Flutter المستقر المطابق لـ `README.md` و`pubspec.yaml`:
   `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.7-stable.tar.xz` (حوالي 1.5 GiB). التنزيل اكتمل.
2. فك الضغط إلى `/opt` فشل: `tar: flutter: Cannot mkdir: Permission denied`. لا توجد صلاحية كتابة على `/opt`.
3. فك الضغط إلى `$HOME/sdks/flutter` نجح، وأُضيف `bin` إلى `PATH` لهذا التشغيل فقط. لم يُثبَّت Flutter داخل المستودع.

الإصدار المستخدم بعد ذلك:

```text
Flutter 3.47.7 • channel stable • https://github.com/flutter/flutter.git
Framework • revision abaf9c5237 (12 days ago) • 2026-10-08 09:51:21 -0700
Engine • hash d8a2d6c768c334d53e16277f837970ffa1e2de81 (revision deb287481e) (13 days ago) • 2026-10-07 17:09:12.000Z
Tools • Dart 3.13.5 • DevTools 2.60.0
Dart SDK version: 3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on "linux_x64"
```

أُوقف إرسال إحصاءات Flutter (`flutter config --no-analytics`) قبل التشغيل.

## نتيجة `tool/check.sh` على `main`

**رمز الخروج: 1 (فشل).** السكربت توقف عند `flutter analyze` للتطبيق بسبب `set -e`. لم يصل إلى `flutter test` للتطبيق، ولا إلى `flutter analyze` / `flutter test` داخل `packages/api_layer`.

### التطبيق: `flutter analyze`

**7 مشكلات، بلا أخطاء `error`.** المدة حوالي 7.6 ثانية. خروج الأمر 1.

| الشدة | القاعدة | الموقع |
|---|---|---|
| info | `unintended_html_in_doc_comment` | `packages/api_layer/lib/core/network/precise_json.dart:25:22` |
| info | `unintended_html_in_doc_comment` | `packages/api_layer/lib/core/network/precise_json.dart:25:45` |
| info | `unintended_html_in_doc_comment` | `packages/api_layer/lib/core/realtime/polling_realtime_service.dart:8:44` |
| info | `unintended_html_in_doc_comment` | `packages/api_layer/lib/core/realtime/realtime_service.dart:4:38` |
| info | `unintended_html_in_doc_comment` | `packages/api_layer/lib/core/realtime/realtime_service.dart:5:45` |
| info | `unintended_html_in_doc_comment` | `packages/api_layer/lib/data/models/home_models.dart:10:32` |
| warning | `unused_import` | `test/qa_round_test.dart:4:8` (`package:flutter_riverpod/flutter_riverpod.dart`) |

المخرجات الحرفية لكتلة المشكلات:

```text
   info • Angle brackets will be interpreted as HTML. Try using backticks around the content with angle brackets, or try replacing `<` with `&lt;` and `>` with `&gt;` • packages/api_layer/lib/core/network/precise_json.dart:25:22 • unintended_html_in_doc_comment
   info • Angle brackets will be interpreted as HTML. Try using backticks around the content with angle brackets, or try replacing `<` with `&lt;` and `>` with `&gt;` • packages/api_layer/lib/core/network/precise_json.dart:25:45 • unintended_html_in_doc_comment
   info • Angle brackets will be interpreted as HTML. Try using backticks around the content with angle brackets, or try replacing `<` with `&lt;` and `>` with `&gt;` • packages/api_layer/lib/core/realtime/polling_realtime_service.dart:8:44 • unintended_html_in_doc_comment
   info • Angle brackets will be interpreted as HTML. Try using backticks around the content with angle brackets, or try replacing `<` with `&lt;` and `>` with `&gt;` • packages/api_layer/lib/core/realtime/realtime_service.dart:4:38 • unintended_html_in_doc_comment
   info • Angle brackets will be interpreted as HTML. Try using backticks around the content with angle brackets, or try replacing `<` with `&lt;` and `>` with `&gt;` • packages/api_layer/lib/core/realtime/realtime_service.dart:5:45 • unintended_html_in_doc_comment
   info • Angle brackets will be interpreted as HTML. Try using backticks around the content with angle brackets, or try replacing `<` with `&lt;` and `>` with `&gt;` • packages/api_layer/lib/data/models/home_models.dart:10:32 • unintended_html_in_doc_comment
warning • Unused import: 'package:flutter_riverpod/flutter_riverpod.dart'. Try removing the import directive • test/qa_round_test.dart:4:8 • unused_import

7 issues found. (ran in 7.6s)
```

سبب ظهور ملاحظات الحزمة مع التطبيق: تحليل التطبيق يمر على الاعتماد المحلي `packages/api_layer` بقواعد `flutter_lints` ^6 في التطبيق. تحليل الحزمة وحدها يستخدم `flutter_lints` ^4 ولا يُظهر هذه الملاحظات (انظر المتابعة أدناه).

`flutter pub get` للتطبيق نجح قبل التحليل. ظهرت رسالة أن 19 حزمة لها إصدارات أحدث غير متوافقة مع القيود. هذا ليس فشلًا للتحليل.

### ما لم يشغّله السكربت

| الخطوة | السبب |
|---|---|
| `flutter test` في جذر التطبيق | لم تُنفَّذ؛ `flutter analyze` أعاد 1 و`set -e` أوقف السكربت |
| `cd packages/api_layer && flutter analyze` | لم تُنفَّذ للسبب نفسه |
| `cd packages/api_layer && flutter test` | لم تُنفَّذ للسبب نفسه |

## متابعة خارج السكربت (نفس الالتزام `fea12dd`)

شُغّلت الخطوات التي تخطاها السكربت يدويًا حتى تكون أرقام الاختبارات معروفة. هذه ليست نتيجة `tool/check.sh`.

| الأمر | النتيجة |
|---|---|
| `flutter test` في جذر التطبيق | **خروج 0.** المُرسِل `compact` انتهى عند `+72: All tests passed!` أي **72 ناجح، 0 فاشل**. لا اختبارات متخطاة في المخرجات |
| `flutter analyze` داخل `packages/api_layer` | **خروج 0.** `No issues found! (ran in 6.0s)` |
| `flutter test` داخل `packages/api_layer` | **خروج 0.** المُرسِل `compact` انتهى عند `+52: All tests passed!` أي **52 ناجح، 0 فاشل** |

`flutter pub get` للحزمة نجح، مع رسالة أن 12 حزمة لها إصدارات أحدث غير متوافقة مع القيود.

## اختبارات القبول المضافة بعد خط الأساس

بعد تسجيل نتيجة `main` أُضيف `test/acceptance/phase_1_3_fake_test.dart` (4 اختبارات). لا تُصلح عيوب الإنتاج.

إعادة التشغيل على الفرع، بنفس Flutter 3.47.7:

| الأمر | النتيجة |
|---|---|
| `flutter test test/acceptance/phase_1_3_fake_test.dart` | **4 ناجحة، 0 فاشلة** |
| `flutter test` لمجموعة التطبيق | **خروج 0.** `+76: All tests passed!` (72 السابقة + 4 الجديدة) |
| `flutter analyze` من جذر التطبيق | **خروج 1.** في هذه الإعادة ظهرت مشكلة واحدة: تحذير `unused_import` في `test/qa_round_test.dart:4`. ملاحظات info الست التي طبعها `tool/check.sh` في التشغيل الأول لم تتكرر بعد `flutter pub get` داخل `packages/api_layer`. التحذير وحده يكفي لفشل السكربت |

معيار المرحلة 1 «ينجح `tool/check.sh`» يبقى **فاشلًا** إلى أن يخرج تحليل التطبيق 0. لم يُعد تشغيل السكربت كاملًا بعد إضافة الاختبارات لأن `set -e` سيتوقف عند التحليل كما في خط الأساس.

## إعادة اختبار DEF-001 على PR #15

التاريخ: 2026-10-20. الفرع: `cursor/fix-def-001-doc-comments-cc17`. الالتزام: `56156a8`. الطلب: https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/15

الأساس `main` بعد دمج PR #4، وهو الذي أزال تحذير `unused_import` من `test/qa_round_test.dart`. هذا الفرع لا يعدّل ذلك الملف.

الأمر: `bash tool/check.sh` من جذر المستودع، مع Flutter 3.47.7 / Dart 3.13.5 على `PATH`.

**رمز الخروج: 0.**

| الخطوة داخل السكربت | النتيجة الفعلية |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 9.4s)` |
| `flutter test` للتطبيق | `+72: All tests passed!` — **72 ناجح، 0 فاشل** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 4.2s)` |
| `flutter test` في `packages/api_layer` | `+52: All tests passed!` — **52 ناجح، 0 فاشل** |

مراجعة الفرق مقابل `main`: أربعة ملفات وخمسة أسطر، وكلها تعليقات. المواضع الستة لـ `unintended_html_in_doc_comment` صارت داخل backticks. لا تغيير سلوكي.

**الحكم:** Fixed in #15 — verified.

اختبارات القبول الأربعة في `test/acceptance/` ليست على هذا الفرع، لذلك العدد 72 هنا يطابق مجموعة `main` لا مجموعة فرع القبول (76). هذا لا يغيّر حكم DEF-001.

## خلاصة خط الأساس

| البند | القيمة |
|---|---|
| `tool/check.sh` | فشل، خروج 1 |
| تحليل التطبيق | 7 مشكلات (6 info + 1 warning)، 0 error |
| اختبارات التطبيق عبر السكربت | لم تُشغَّل |
| اختبارات التطبيق يدويًا على `main` | 72 ناجح / 0 فاشل |
| تحليل `packages/api_layer` عبر السكربت | لم يُشغَّل |
| تحليل `packages/api_layer` يدويًا | 0 مشكلات |
| اختبارات `packages/api_layer` يدويًا | 52 ناجح / 0 فاشل |
| Flutter / Dart | 3.47.7 / 3.13.5 |
| DEF-001 على PR #15 (`56156a8`) | Fixed in #15 — verified. `tool/check.sh` خروج 0: تحليل التطبيق والحزمة بلا مشكلات، 72 و52 اختبارًا ناجحة |
