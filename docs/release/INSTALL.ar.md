# تعليمات التثبيت وخطة اختباره: APK Debug وAPK Release وAAB (المرحلة 9)

> مبنية على مسودة QA (`/workspace/phase9/install-test-plan.ar.md`)، ومحدَّثة لمعرّف التطبيق الجديد `com.vip2100.vib` ولتوقيع الإصدار. الجداول المرجعية في القسم 1 جردها QA على `main` عند `faa54fb`، وراجعناها بعد دمج المرحلة 8 (`f1dee47`: #73 و#81 و#68 و#83)؛ الأسطر التي غيّرها فرع المرحلة 9 معلَّمة.

- **الأساس:** `origin/main` عند `f1dee47416dd440214e8713a9a3341ebba9de8cf` (بعد دمج المرحلة 8). commit البناء النهائي: `<BUILD_COMMIT>` (يُملأ بعد دمج #84).
- **التاريخ:** 2026-10-30 (توقيت طرابلس، UTC+2).
- **قراءة فقط:** لم يُعدَّل المستودع.
- **ممنوع في هذه الوثيقة:** أي بيانات دخول، أو اسم مستخدم، أو كلمة مرور، أو مسار keystore، أو كلمة مروره، أو رابط فيه سر. يُكتب مضيف staging هنا `<staging-host>` كما في `docs/staging.md:10`.

## 0. التثبيت السريع بـ adb

> **مهم:** المعرّف تغيّر من `com.example.vib_abdo_company_mobile` إلى `com.vip2100.vib`. النظام يعدّهما تطبيقين مختلفين، فلا تُرقّي النسخة الجديدة القديمة، وقد يظهر أيقونتان باسم `VIB`. **أزل النسخة القديمة أولًا** (تُحذف بياناتها المحلية وجلستها):

```bash
adb devices                                   # تأكد من ظهور الجهاز بحالة device
adb uninstall com.example.vib_abdo_company_mobile || true   # النسخة القديمة إن وُجدت

# تحقق من الملف قبل التثبيت: البصمة يجب أن تطابق تقرير النسخة
sha256sum app-release.apk
apksigner verify --print-certs app-release.apk | grep -E 'DN|SHA-256'

# تثبيت أول مرة
adb install app-release.apk                   # أو app-debug.apk
# ترقية فوق نسخة بالمعرّف نفسه والمفتاح نفسه
adb install -r app-release.apk

adb shell dumpsys package com.vip2100.vib | grep -E 'versionCode|versionName'
adb shell am start -n com.vip2100.vib/.MainActivity
```

- **Debug وRelease بالمعرّف نفسه:** Debug موقّع بمفتاح debug وRelease بمفتاح الإصدار، فلا يحلّ أحدهما محل الآخر بـ `install -r` (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`). أزل الأول (`adb uninstall com.vip2100.vib`) قبل تثبيت الآخر.
- **AAB:** لا يُثبَّت مباشرة. استعمل `bundletool build-apks` ثم `install-apks` (الحالة INS-03)، أو ارفعه إلى Play.
- **من الهاتف دون adb:** انقل `app-release.apk` إلى الهاتف، وفعّل «تثبيت تطبيقات غير معروفة» لمدير الملفات، ثم افتح الملف.

## 1. الحقائق المأخوذة من المستودع

| البند | القيمة على `main` | المرجع |
|---|---|---|
| `applicationId` / `namespace` | **`com.vip2100.vib`** بعد المرحلة 9 (كان `com.example.vib_abdo_company_mobile`) | `android/app/build.gradle.kts` |
| `versionCode` / `versionName` | من `pubspec.yaml` `version: 1.0.0+1`، أي versionName `1.0.0` وversionCode `1` | `pubspec.yaml:4`؛ `build.gradle.kts` (`versionCode = flutter.versionCode`) |
| minSdk / targetSdk / compileSdk | `minOf(flutter.minSdkVersion, 29)`، أي 24. target 36. compile 36. يجب أن يبقى Android 10 (API 29) قابلًا للتثبيت | `build.gradle.kts` (`minSdk = minOf(...)`)؛ `docs/NOTIFICATIONS.md:35-44` |
| توقيع release | **بعد المرحلة 9:** مفتاح الإصدار `vib-release` من جهاز البناء (`ANDROID_KEY_PROPERTIES`). بلا مادة توقيع (مثل CI) يوقَّع بمفتاح debug مع تحذير | `build.gradle.kts`؛ `docs/release/BUILD.ar.md` |
| أذونات الـ Manifest | `INTERNET`، و`ACCESS_NETWORK_STATE`، و`POST_NOTIFICATIONS` (API 33+). لا `RECEIVE_BOOT_COMPLETED` | `android/app/src/main/AndroidManifest.xml:2-6` |
| اسم التطبيق | `VIB` | `AndroidManifest.xml:8` |
| قناة الإشعارات | `vib_collections_alerts`، والاسم «تنبيهات VIB» | `docs/NOTIFICATIONS.md:19-27` |
| وضع Fake | الافتراضي `USE_FAKE_API=true`. وضع الخادم الحقيقي يحتاج `USE_FAKE_API=false` مع `API_BASE` | `packages/api_layer/lib/core/config/release_fake_api_guard.dart:4-7`؛ `docs/staging.md:25-34` |
| حارس الإصدار | assert ثابت يكسر الترجمة في release إذا كان `USE_FAKE_API=true`، وفحص وقت تشغيل `rejectFakeApiInRelease`. الرسالة: «Release builds cannot use the fake API. Pass --dart-define=USE_FAKE_API=false.» | `release_fake_api_guard.dart:10-41`؛ `api_config.dart:101-124` |
| وظائف CI | `Analyze, test, and debug APK` (تبني debug بـ Fake وترفع `app-debug-apk` لـ 14 يومًا)؛ `Negative permission tests`؛ `Release build rejects fake API` (تبني release بـ `API_BASE=https://staging.example.com` للفحص فقط، **ولا ترفع الـ APK**) | `.github/workflows/ci.yml:47-174` و`:176-205` و`:207-301` |
| وظائف يدوية | `Staging smoke` (فحص `GET /api/health` بلا دخول)، و`Android notification emulator`، و`Android performance` | `.github/workflows/staging-smoke.yml:26-29`؛ `android-notifications-emulator.yml:15-19`؛ `android-performance.yml:21-25` |
| بوابة محلية | `tool/check.sh`: analyze واختبارات التطبيق وapi_layer، والصلاحيات السالبة، وpreflight، و`scan_release_apk.py --self-test`، و`check_release_rejects_fake_api.sh` | `tool/check.sh:6-21` |
| AAB | لا وظيفة في GitHub تبني AAB موقّعًا. يُبنى AAB على جهاز البناء المشترك فقط (`docs/release/BUILD.ar.md`) | `ci.yml` |
| الجلسة | كوكي `abdo_session` في مخزن آمن. بعد إعادة التشغيل يُستدعى `GET /api/me` ثم `GET /api/auth/csrf`. الخروج يمسح الكوكي والرمز وCSRF | `packages/api_layer/lib/core/auth/cookie_store.dart:10` و`:76`؛ `docs/session-behaviour.md:9` و`:37-45` |

## 2. الأدوات والبيئة

- **الأجهزة:** جهاز أو محاكٍ بـ Android 10 (API 29)، وآخر بـ API 33 أو أحدث، لاختبار `POST_NOTIFICATIONS`.
  - فحص وضع الطيران (P7-19) يحتاج جهازًا حقيقيًا. المحاكي لا يغلقه (`docs/acceptance/phase-7.md:182` و`:270`).
- **الأدوات:** `adb`، و`apksigner` و`zipalign` من build-tools، و`jarsigner` و`keytool` من JDK 17، و`bundletool`.
- **بناء الحزم:** يبنيها DevOps من `main`. QA لا يبني من فرع.
  - **Debug:** `flutter build apk --debug --dart-define=USE_FAKE_API=true`، أو artefact `app-debug-apk` من CI (`ci.yml:161` و`:167-174`).
  - **Release APK:** `flutter build apk --release --dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://<staging-host>`.
  - **AAB:** `flutter build appbundle --release --dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://<staging-host>` (`release_fake_api_guard.dart:17-19`).
  - **نسخة الترقية:** البناء نفسه مع `--build-number=2` (versionCode 2) و`--build-name=1.0.1`، **بالمفتاح نفسه**. أعلام Flutter القياسية؛ لا تغيير في `pubspec.yaml` من QA.
- **قيود staging:**
  - تسجيل دخول staging على جهاز Grok Bot فقط (`docs/api/integration-plan.ar.md:11`؛ `docs/staging.md:83` و`:98`).
  - حد الدخول 8 محاولات لكل حساب كل 15 دقيقة. بعد أي فشل لا تُعاد المحاولة قبل 15 دقيقة (`docs/staging.md:100`).
  - لا كتابة على staging إلا ببيانات اختبارية وبموافقة Ali المسبقة (`integration-plan.ar.md:182`). لا يُعاد تقديم تحصيل على staging بعد فشل غير حاسم (DEF-037، `docs/api/defect-decisions.ar.md:125-129`).

## 3. الحالات

الأعمدة: المعرّف | الحالة | الشروط المسبقة | الخطوات | النتيجة المتوقعة | نجاح/فشل

| المعرّف | الحالة | الشروط المسبقة | الخطوات | النتيجة المتوقعة | نجاح/فشل |
|---|---|---|---|---|---|
| INS-01 | تثبيت نظيف: Debug APK | جهاز بلا الحزمة (`adb shell pm list packages \| grep com.vip2100.vib` فارغ). artefact `app-debug-apk` أو بناء DevOps | 1. `adb install app-debug.apk` 2. `adb shell dumpsys package com.vip2100.vib \| grep -E "versionCode\|versionName"` | `Success`. versionCode 1 وversionName `1.0.0`. الأيقونة باسم `VIB` | ☐ |
| INS-02 | تثبيت نظيف: Release APK | الحزمة غير مثبتة. APK من DevOps بـ `USE_FAKE_API=false` و`API_BASE` | 1. `apksigner verify --print-certs app-release.apk` 2. `adb install app-release.apk` 3. `dumpsys package` كما سبق | التحقق ناجح، والتثبيت `Success`. الإصدار كما في الأعلام. **الشهادة على `main` شهادة debug** (`build.gradle.kts:41`)، تُسجَّل كملاحظة لا كفشل في هذه المرحلة | ☐ |
| INS-03 | تثبيت نظيف: AAB عبر bundletool | الحزمة غير مثبتة. AAB من DevOps. bundletool | 1. `bundletool build-apks --bundle=app-release.aab --output=app.apks` (بلا `--ks` يوقّع bundletool بمفتاح debug المحلي؛ لا تُكتب معاملات keystore في الوثيقة ولا في السجل) 2. `bundletool get-device-spec --output=device.json` 3. `bundletool install-apks --apks=app.apks` 4. `dumpsys package` | تُبنى ملفات APK مقسّمة وتُثبَّت. الإصدار مطابق لما في الـ AAB | ☐ |
| INS-04 | تشغيل التطبيق (كل حزمة) | INS-01 أو INS-02 أو INS-03 ناجح | 1. `adb logcat -c` 2. فتح التطبيق من المشغّل 3. `adb logcat -d > launch-<artefact>.txt` | تظهر شاشة الدخول «تسجيل الدخول» دون انهيار ولا `FATAL EXCEPTION`. في Release لا قيم أسرار في السجل؛ السجل يحمل الرمز و`correlationId` فقط (`docs/staging.md:69`) | ☐ |
| INS-05 | Release بلا `API_BASE` يُرفض قبل أي طلب | بناء DevOps خاص بالفحص: `USE_FAKE_API=false` بلا `API_BASE` | 1. التثبيت 2. التشغيل 3. التقاط logcat | `ApiConfigException` قبل أي طلب شبكة، والنص لا يكرر القيمة (`docs/staging.md:21`؛ `api_config.dart:96-97`). **غير مؤكد** كيف تظهر للمستخدم؛ تُسجَّل الشاشة كما هي | ☐ |
| UPG-01 | ترقية فوق نسخة سابقة مع بقاء البيانات والجلسة | Release versionCode 1 مثبت على جهاز Grok Bot ومسجَّل دخول على staging (STG-01). المظهر الليلي مفعّل كقيمة محلية. النسخة الثانية versionCode 2 **بالمفتاح نفسه** | 1. `adb install -r app-release-v2.apk` 2. `dumpsys package`: versionCode 2 3. فتح التطبيق | `Success`. الإصدار 2. يدخل التطبيق مباشرة دون شاشة دخول: الكوكي باقٍ، ويُستدعى `GET /api/me` ثم CSRF (`session-behaviour.md:9`). المظهر المحفوظ باقٍ (مفتاح `app-theme` في SharedPreferences، `lib/state/theme_controller.dart:10-32`). لا رسالة «انتهت الجلسة» | ☐ |
| UPG-02 | ترقية بين شهادتين مختلفتين (خطر معروف) | نسخة موقّعة بمفتاح debug من جهاز بناء A مثبتة، ونسخة أعلى من جهاز بناء B | `adb install -r` | المتوقع `INSTALL_FAILED_UPDATE_INCOMPATIBLE` لأن مفتاح debug يختلف بين الأجهزة. تُسجَّل النتيجة. بعد المرحلة 9 تُوقَّع نسخ Release كلها بمفتاح `vib-release` الثابت، فيبقى الخطر لنسخ debug فقط | ☐ |
| DWN-01 | رفض التخفيض | versionCode 2 مثبت | 1. `adb install -r app-release-v1.apk` (بلا `-d`) | يُرفض بـ `INSTALL_FAILED_VERSION_DOWNGRADE`، والنسخة 2 باقية (`dumpsys package`) | ☐ |
| REL-01 | Release يرفض الـ Fake في CI | تشغيل CI على `main` أو على PR النسخة | فتح وظيفة «Release build rejects fake API» وقراءة الخطوات | خطوة `Reject USE_FAKE_API in a release compile` ناجحة (`tool/check_release_rejects_fake_api.sh`). في خطوة `Scan a release APK for demo profiles` يطبع السجل «Release APK build rejected USE_FAKE_API=true.»، ثم يمر `scan_release_apk.py` على `app-release.apk` (`ci.yml:248-301`) | ☐ |
| REL-02 | Release يرفض الـ Fake يدويًا | جهاز بناء DevOps أو QA محلي، بلا أسرار | 1. `flutter build apk --release` **بلا** define 2. `flutter build apk --release --dart-define=USE_FAKE_API=true` 3. `flutter build appbundle --release` بلا define 4. `tool/check_release_rejects_fake_api.sh` | الأوامر 1 و2 و3 تفشل والسجل فيه «Release builds cannot use the fake API» (`release_fake_api_guard.dart:10-19`). 4 يخرج 0 | ☐ |
| REL-03 | الـ Release المثبت ليس Fake | INS-02 ناجح | 1. `python3 tool/scan_release_apk.py app-release.apk` 2. التشغيل وفتح شاشة الدخول | الفحص لا يجد ملفات تعريف تجريبية. شاشة الدخول لا تقبل حسابًا تجريبيًا دون خادم. **غير مؤكد**: لا يُجرَّب دخول تجريبي على staging، حفاظًا على حد المحاولات | ☐ |
| DIF-01 | فروق Debug وRelease | INS-01 وINS-02 | مقارنة البنود في الجدول 4 | كل بند كما في الجدول 4 | ☐ |
| AAB-01 | توقيع AAB وAPK | AAB وAPK من DevOps | 1. `jarsigner -verify -verbose -certs app-release.aab` 2. `keytool -printcert -jarfile app-release.aab` 3. `apksigner verify --verbose --print-certs app-release.apk` 4. `zipalign -c -v 4 app-release.apk` | التحقق ناجح. تُسجَّل بصمة SHA-256 للشهادة فقط. بعد المرحلة 9 المتوقع الموضوع `CN=VIB, O=Abdo Company, C=LY` وبصمة SHA-256 المسجلة في تقرير النسخة. شهادة «Android Debug» على Release تعني أن البناء تم بلا مادة توقيع: **مانع للتوزيع** | ☐ |
| AAB-02 | تطابق إصدار AAB وAPK | AAB-01 | `bundletool dump manifest --bundle=app-release.aab` ومقارنته بـ `dumpsys` بعد INS-03 | الحزمة `com.vip2100.vib`، ونفس versionCode وversionName | ☐ |
| STG-01 | دخول staging على جهاز Grok Bot فقط | Release مثبت على جهاز Grok Bot. حساب اختباري يُقرأ من الملف المحمي على ذلك الجهاز فقط. آخر فشل دخول قبل أكثر من 15 دقيقة | 1. Grok Bot يُدخل البيانات على الجهاز مباشرة دون تفعيل «إظهار كلمة المرور» 2. انتظار الرئيسية 3. لقطة الرئيسية **بعد** الدخول فقط | الدخول ناجح، وتظهر الأقسام بحسب صلاحيات الخادم. **لا تُكتب البيانات في GitHub ولا الدردشة ولا هذه الوثيقة ولا اسم لقطة.** لا لقطة لحقل الدخول وهو مملوء. عند الفشل لا تُعاد المحاولة قبل 15 دقيقة (`docs/staging.md:100`) | ☐ |
| NOT-01 | الإذن عند أول تشغيل، API 33+ | تثبيت نظيف على API 33+ | 1. التشغيل والدخول 2. ملاحظة هل يظهر طلب نظام عند الإقلاع 3. فتح «الإشعارات» لأول مرة | لا يُطلب الإذن عند الإقلاع: الشرح يظهر عند أول زيارة لشاشة الإشعارات (`lib/features/notifications/notifications_screen.dart:42-48`). يظهر «إذن الإشعارات» مع «موافق» و«ليس الآن» (`strings.dart:371-375`). «موافق» يفتح طلب النظام. **غير مؤكد** على جهاز حقيقي في هذه الجولة | ☐ |
| NOT-02 | رفض الإذن | NOT-01 | 1. «ليس الآن»، أو الرفض في طلب النظام 2. إعادة فتح الشاشة | تبقى القائمة. عند الرفض الدائم يظهر «لم يُمنح إذن الإشعارات. يمكنك تفعيله من إعدادات التطبيق.» مع «فتح الإعدادات» (`strings.dart:376-378`) | ☐ |
| NOT-03 | API 29 (Android 10) | تثبيت نظيف على API 29 | فتح الإشعارات | لا طلب ولا شرح، لأن الإذن ضمني تحت API 33 (`notifications_screen.dart:43`؛ `NOTIFICATIONS.md:13`) | ☐ |
| NOT-04 | القناة | بعد NOT-01 | `adb shell dumpsys notification \| grep vib_collections_alerts` أو إعدادات التطبيق ← الإشعارات | القناة `vib_collections_alerts` باسم «تنبيهات VIB» وأهمية عالية (`NOTIFICATIONS.md:19-27`). الدفع غير مدعوم: `/api/mobile-push/devices` يعيد 404 على staging (G-09). يُسجَّل في السجل ولا يُعد فشل تثبيت | ☐ |
| NET-01 | انقطاع الشبكة أثناء الدخول | Release على جهاز حقيقي. شاشة الدخول. للدخول الحقيقي جهاز Grok Bot فقط | 1. وضع الطيران 2. محاولة الدخول 3. إعادة الشبكة | رسالة شبكة أو مهلة (`NETWORK_UNAVAILABLE`/`TIMEOUT`، `docs/staging.md:60-63`)، لا «بيانات خاطئة»، ولا تُخزَّن جلسة. **تُحسب المحاولة ضمن حد الثماني** إن وصلت إلى الخادم، فلا تُكرَّر أكثر من مرة | ☐ |
| NET-02 | انقطاع الشبكة أثناء الكتابة | **Debug/Fake** أولًا. على staging فقط بموافقة Ali المسبقة وببيانات اختبارية. **لا يُستعمل تقديم التحصيل** (DEF-037) | 1. فتح حوار سداد 2. وضع الطيران قبل التأكيد 3. التأكيد 4. إعادة الشبكة 5. إعادة المحاولة يدويًا | لا إعادة آلية للكتابة (`docs/staging.md:55`؛ `session-behaviour.md:35`). يظهر «غير متصل — تُعرض آخر بيانات محمّلة للقراءة» (`strings.dart:52`). الإعادة اليدوية تحمل `requestId` نفسه، ويبقى في الدفتر سطر واحد (P7-19 وP7-20، `phase-7.md:305-306` و`:370`) | ☐ |
| OUT-01 | تسجيل الخروج | مسجّل دخول (Fake على debug، أو staging على جهاز Grok Bot) | 1. «تسجيل الخروج» 2. «هل تريد تسجيل الخروج؟»، ثم التأكيد 3. إغلاق التطبيق وإعادة فتحه | العودة إلى شاشة الدخول **دون** «انتهت الجلسة، يرجى تسجيل الدخول». بعد إعادة الفتح تبقى شاشة الدخول: الكوكي والرمز وCSRF ممسوحة (`strings.dart:18` و`:21`؛ `session-behaviour.md:31-45`) | ☐ |
| OUT-02 | خروج دون شبكة | مسجّل دخول | وضع الطيران، ثم الخروج | المسح المحلي يحدث حتى لو فشل `POST /api/auth/logout` (`session-behaviour.md:39-45`). تُسجَّل الملاحظة أن جلسة الخادم قد تبقى حتى تنتهي | ☐ |

## 4. فروق Debug وRelease (DIF-01)

| البند | Debug | Release | المرجع |
|---|---|---|---|
| الـ API | Fake افتراضيًا (`USE_FAKE_API=true`)، وCI يبنيه هكذا | يجب `USE_FAKE_API=false` مع `API_BASE`، وإلا تفشل الترجمة | `ci.yml:161`؛ `release_fake_api_guard.dart:14-27` |
| الشبكة | Fake لا يفتح socket | Dio نحو `API_BASE` | `docs/staging.md:3` و`:29` |
| التوقيع على `main` | مفتاح debug | مفتاح الإصدار `vib-release` عند البناء على جهاز البناء؛ مفتاح debug مع تحذير في CI | `build.gradle.kts` |
| artefact في CI | `app-debug-apk` يُرفع | لا يُرفع، يُبنى للفحص فقط | `ci.yml:167-174` و`:300` |
| سجل الطلبات | `API_DEBUG_LOG` افتراضه `false` في الاثنين؛ السجلات منقّحة | — | `docs/staging.md:32` |
| الترجمة | JIT مع `assert` | AOT. الحارس ثابت وقت الترجمة، ثم فحص وقت التشغيل | `release_fake_api_guard.dart:16-20` و`:33-41` |
| `applicationId` | واحد للنوعين، بلا لاحقة. لا يمكن تثبيتهما معًا؛ الثاني يحل محل الأول إن تطابقت الشهادة | — | `build.gradle.kts` (`applicationId = "com.vip2100.vib"`) |

## 5. الأدلة المطلوب جمعها

لا تُضمَّن قيم سرية في أي دليل.

1. مخرجات `dumpsys package` (versionCode وversionName) لكل حزمة، قبل الترقية وبعدها.
2. مخرجات `apksigner --print-certs` و`keytool -printcert`: بصمة SHA-256 والموضوع فقط.
3. مخرجات `bundletool build-apks` و`install-apks` دون معاملات keystore.
4. `adb logcat` عند الإقلاع، وعند NET-01 وNET-02، وعند الخروج. تُفحص قبل الإرفاق: لا كوكي، ولا رمز CSRF، ولا كلمة مرور.
5. لقطات شاشة:
   - شاشة الدخول.
   - الرئيسية بعد الدخول، دون حقول الدخول.
   - حوار إذن الإشعارات ورسالة الرفض.
   - شريط «غير متصل».
   - حوار الخروج.
   - رسائل الترقية والتخفيض.
6. روابط تشغيلات CI لوظيفة «Release build rejects fake API» ووظيفة «Analyze, test, and debug APK» على SHA النسخة.
7. مخرجات REL-02 (فشل الترجمة بالرسالة)، و`tool/check.sh` (خروج 0).

## 6. معايير الخروج

1. كل الحالات INS وUPG-01 وDWN وREL وAAB وNOT وNET وOUT نجحت على SHA واحد من `main`، مع دليل لكل حالة.
2. REL-01 وREL-02 كلتاهما ناجحتان: لا Release يقبل الـ Fake.
3. لا انهيار عند الإقلاع على API 29 ولا على API 33+.
4. الترقية تحفظ الجلسة والإعدادات، والتخفيض مرفوض.
5. لم تظهر أي بيانات دخول في GitHub أو الدردشة أو الوثائق أو اللقطات أو السجلات.
6. نتائج UPG-02 وAAB-01 مسجّلة في تقرير النسخة. نسخة المرحلة 9 تجريبية على staging (إصدار-02 في `KNOWN_ISSUES.ar.md`)، و**النشر على Play** يحتاج قرار Ali ومالك Play Console.
7. لا قبول مالي نهائي من هذه الخطة: بوابة DEF-037 وP-19 خارجها (`integration-plan.ar.md:183-184`).
