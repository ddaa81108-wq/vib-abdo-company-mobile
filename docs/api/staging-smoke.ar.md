# دخان staging اليدوي (P-01)

تشغيل يدوي ضد بيئة GitHub باسم `staging`. لا يعمل على `push` ولا `pull_request` ولا `schedule`، ولا يُضاف مشغّل push مؤقت. ليس من فحوص طلب السحب الثلاثة، ولا يغيّر `applicationId` ولا التوقيع ولا الإصدار ولا `ci.yml`.

وظيفة GitHub **لا تسجّل الدخول**. تقتصر على فحص الوصول غير المصادق: `GET /api/health`. فحص الدخول (P7-01) يُشغَّل محليًا على جهاز البوت فقط.

**لا تُخزَّن أسماء مستخدمي staging ولا كلمات مرورها في GitHub، لا كأسرار ولا كمتغيرات.**

القيمة المقصودة لـ `STAGING_API_BASE` هي الأصل `https://staging.vip2100.com` **بلا** لاحقة `/erp`. واجهة الموقع على `/erp`، والـ API على `/api` في الأصل نفسه. `/erp/api/health` يعيد HTML. لا تُكتب القيمة في المستودع. السكربت لا يستبدل الأصل الفارغ بهذه القيمة، بل يفشل.

## تحذير حد الدخول (الفحص المحلي)

**بعد فشل تسجيل الدخول لا تُعد فحص الدخول المحلي أكثر من مرة واحدة خلال 15 دقيقة.** حد محاولات الدخول **8 محاولات لكل حساب**. إعادة التشغيل المتكررة تقفل الحساب. هذا التحذير يخص التشغيل المحلي على جهاز البوت، لا وظيفة GitHub، لأن الوظيفة لا ترسل طلب دخول.

## كيف يُشغَّل فحص الصحة على GitHub

1. الملف يجب أن يكون على الفرع الافتراضي `main`. GitHub لا يشغّل `workflow_dispatch` من فرع آخر حتى يوجد الملف على الافتراضي.
2. أنشئ بيئة باسم `staging` حرفيًا: Settings → Environments → New environment.
3. ضع `STAGING_API_BASE` **سرًا** في تلك البيئة. متغير بالاسم نفسه يبقى احتياطًا في ملف الوظيفة وغير موصى به، لأن المتغيرات لا تُقنَّع مثل الأسرار. لا تضع اسم مستخدم ولا كلمة مرور في البيئة.
4. من تبويب Actions اختر **Staging smoke** ثم Run workflow على `main`.
5. أو من الطرفية، بعد وصول الملف إلى `main`:

```bash
gh workflow run "Staging smoke" --ref main
```

الوظيفة في `.github/workflows/staging-smoke.yml` مربوطة بـ `environment: staging`. `actions/checkout` مثبّت على بصمة commit كاملة لأن الوظيفة ترى سر الأصل.

ما يفعله التشغيل:

- يفحص الأصل. الفارغ، أو الذي ينتهي بـ `/erp`، أو الذي يشبه الإنتاج، أو الذي ليس أصل staging، **يفشل** الوظيفة. القيمة لا تُطبع. الرفض الإنتاجي هو `classify_origin` نفسه في `tool/staging_negative_tests/preflight.py`.
- يطلب `GET /api/health` بلا دخول عبر curl، مع User-Agent `VibAbdoMobileSmoke/1.0 (+github-actions)`. النجاح هو HTTP 200 وليس HTML.
- لا يقرأ `STAGING_ADMIN_USERNAME` ولا `STAGING_ADMIN_PASSWORD` ولا أي اسم أو كلمة مرور أخرى، ولا يشغّل `staging_smoke_test.dart`.

## فحص الدخول المحلي (جهاز البوت فقط)

لا يُخزَّن الحساب في GitHub. على جهاز البوت، في جلسة لا تُكتب في المستودع:

```bash
STAGING_API_BASE='https://staging.vip2100.com' \
STAGING_ADMIN_USERNAME='<account>' \
STAGING_ADMIN_PASSWORD='<password>' \
flutter test packages/api_layer/test/phase7/staging_smoke_test.dart
```

التفاصيل في `docs/staging.md`. لا تضبط `STAGING_SMOKE_ACCOUNT_ID` حتى P-07. بعد فشل الدخول: محاولة محلية واحدة إضافية على الأكثر خلال 15 دقيقة، ثم التوقف. الحد 8 محاولات لكل حساب.

## User-Agent

Cloudflare على staging يعيد 403 لـ `Python-urllib`. طلب الصحة من الوظيفة ليس من بايثون:

| الأداة | User-Agent |
|---|---|
| curl في `tool/staging_smoke/reachability.sh` | `VibAbdoMobileSmoke/1.0 (+github-actions)` |
| اختبار Flutter المحلي | عميل `dart:io` الافتراضي `Dart/x (dart:io)`، وهو مقبول حسب `staging-readonly-check.ar.md` |

`tool/staging_smoke/preflight.py` لا يفتح اتصالًا. يستخدم `urllib.parse` لتقسيم الرابط فقط، لذلك لا يضع ترويسة User-Agent.

## جدول أسرار هذه الوظيفة

القيمة من القناة الآمنة على بيئة `staging`. هذا المستودع يذكر الاسم فقط.

| الاسم | النوع | لهذه الوظيفة | الغرض | المرحلة |
|---|---|---|---|---|
| `STAGING_API_BASE` | سر بيئة. هذا هو الشكل الموصى به. متغير بالاسم نفسه احتياط غير موصى به | مطلوب. الفارغ يفشل الوظيفة | الأصل فقط. القيمة المقصودة `https://staging.vip2100.com` بلا `/erp` | P-01 |

لا صفوف أخرى. أسماء المستخدمين وكلمات المرور ليست أسرار هذه الوظيفة وليست متغيراتها.

## ما يبقى خارج الوظيفة

- لا قيم أسرار في git، ولا تعديل لملف حسابات محلي.
- إقناع الأصل بنمط `::add-mask::` قبل الطلب، داخل GitHub Actions فقط حتى لا يطبع تشغيل محلي السر في الطرفية.
- كتابة pin و`STAGING_SMOKE_ACCOUNT_ID` مؤجلتان إلى P-07، ولا تُقرآن من GitHub.
