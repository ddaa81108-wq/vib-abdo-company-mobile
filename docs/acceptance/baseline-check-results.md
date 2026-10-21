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

## إعادة اختبار Fake API على PR #17

التاريخ: 2026-10-20. الفرع: `cursor/fake-api-qa-defects-566d`. الالتزام: `350e051`. الطلب: https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/17

الأمر: `bash tool/check.sh` من جذر المستودع، مع Flutter 3.47.7 / Dart 3.13.5 على `PATH`.

**رمز الخروج: 0.**

| الخطوة داخل السكربت | النتيجة الفعلية |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 7.7s)` |
| `flutter test` للتطبيق | `+74: All tests passed!` — **74 ناجح، 0 فاشل** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 3.3s)` |
| `flutter test` في `packages/api_layer` | `+56: All tests passed!` — **56 ناجح، 0 فاشل** |

الـ 74 تشمل اختباري الودجت في `test/fake_server_defects_test.dart`. الـ 56 تشمل اختبارات `packages/api_layer/test/fake_qa_defects_test.dart`. أحكام العيوب: DEF-006 وDEF-008 وDEF-009 وDEF-011 كلها **Verified**. DEF-002 إلى DEF-005 بقيت مفتوحة. التفاصيل في `defects.md`.

## إعادة اختبار الرئيسية على PR #17 عند `c4edd59`

التاريخ: 2026-10-20. الفرع: `cursor/fake-api-qa-defects-566d`. الالتزام: `c4edd59`.

الأمر: `bash tool/check.sh` من جذر المستودع، مع Flutter 3.47.7 / Dart 3.13.5 على `PATH`.

**رمز الخروج: 0.**

| الخطوة داخل السكربت | النتيجة الفعلية |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 3.3s)` |
| `flutter test` للتطبيق | `+74: All tests passed!` — **74 ناجح، 0 فاشل** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 0.6s)` |
| `flutter test` في `packages/api_layer` | `+57: All tests passed!` — **57 ناجح، 0 فاشل** |

فلترة الرئيسية ونسخ الإجماليات مغطاة في اختبار الحزمة واختبار الدخول. إعادة إنتاج محلية للأدوار الخمسة أكدت الجدول في `defects.md` ثم حُذف المسبار. P2-01 تبقى **Partially**: الأرقام تطابق صفحات الأقسام الموجودة في الحمولة، ولا مقارنة مع الويب.

## إعادة اختبار DEF-002 إلى DEF-005 على PR #24

التاريخ: 2026-10-21. الفرع: `cursor/fix-qa-blocking-defects-3aad`. الالتزام: `4260c16`. الأساس `main` عند `ba44462`، وليس فرع #17.

الأمر: `bash tool/check.sh` من جذر المستودع، مع Flutter 3.47.7 / Dart 3.13.5 على `PATH`.

**رمز الخروج: 0.**

| الخطوة داخل السكربت | النتيجة الفعلية |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 2.8s)` |
| `flutter test` للتطبيق | `+83: All tests passed!` — **83 ناجح، 0 فاشل** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 0.5s)` |
| `flutter test` في `packages/api_layer` | `+56: All tests passed!` — **56 ناجح، 0 فاشل** |

DEF-003 وDEF-004 وDEF-005: **Verified**. DEF-002: **Pending PM decision** بعد ثبوت الاتساق. التفاصيل في `defects.md`.

## متابعة P2-06 على PR #24 عند `6fe357e`

`bash tool/check.sh` خرج **0**. تحليل التطبيق بلا مشكلات (2.8s) و**83/0**. تحليل الحزمة بلا مشكلات (0.5s) و**60/0**.

| العملية | النجاح | إصدار قديم | الحالة بعد الرفض |
|---|---|---|---|
| سداد جزئي 100 من 320 | الرصيد 220 والإصدار 5 | 409 | 320/4 ثم 220/5 |
| نقد مربوط `sb_2` | `received` والإصدار 4 | 409 عند 99 | تبقى `pending` / 3 |
| نقد غير مربوط `ur_1` | `received` والإصدار 2 | 409 عند 1 | تبقى `received` / 2 |
| قرار غير مربوط | `approved` والإصدار 2 | 409 عند 9 ثم عند 1 | لا ينقلب إلى `rejected` |
| إقفال اليوم | `ok/1` حتى مع الإصدار 99 | لا 409 | `batchId` يبقى `b_1` |

## فرع الدمج PR #26 عند `aead4c5`

`bash tool/check.sh` خرج **0**. تحليل التطبيق بلا مشكلات (3.3s) و**93/0**. تحليل الحزمة بلا مشكلات (0.6s) و**68/0**. يضم #17 و#24 وPR #3. الفحوصات الثلاثة: الملخص 10635 ثم 10315، وتكرار `requestId` لا يخصم مرة ثانية، وقراءة الموظف للخزينة 403. `GET /api/home` يبقى 10635 بعد السداد. P3-11 من `/collections`: المدير والموظف مطابقان، والإصدار القديم 409 مع إعادة الجلب، والممنوع 403. رفض الإداري المحدود متسق ويبقى Pending PM decision. إقفال اليوم ما زال `ok/1`. المرحلة 2: **مقبول بشروط**. المرحلة 3: **مرفوض** لأن DEF-002 Pending PM decision وP3-01 Blocked. DEF-007: Verified.

## PR #24 عند `fe0c56d` وPR #26 عند `589d645` وPR #17 عند `5b51ef3`

`bash tool/check.sh` خرج **0** على الثلاثة بعد حل حزمة `packages/api_layer`، وهو الترتيب الذي يستخدمه CI قبل التحليل. على شجرة لم تُجلب فيها الحزمة بعد، تحليل جذر التطبيق يتوقف عند 6 معلومات `unintended_html_in_doc_comment` لأن `flutter_lints` 6 في التطبيق يفعّل القاعدة و`flutter_lints` 4 في الحزمة لا يفعّلها. هذا ليس تغيير هذه الالتزامات.

| الفرع | التحليل | الاختبارات |
|---|---|---|
| #24 `fe0c56d` | بلا مشكلات (3.5s و1.7s) | **83/0** و**61/0** |
| #26 `589d645` | بلا مشكلات (2.9s و0.6s) | **93/0** و**70/0** |
| #17 `5b51ef3` | بلا مشكلات (3.5s و1.7s) | **74/0** و**58/0** |

إقفال يوم الاستلامات على #24 و#26: إصدار 99 يعيد 409 و`b_1` يبقى، والإصدار 1 يخزّن الإصدار 2 و`b_2`، وإعادة الإصدار 1 تعيد 409. إقفال يوم المشتريات ما زال على `expectedDayVersion`. على #26 بعد سداد `c_55` الرئيسية والقائمة **10315**، والمصري **23750** في الجهتين. على #17 الرئيسية تطابق صفحة القائمة الثابتة (10635 و23750) ولا مسار رصيد مخزَّن. المرحلة 2 على #26: **مقبول بشروط**. المرحلة 3 على #26: **مرفوض**. DEF-002 Pending PM decision. P3-01 Blocked.

## PR #25 عند `e53a8b1`

`bash tool/check.sh` خرج **0**. تحليل التطبيق (3.1s) و**86/0**. تحليل الحزمة (0.6s) و**56/0**. سلوك قائمة الكروت المطلوب مطابق لمعايير المرحلة 2. اشتراط كتابة القسم مع `debts.zero_review` سؤال مفتوح للخادم وليس عيبًا. لم يُدمج.

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
| PR #17 (`350e051`) | `tool/check.sh` خروج 0: تحليل التطبيق والحزمة بلا مشكلات، 74 و56 اختبارًا ناجحة. DEF-006 وDEF-008 وDEF-009 وDEF-011: Verified |
| PR #17 (`c4edd59`) | `tool/check.sh` خروج 0: تحليل بلا مشكلات، 74 و57 اختبارًا ناجحة. فلترة الرئيسية ونسخ 10635 / 10 و23750 و8000: Verified. P2-01: Partially |
| PR #24 (`4260c16`) | `tool/check.sh` خروج 0: تحليل بلا مشكلات، 83 و56 اختبارًا ناجحة. DEF-003 وDEF-004 وDEF-005: Verified. DEF-002: Pending PM decision |
| PR #24 (`6fe357e`) | `tool/check.sh` خروج 0: 83 و60. السداد الجزئي والنقدان وقرار غير المربوط: Verified. إقفال اليوم: ما زال `ok/1` |
| PR #24 (`fe0c56d`) | `tool/check.sh` خروج 0: 83 و61. إقفال اليوم: 409 ثم `b_2` / الإصدار 2 ثم 409. إقفال المشتريات ما زال محميًا |
| PR #26 (`589d645`) | `tool/check.sh` خروج 0: 93 و70. الرئيسية بعد السداد 10315 مثل القائمة. المرحلة 2 مقبول بشروط. المرحلة 3 مرفوض |
| PR #17 (`5b51ef3`) | `tool/check.sh` خروج 0: 74 و58. الرئيسية تطابق صفحة القائمة. لا رصيد مخزَّن بعد السداد |
| PR #25 (`e53a8b1`) | `tool/check.sh` خروج 0: 86 و56. قائمة الكروت مطابقة. كتابة القسم مع `debts.zero_review`: سؤال مفتوح وليس عيبًا |
