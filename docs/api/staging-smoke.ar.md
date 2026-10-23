# دخان staging اليدوي (P-01)

تشغيل يدوي ضد بيئة GitHub باسم `staging`. لا يعمل على `push` ولا `pull_request` ولا `schedule`، ولا يُضاف مشغّل push مؤقت. ليس من فحوص طلب السحب الثلاثة، ولا يغيّر `applicationId` ولا التوقيع ولا الإصدار ولا `ci.yml`.

وظيفة GitHub **لا تسجّل الدخول**. تقتصر على فحص الوصول غير المصادق: `GET /api/health`. فحص الدخول (P7-01) يُشغَّل محليًا على جهاز البوت فقط.

**لا تُخزَّن أسماء مستخدمي staging ولا كلمات مرورها في GitHub، لا كأسرار ولا كمتغيرات.**

فحص الصلاحيات السالبة ضد staging (مدير، وموظف، وموظف ثانٍ، ومدير محدود) يُشغَّل على جهاز البوت فقط، عبر `tool/staging_negative_tests/run.sh` بلا `--dry-run`. الوضع الحي للقراءة فقط ما لم يُمرَّر `--allow-sandbox-writes`، وهذا العلم لبيئة sandbox نظيفة وبموافقة Ali الصريحة في كل مرة، وليس متغير بيئة. أي قيمة غير فارغة لـ `CI` أو `GITHUB_ACTIONS` ترفض الوضع الحي وتخرج 2. GitHub يشغّل `--dry-run` فقط داخل الفحص المطلوب «Negative permission tests»، وهو لا يفتح اتصالًا ولا يقرأ حسابات. تغطية الـ Fake API لذلك الفحص تبقى كما هي. لا وظيفة في GitHub مربوطة بـ `environment: staging` لقراءة أسماء الدخول أو كلمات المرور.

القيمة المقصودة لـ `STAGING_API_BASE` هي الأصل `https://staging.vip2100.com` **بلا** لاحقة `/erp`. واجهة الموقع على `/erp`، والـ API على `/api` في الأصل نفسه. `/erp/api/health` يعيد HTML. لا تُكتب القيمة في المستودع. السكربت لا يستبدل الأصل الفارغ بهذه القيمة، بل يفشل.

## تحذير حد الدخول (الفحص المحلي)

**بعد فشل تسجيل الدخول لا تُعد فحص الدخول المحلي أكثر من مرة واحدة خلال 15 دقيقة.** حد محاولات الدخول **8 محاولات لكل حساب كل 15 دقيقة**. إعادة التشغيل المتكررة تقفل الحساب. هذا التحذير يخص التشغيل المحلي على جهاز البوت، لا وظيفة GitHub، لأن الوظيفة لا ترسل طلب دخول.

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
- لا يقرأ اسم مستخدم ولا كلمة مرور، لا للمدير ولا للموظف ولا للموظف الثاني ولا للمدير المحدود، ولا يشغّل `staging_smoke_test.dart` ولا الوضع الحي من `tool/staging_negative_tests/run.sh`.

## فحص الدخول المحلي (جهاز البوت فقط)

لا يُخزَّن الحساب في GitHub. على جهاز البوت، في جلسة لا تُكتب في المستودع:

```bash
STAGING_API_BASE='https://staging.vip2100.com' \
STAGING_ADMIN_USERNAME='<account>' \
STAGING_ADMIN_PASSWORD='<password>' \
flutter test packages/api_layer/test/phase7/staging_smoke_test.dart
```

التفاصيل في `docs/staging.md`. مسار `setPinned` و`STAGING_SMOKE_ACCOUNT_ID` أُزيل من فحص الدخان. القراءة لا تغطي قصد P-07 (جسم التثبيت)، فالكتابة مؤجلة إلى P-07 حتى يقرر Ali. بعد فشل الدخول: محاولة محلية واحدة إضافية على الأكثر خلال 15 دقيقة، ثم التوقف. الحد 8 محاولات لكل حساب كل 15 دقيقة.

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

لا صفوف أخرى. `STAGING_API_BASE` هو الاسم الوحيد. أسماء المستخدمين وكلمات المرور ليست أسرار هذه الوظيفة وليست متغيراتها، وليست أسرار أي وظيفة أخرى تحت `.github/workflows` ولا متغيراتها.

## ما يبقى خارج الوظيفة

- لا قيم أسرار في git، ولا تعديل لملف حسابات محلي.
- إقناع الأصل بنمط `::add-mask::` قبل الطلب، داخل GitHub Actions فقط حتى لا يطبع تشغيل محلي السر في الطرفية.
- كتابة pin (`setPinned`) و`STAGING_SMOKE_ACCOUNT_ID` أُزيلتا من فحص الدخان ومؤجلتان إلى P-07 حتى يقرر Ali. GitHub لا يقرأهما ولا يرسل كتابة إلى staging. GitHub يصل إلى staging بلا دخول فقط: فحص الصحة وبداية التشغيل الباردة.
