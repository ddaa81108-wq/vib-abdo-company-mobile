# تعليمات بناء نسخة الإصدار (المرحلة 9)

> **الأسرار:** مفتاح الإصدار وكلمة مروره وملف `key.properties` موجودة على جهاز البناء المشترك فقط، في `/workspace/phase9/secrets/` (المجلد 700، والملفات 600). لا تُنسخ إلى المستودع ولا إلى GitHub (لا commit ولا secret ولا variable ولا artifact)، ولا تُطبع في أي سجل أو رسالة. لا تستعمل `cat` أو `echo` على أي ملف فيها.

## 1. ما يقرؤه Gradle

`android/app/build.gradle.kts` يقرأ كل حقل من متغير بيئة غير فارغ أولًا، ثم من ملف `key.properties`:

| الحقل في `key.properties` | متغير البيئة البديل |
|---|---|
| `storeFile` (مسار مطلق يُفضَّل؛ المسار النسبي يُحسب من `android/app`، لا من جذر المستودع ولا من مكان `key.properties`) | `ANDROID_KEYSTORE_PATH` (القاعدة نفسها) |
| `storePassword` | `ANDROID_KEYSTORE_PASSWORD` |
| `keyAlias` | `ANDROID_KEY_ALIAS` |
| `keyPassword` (اختياري لـ PKCS12؛ يُستعمل `storePassword` عند غيابه) | `ANDROID_KEY_PASSWORD` |

- **مكان `key.properties`:** المسار في `ANDROID_KEY_PROPERTIES` إن وُجد (المفضَّل: خارج المستودع)، وإلا `android/key.properties` (مستثنى في `.gitignore`). القالب: `android/key.properties.example` (قيم وهمية فقط).
- **بلا أي مادة توقيع** (حالة CI: لا `ANDROID_KEY_PROPERTIES`، ولا `android/key.properties`، ولا متغيرات `ANDROID_KEYSTORE_*`): يُوقَّع Release بمفتاح debug، ويطبع Gradle تحذيرًا واضحًا. هذا البناء **غير صالح للتوزيع**.
- **مادة ناقصة**: يفشل بناء Release ويذكر الحقول الناقصة بأسمائها دون أي قيمة. يُعدّ التوقيع مطلوبًا متى ضُبط `ANDROID_KEY_PROPERTIES` أو وُجد `android/key.properties` أو ضُبط أي حقل، فيفشل البناء مع: مسار بلا كلمة مرور، أو ملف غير موجود، أو ملف `key.properties` فارغ، أو أسماء مفاتيح خاطئة (تُذكر الأسماء غير المعروفة).
- **متى يعمل الفحص:** فقط عند طلب مهمة Release (`assemble`/`bundle`/`package`/`sign...Release`). بناء debug و`flutter run` لا يتأثران حتى مع `ANDROID_REQUIRE_RELEASE_SIGNING=true` وبلا مادة.
- **فحص السلوك:** `tool/check_release_signing_gradle.sh` يشغّل Gradle dry-run (`-m`) بمفتاح مؤقت في `/tmp` فقط، ويتحقق من الحالات السابقة. يعمل ضمن `tool/check.sh` محليًا، وليس في CI الإلزامي.
- **`ANDROID_REQUIRE_RELEASE_SIGNING=true`** أو `-PrequireReleaseSigning=true`: غياب المادة خطأ. **استعمله دائمًا في بناء الإصدار** حتى لا يخرج APK موقّع بمفتاح debug خطأً.
- `API_BASE` يُمرَّر عند البناء فقط بـ `--dart-define`، ولا قيمة افتراضية له في الكود. نسخة Release الحالية **تجريبية على staging**.

## 2. البيئة

الأدوات على جهاز البناء بنفس نسخ CI: JDK 17 (Temurin)، وFlutter 3.47.7 (Dart 3.13.5)، وAndroid SDK (platform 36، وbuild-tools 36.0.0، وNDK 28.2.13676358). يحمّل Gradle 9.3.1 بنفسه، مع AGP 9.1.0 وKotlin 2.4.0.

```bash
source /workspace/phase9/env.sh          # JAVA_HOME وANDROID_HOME وPATH، بلا أسرار
flutter --version
cd /workspace/phase9/repo
git fetch origin && git checkout --detach <BUILD_COMMIT>   # commit يحدده Grok Bot
git status --porcelain                   # يجب أن يكون فارغًا
flutter clean && flutter pub get
```

## 3. البناء

```bash
export ANDROID_KEY_PROPERTIES=/workspace/phase9/secrets/key.properties
# إلزامي في كل بناء إصدار: بدونه قد يخرج APK موقّع بمفتاح debug.
export ANDROID_REQUIRE_RELEASE_SIGNING=true

# Debug APK (Fake API)
flutter build apk --debug --dart-define=USE_FAKE_API=true

# Release APK (staging، نسخة تجريبية)
ANDROID_REQUIRE_RELEASE_SIGNING=true flutter build apk --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://staging.vip2100.com

# AAB للنشر
ANDROID_REQUIRE_RELEASE_SIGNING=true flutter build appbundle --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://staging.vip2100.com

# Release APK على الخادم الرئيسي (production)
ANDROID_REQUIRE_RELEASE_SIGNING=true flutter build apk --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://vip2100.com \
  --dart-define=EMPLOYEE_TOTALS_SOURCE=collections
```

**مصدر إجماليات الموظفين (`EMPLOYEE_TOTALS_SOURCE`):**
- `standalone` (الافتراضي) يطلب `GET /api/admin/employee-totals`. هذا المسار غير موجود على الخادم الرئيسي ولا على staging (404 `ROUTE_NOT_FOUND`).
- `collections` يقرأ مصفوفة `employeeTotals` من `GET /api/collections`، وهي متاحة للمدير فقط. **مرّر `EMPLOYEE_TOTALS_SOURCE=collections` في بناء الخادم الرئيسي.**
- إن نُسي التعريف فالتطبيق لا يتعطل: عند 404 `ROUTE_NOT_FOUND` من المسار المستقل يرجع تلقائيًا إلى `employeeTotals` في `/api/collections`، للمدير فقط. غير المدير يبقى رفض الخادم كما هو، ولا يُستبدل بالمصفوفة. أي 404 آخر يُعرض خطأً كما هو.
- إذا أضاف الخادم المسار المستقل لاحقًا فإن الافتراضي يستعمله تلقائيًا.

المخرجات:
- `build/app/outputs/flutter-apk/app-debug.apk`
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`

إذا رد Maven بـ 429 (Too Many Requests) أعد الأمر نفسه بعد دقيقة ثم دقيقتين ثم ثلاث. لا تغيّر الكود.

## 4. التحقق

```bash
BT=$ANDROID_HOME/build-tools/36.0.0
$BT/aapt2 dump badging build/app/outputs/flutter-apk/app-release.apk | grep -E "^package"
#   name='com.vip2100.vib' versionCode='1' versionName='1.0.0'
$BT/apksigner verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk \
  | grep -E 'Verifies|DN|SHA-256|SHA-1'
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | grep -E 'Owner|SHA1|SHA256'
sha256sum build/app/outputs/flutter-apk/*.apk build/app/outputs/bundle/release/app-release.aab
ls -l build/app/outputs/flutter-apk/*.apk build/app/outputs/bundle/release/app-release.aab
python3 tool/scan_release_apk.py build/app/outputs/flutter-apk/app-release.apk
```

- الموضوع المتوقع: `CN=VIB, O=Abdo Company, C=LY`.
- بصمة SHA-256 المتوقعة للشهادة: `40:B5:69:E6:FF:E8:91:26:ED:81:02:7A:1B:15:7E:4D:C4:89:13:19:EC:8C:54:49:AE:60:20:6E:08:BB:B8:41`.
- بصمة SHA-1 المتوقعة: `1B:5E:77:E1:88:90:09:1D:2C:94:FE:8A:6E:AC:E0:37:A3:54:44:50`.
- إذا ظهر `CN=Android Debug` على Release أو AAB فالبناء بلا مادة توقيع: **لا يُوزَّع**.

قراءة بيانات المفتاح نفسه (دون كلمة المرور في سطر الأوامر، ومع تصفية المخرجات):

```bash
keytool -list -v -keystore /workspace/phase9/secrets/vib-release.p12 \
  -storepass:file /workspace/phase9/secrets/store.pass \
  | grep -E '^(Alias name|Owner|Valid from)|SHA1:|SHA256:'
```

## 5. التوقيع اليدوي بـ apksigner (عند الحاجة فقط)

```bash
$BT/apksigner sign --ks /workspace/phase9/secrets/vib-release.p12 --ks-type PKCS12 \
  --ks-key-alias vib-release --ks-pass file:/workspace/phase9/secrets/store.pass \
  --out signed.apk unsigned-or-other.apk
```

- **لا تمرّر `--key-pass` بالملف نفسه.** `apksigner` يقرأ من ملف `file:` سطرًا واحدًا لكل خيار بالتتابع، والملف فيه سطر واحد، فيفشل بـ «end of file reached». عند غياب `--key-pass` يستعمل كلمة مرور المخزن، وهي نفسها في PKCS12.
- لا تستعمل `pass:<value>` أبدًا: القيمة تظهر في قائمة العمليات وسجل الأوامر.

## 6. بعد البناء

1. انسخ المخرجات إلى مجلد النسخة (مثل `/workspace/phase9/release-<commit>/`)، وسجّل الحجم وSHA-256 في `RELEASE_REPORT`.
2. تحقق من أن السجلات لا تحوي كلمة المرور، دون طباعة أي تطابق:
   `grep -rlF -f /workspace/phase9/secrets/store.pass /workspace/phase9 --exclude-dir=secrets | wc -l` يجب أن يكون `0`.
3. `git status --porcelain` فارغ، و`git ls-files | grep -Ei 'p12|jks|keystore|key.properties$'` فارغ.
