# دخان staging اليدوي (P-01)

تشغيل يدوي ضد بيئة GitHub باسم `staging`. لا يعمل على `push` ولا `pull_request` ولا `schedule`، ولا يُضاف مشغّل push مؤقت. ليس من فحوص طلب السحب الثلاثة، ولا يغيّر `applicationId` ولا التوقيع ولا الإصدار ولا `ci.yml`.

القيمة المقصودة لـ `STAGING_API_BASE` هي الأصل `https://staging.vip2100.com` **بلا** لاحقة `/erp`. واجهة الموقع على `/erp`، والـ API على `/api` في الأصل نفسه. `/erp/api/health` يعيد HTML. لا تُكتب القيمة في المستودع كسر؛ السكربت لا يستبدل الأصل الفارغ بهذه القيمة، بل يفشل.

## كيف يُشغَّل

1. الملف يجب أن يكون على الفرع الافتراضي `main`. GitHub لا يشغّل `workflow_dispatch` من فرع آخر حتى يوجد الملف على الافتراضي.
2. أنشئ بيئة باسم `staging` حرفيًا: Settings → Environments → New environment.
3. ضع الأسماء في **تلك البيئة** لا في وصف issue أو PR. فضّل الأسرار على المتغيرات حتى يُقنّع السجل القيمة.
4. من تبويب Actions اختر **Staging smoke** ثم Run workflow على `main`.
5. أو من الطرفية، بعد وصول الملف إلى `main`:

```bash
gh workflow run "Staging smoke" --ref main
```

الوظيفة في `.github/workflows/staging-smoke.yml` مربوطة بـ `environment: staging`.

ما يفعله التشغيل:

- يفحص الأصل. الفارغ، أو الذي ينتهي بـ `/erp`، أو الذي يشبه الإنتاج، أو الذي ليس أصل staging، **يفشل** الوظيفة. القيمة لا تُطبع. الرفض الإنتاجي هو `classify_origin` نفسه في `tool/staging_negative_tests/preflight.py`.
- يطلب `GET /api/health` بلا دخول عبر curl، مع User-Agent `VibAbdoMobileSmoke/1.0 (+github-actions)`. النجاح هو HTTP 200 وليس HTML.
- إن غاب `STAGING_ADMIN_USERNAME` أو `STAGING_ADMIN_PASSWORD` يتخطى الدخول بإشعار عنوانه `secret not configured`. فحص الصحة غير المصادق يكون قد تم.
- إن وُجد الاسمان يشغّل `packages/api_layer/test/phase7/staging_smoke_test.dart` من حزمة `packages/api_layer` (دخول، `GET /api/me`، قائمة قسم واحد، ثم `POST /api/auth/logout`). لا يُمرَّر `STAGING_SMOKE_ACCOUNT_ID`.

## User-Agent

Cloudflare على staging يعيد 403 لـ `Python-urllib`. طلبات HTTP في هذا المسار ليست من بايثون:

| الأداة | User-Agent |
|---|---|
| curl في `tool/staging_smoke/reachability.sh` | `VibAbdoMobileSmoke/1.0 (+github-actions)` |
| اختبار Flutter | عميل `dart:io` الافتراضي `Dart/x (dart:io)`، وهو مقبول حسب `staging-readonly-check.ar.md` |

`tool/staging_smoke/preflight.py` لا يفتح اتصالًا. يستخدم `urllib.parse` لتقسيم الرابط فقط، لذلك لا يضع ترويسة User-Agent.

## جدول الأسماء

تُنشأ القيم من القناة الآمنة على بيئة `staging`. هذا المستودع يذكر الأسماء فقط.

| الاسم | النوع | لهذه الوظيفة | الغرض | المرحلة |
|---|---|---|---|---|
| `STAGING_API_BASE` | سر بيئة (مفضّل) أو متغير بيئة بالاسم نفسه | مطلوب. الفارغ يفشل الوظيفة | الأصل فقط. القيمة المقصودة `https://staging.vip2100.com` بلا `/erp` | P-01 |
| `STAGING_ADMIN_USERNAME` | سر بيئة | اختياري حتى اعتماد كلمة المرور. الغياب يتخطى الدخول | حساب المدير لدخان P7-01 (دخول، `/api/me`، القائمة) | P-01 (الاسم). القيمة غير معتمدة بعد |
| `STAGING_ADMIN_PASSWORD` | سر بيئة | اختياري حتى الاعتماد. الغياب يتخطى الدخول ولا يفشل الوظيفة | كلمة مرور المدير. لا تُطبع ولا تُشتق في السجل | P-01 (الاسم). القيمة غير معتمدة بعد |
| `STAGING_EMPLOYEE_USERNAME` | سر بيئة | لا تقرأه هذه الوظيفة. مطلوب لوظيفة الصلاحيات السالبة | دور `employee` | P-01 يطلب إنشاءه على البيئة. المستهلك هو `.github/workflows/staging-negative-permissions.yml` |
| `STAGING_EMPLOYEE_PASSWORD` | سر بيئة | مثل السابق | كلمة مرور الموظف | مثل السابق |
| `STAGING_EMPLOYEE2_USERNAME` | سر بيئة | مثل السابق | موظف ثانٍ لحالات العزل | مثل السابق |
| `STAGING_EMPLOYEE2_PASSWORD` | سر بيئة | مثل السابق | كلمة مروره | مثل السابق |
| `STAGING_LIMITED_MANAGER_USERNAME` | سر بيئة | لا تقرأه هذه الوظيفة. زوج اختياري في فحوص الصلاحيات | مدير محدود. معلّق على DEF-002 | مذكور في P-01. ليس جزءًا من الدخان |
| `STAGING_LIMITED_MANAGER_PASSWORD` | سر بيئة | مثل السابق. الاثنان معًا أو لا شيء في وظيفة الصلاحيات | كلمة مروره | مثل السابق |
| `STAGING_SMOKE_ACCOUNT_ID` | لا يُضبط | غائب. الوظيفة لا تقرأ السر ولا المتغير | كتابة pin. الجسم الحالي `pinned` بلا `isPinned` و`expectedVersion` (G-05) | P-07 |
| `STAGING_SMOKE_SECTION` | ليس سرًا | غير مضبوط هنا. الاختبار يفترض `customers` | قسم قائمة القراءة | اختبار P7-01 القائم. ليس سرًا جديدًا |

## ما يبقى خارج الوظيفة

- لا قيم أسرار في git، ولا تعديل لملف حسابات محلي.
- إقناع القيم بنمط `::add-mask::` قبل أي طلب، داخل GitHub Actions فقط حتى لا تطبع تشغيلًا محليًا السر في الطرفية.
- الخروج `POST /api/auth/logout` هو الكتابة الوحيدة داخل اختبار P7-01 عندما لا يُضبط معرّف الكارت. لا كتابة pin.
