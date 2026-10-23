# مصدر العقد — تسليم مهندس الموقع

هذا المجلد نسخة من تسليم مهندس الموقع لربط تطبيق Android. لم يُعدّل محتوى الملفات المنسوخة. البصمات SHA-256 مطابقة لـ `MANIFEST.json`، وقد تحققنا منها عند النسخ.

| البند | القيمة | المرجع |
|---|---|---|
| commit الموقع | `537f073e8fc76ec2ee9120a198272413d5ea68d9` (`537f073`) | `MANIFEST.json` `sourceCommit`، `README.ar.md` السطر 3 |
| apiVersion | `1` | `README.ar.md` السطر 3، `evidence/public-verification.json` `health.data.apiVersion` |
| schema | `50` | `README.ar.md` السطر 3، `evidence/public-verification.json` `health.data.schemaVersion` |
| رابط staging | `https://staging.vip2100.com` (الواجهة `/erp`، والـ API تحت `/api`) | `openapi.json` `servers[0]`، `README.ar.md` السطر 11 |
| تاريخ التسليم | 2026-10-23 | `README.ar.md` العنوان. `MANIFEST.json` `preparedAt` = `2026-10-22T23:01:22Z` (2026-10-23 01:01 بتوقيت طرابلس UTC+2) |
| البيانات | مصطنعة (`synthetic: true`). لا بيانات أشخاص حقيقية | `MANIFEST.json`، `README.ar.md` السطر 12 |
| فحص البناء | `dirty=true` لأن مشغّل staging غير مرفوع. يقول الموقع إن `src` المالي مطابق للـ commit | `evidence/staging-build-proof.json`، `README.ar.md` السطر 15 |

## بيانات الدخول

**بيانات الدخول ليست في هذا المستودع ولن تكون فيه.** تصل حسابات الأدوار الثلاثة (مدير، ومحدود، ومحصّل) عبر قناة آمنة منفصلة، أي خزنة كلمات مرور بمشاركة محددة المستلم والمدة (`README.ar.md` السطران 16–17). ملفات التسليم المنسوخة كما هي تذكر أسماء مستخدمي الاختبار في أمثلة الأجسام، ولا تذكر كلمات مرورها. كلمات المرور والكوكيز ورموز CSRF غير موجودة. في الأمثلة، `csrfToken` نصّ بديل مثل `<session-csrf-token>`، و`password` نصّ بديل مثل `<private password>`.

لا تُحفظ أسماء المستخدمين ولا كلمات المرور في GitHub، لا كأسرار ولا كمتغيرات. السر الوحيد لوظيفة دخان staging هو `STAGING_API_BASE` داخل Environment `staging`. حسابات الأدوار تبقى على جهاز البوت. لا تُكتب في ملف ولا في سجل ولا في PR.

## الملفات

| الملف | الوصف |
|---|---|
| `openapi.json` | عقد OpenAPI 3.1: ‏80 مسارًا و95 عملية مع SSE (`MANIFEST.json` `openapiValidation`) |
| `endpoints.ar.md` | مرجع مقروء بالعربية مع أمثلة طلب ورد لكل عملية. أمثلة «observed» من sandbox، والباقي توضيحي من الكود |
| `README.ar.md` | إجابات الموقع عن أسئلة الخادم: الجلسة وCSRF والوحدة والإجماليات والتكرار والترقيم |
| `error-catalog.json` | أكواد الأخطاء الحرفية من المصدر مع حالة HTTP والملف والسطر |
| `response-types.ts.txt` | أنواع TypeScript لردود الموقع. مرجع إضافي، والحكم النهائي لردود الخادم |
| `MANIFEST.json` | بصمات الملفات كما سلّمها الموقع |
| `evidence/reconciliation.json` | قيم المطابقة ومراحلها: قبل الدفع، وبعد 250، وبعد 750 |
| `evidence/api-samples.json` | ردود فعلية من sandbox بلا كلمات مرور ولا كوكيز ولا CSRF حقيقي |
| `evidence/MATCHING.ar.md` | جدول مطابقة الموقع مع API. عمود Flutter «لم يُختبر» |
| `evidence/public-verification.json` | فحص HTTPS العام: الدخول والخروج وخصائص الكوكي |
| `evidence/staging-build-proof.json` | بصمة البناء المجمّد |
| `evidence/01…11-*.png` | لقطات واجهة الموقع على البيانات المصطنعة |

## ما استُبعد

- `evidence/12-cloudflare-staging-route.png`: لقطة من لوحة حساب Cloudflare الخاص بالمالك، تُظهر اسم النفق ومسار الخدمة الداخلي. ليست بيانات شخصية، لكنها تفاصيل بنية تحتية لحساب خاص ولا تفيد التطبيق، والمستودع عام. بصمتها باقية في `MANIFEST.json`، والملف غير منسوخ. يمكن طلبه من الموقع مباشرة عند الحاجة.

## فحص الخصوصية قبل الإضافة

فحصنا كل ملف نصي بحثًا عن قيم `Set-Cookie` و`abdo_session=` و`abdo_mfa=` و`csrfToken` و`password` وBearer/JWT ومفاتيح Google/GitHub والمفاتيح الخاصة وأرقام الهواتف الليبية والمصرية والبريد الإلكتروني وعناوين IP الخاصة. وجدنا نصوصًا بديلة فقط: `<session-csrf-token>` و`<new token>` و`<private password>` و`<private letters and digits>` و`test@example.invalid`. كل `phone` في العيّنات `null`. الأسماء في العيّنات واللقطات أسماء اختبار مصطنعة، مثل «عميل المطابقة ألف» و«مدير الاختبار» و«محصل الاختبار». راجعنا اللقطات 01–11 بالعين، ولا تحتوي بيانات حقيقية.

## سياسة التحديث

أي تغيير في API بعد `537f073` يحتاج إصدار عقد جديدًا ومراجعة مشتركة قبل النشر (`README.ar.md` السطر 109). عند وصول نسخة جديدة يُستبدل هذا المجلد في PR مستقل، ويُحدَّث هذا الملف.
