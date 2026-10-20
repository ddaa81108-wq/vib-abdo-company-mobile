# فجوات عقد الـ API

جرد ما يفترضه تطبيق الجوال ولم يؤكّده الخادم. هذا المستند مخرج المرحلة 0 من تحليل المستودع: كل حقل أو كود أو مسار موسوم بـ `proposed` / «مقترح» / 🔶 / `pending server confirmation` / `assumed` / `to confirm` / `STUB`، مع أثر الاختلاف وبديل مؤقت والسؤال الحرفي لمالك الخادم.

- **لا يغيّر هذا المستند سلوك التطبيق.** لا مسارات جديدة، ولا تعديل على الطلبات.
- **أساس الأسطر:** الفرع `main` عند `fea12dd`. الأسطر تشير إلى الملفات كما هي في هذا الجرد.
- **النطاق:** `packages/api_layer/lib/core/network/api_endpoints.dart`، و`packages/api_layer/lib/core/permissions/permission_codes.dart`، وكل `*_models.dart`، ثم العلامات المماثلة في بقية المستودع.
- **ما لم يُدرَج:** مسارات وكودات يصفها التعليق بأنها من العقد القائم (مثل `debts.read` و`POST /api/auth/login` و`GET /api/events`). صيغة السعر `RATE_WIRE_FORMAT` موثّقة في الكود كعقد: الافتراضي `number` لأن الخادم الحالي يتوقع عدد JSON، والهدف `string`. علامة 🔶 على `API_BASE` في `api_config.dart` قيد أمان (لا عنوان إنتاج افتراضي) وليست حقلًا غير مؤكد. مسارا `GET /api/account-requests` و`/api/notification-preferences` موجودان في الملف بلا وسم «مقترح»؛ نقصهما في الواجهة خارج هذا الجرد.

كل بند أدناه يحمل الرقم نفسه في [قائمة الأسئلة](#قائمة-الأسئلة-لمالك-الخادم).

| # | البند | الملف:السطر |
|---|---|---|
| 01 | مخطط Bearer للجوال | `api_endpoints.dart:18-21` |
| 02 | `fullAccess` / `isSuperuser` | `profile_models.dart:28-30` |
| 03 | وجود `sectionAccess` على `GET /api/me` | `profile_models.dart:5` |
| 04 | قيم `sectionAccess` ومنها `read` | `permission_codes.dart:65-76` |
| 05 | `collections.assign` | `permission_codes.dart:88` |
| 06 | `collections.decide` | `permission_codes.dart:89` |
| 07 | `collections.cash_receive` | `permission_codes.dart:90` |
| 08 | `collections.close_day` | `permission_codes.dart:91` |
| 09 | `payroll.manage` | `permission_codes.dart:92` |
| 10 | `debts.zero_review` | `permission_codes.dart:93` |
| 11 | `users.manage` | `permission_codes.dart:94` |
| 12 | `settings.manage` | `permission_codes.dart:95` |
| 13 | `cashStatus` / `cashPending` | `collection_models.dart:40-59` |
| 14 | شكل `GET /api/collections` | `collection_models.dart:3-4` |
| 15 | `PayrollEntryKind` | `collection_models.dart:261` |
| 16 | `GET /api/home` | `api_endpoints.dart:103`، `home_models.dart:3-11` |
| 17 | `GET /api/notifications/unread-count` | `api_endpoints.dart:101` |
| 18 | `title` / `body` للإشعار | `notification_models.dart:4-6` |
| 19 | `POST /api/mobile-push/devices` | `api_endpoints.dart:102` |
| 20 | `GET /api/statements/pdf` | `api_endpoints.dart:105-107` |
| 21 | `systemKind` | `account_models.dart:72-73` |
| 22 | `summary.tabCounts` | `account_models.dart:117-118` |
| 23 | عملة حقول فودافون | `purchase_models.dart:14-15` |
| 24 | حالة يوم المشتريات | `purchase_models.dart:125` |
| 25 | مفاتيح `lifetimeTotals` | `purchase_models.dart:172-173` |
| 26 | حالة صف التقرير | `report_models.dart:34-35` |
| 27 | `changeUnits` | `report_models.dart:62-64` |
| 28 | `activeCashTone` | `treasury_models.dart:29-31` |
| 29 | `MONEY_UNIT_SCALE` | `api_config.dart:45-46` |
| 30 | أكواد انتهاء الجلسة | `error_mapper.dart:12-17` |
| 31 | كود خطأ CSRF | `error_mapper.dart:20-22` |
| 32 | أي 401 آخر = انتهاء جلسة | `error_mapper.dart:119-120` |
| 33 | شكل `error.details` | `error_mapper.dart:199-200` |

آلية الصلاحيات المشتركة للبنود 05–12: التعليق في `permission_codes.dart:83-86` يقول إن الويب الحالي يتحكم بهذه الإجراءات **باسم الدور** (`admin`) بلا كود دقيق، وكل `ManagementAction` يقابل كودًا مقترحًا. `PermissionService.canDo` يسمح بالإجراء إذا وُجد الكود في `permissions[]`، أو إذا كانت الصلاحية كاملة: `fullAccess == true`، أو الدور `admin` وقائمتا `permissions` و`sectionAccess` فارغتان (`permission_service.dart:135-136`). غياب الكود يخفي الزر عن غير المدير الكامل. الإخفاء في الواجهة ليس حماية؛ الخادم يفرض الصلاحية على الطلب نفسه.

---

## 01 — مخطط Bearer للجوال

- **الملف والسطر:** `packages/api_layer/lib/core/network/api_endpoints.dart:18-21` (`proposedMobileLogin` و`proposedMobileRefresh` و`proposedMobileLogout`). العلامات المماثلة: `packages/api_layer/lib/core/auth/bearer_token_auth_strategy.dart:7-11` و`:69`، `packages/api_layer/lib/core/config/api_config.dart:5-7`، `packages/api_layer/lib/core/auth/auth_strategy.dart:17-19`، `packages/api_layer/lib/data/models/auth_models.dart:24-30` (`LoginChallenge`)، `packages/api_layer/lib/core/session/session_manager.dart:25-30` (`SessionOtpRequired`).
- **ما هو مفترض:** مسارات لا توجد على الخادم: `POST /api/auth/mobile/login` يعيد `{accessToken, refreshToken, expiresIn}`، و`POST /api/auth/mobile/refresh` مع تدوير، و`POST /api/auth/mobile/logout`. تجديد الرمز معلّق (`TODO(pending server answer)`). `LoginChallenge` (`loginTicket` و`channel` و`maskedDestination`) لخطوة OTP مستقبلية وغير ناتج اليوم. التشغيل الافتراضي هو Cookie مع `X-CSRF-Token`. تفعيل الـ stub يتم بـ `--dart-define=AUTH_BEARER=true`.
- **الأثر إذا رفض الخادم أو اختلف:** المسارات الثلاثة غير مستدعاة في الكود الحالي؛ `AuthRepository` يبقى على `POST /api/auth/login`. بناء Cookie العادي لا يتأثر بغيابها. إذا فُعّل `AUTH_BEARER` على الخادم الحالي، الدخول ما زال يضرب مسار الكوكي، ولا يُحفظ رمز إلا إذا أعاد الجسم `accessToken` و`refreshToken` كنصين، و`hasPersistedSession` يبقى كاذبًا، وأي 401 على طلب مصادق يُجبر الخروج لأن التجديد غير مبني.
- **البديل المقترح:** الإبقاء على Cookie و`X-CSRF-Token`، وعدم تمرير `AUTH_BEARER`، إلى أن يقرّ المالك المخطط كتابةً.
- **السؤال:** هل تبقى مصادقة الجوال على Cookie مع `X-CSRF-Token` عبر `POST /api/auth/login` و`GET /api/auth/csrf` و`POST /api/auth/logout`، أم سيُضاف مخطط Bearer على `POST /api/auth/mobile/login` (يعيد `accessToken` و`refreshToken` و`expiresIn`) و`POST /api/auth/mobile/refresh` مع تدوير و`POST /api/auth/mobile/logout`؟ وهل سيُنتج الخادم لاحقًا `loginTicket` (وحقول `channel` و`maskedDestination`) لخطوة OTP؟

## 02 — `fullAccess` / `isSuperuser`

- **الملف والسطر:** `packages/api_layer/lib/data/models/profile_models.dart:28-30` (القراءة في `:42`). العلامة المماثلة: `packages/api_layer/lib/core/permissions/permission_service.dart:6` و`:15-17` و`:59-61`.
- **ما هو مفترض:** علم صريح مقترح. يُقرأ `fullAccess` وإن غاب يُقرأ `isSuperuser`. `null` يعني أن الخادم لم يرسله. القيمة تُقبل فقط إذا كانت boolean؛ أي نوع آخر يُعامَل كغياب. عند الإرسال (سواء `true` أو `false`) تتقدّم على قاعدة «مدير بقوائم فارغة = صلاحية كاملة».
- **الأثر إذا رفض الخادم أو اختلف:** الغياب يُبقي السلوك الحالي: مدير بقوائم فارغة يأخذ صلاحية كاملة، والموظف يُحكم بالأكواد و`sectionAccess`. إرسال `false` لمدير بلا قوائم يسقط كل الأقسام والأزرار. إرسال `true` لموظف يفتح كل ما تفتحه الصلاحية الكاملة، بما فيه السجل المالي. إرسال العلم كنص `"true"` أو رقم `1` يُتجاهل فيُعامل كغياب.
- **البديل المقترح:** عدم الاعتماد على العلم حتى يؤكَّد. المدير الكامل يبقى «`admin` مع `permissions` و`sectionAccess` فارغتين». إذا أرسل الخادم العلم لاحقًا فالأولوية المكتوبة في `PermissionService` تُحترَم كما هي.
- **السؤال:** هل يرسل `GET /api/me` الحقل `fullAccess` أو الاسم البديل `isSuperuser` كـ boolean؟ إذا أُرسل `false`، هل يجب أن يلغي ذلك صلاحية المدير ذي القائمتين الفارغتين (`permissions` و`sectionAccess`)؟ وما القيم غير `true`/`false` إن وُجدت؟

## 03 — وجود `sectionAccess` على `GET /api/me`

- **الملف والسطر:** `packages/api_layer/lib/data/models/profile_models.dart:3-5` (التحليل في `:38-41`).
- **ما هو مفترض:** الخريطة شوهِدت على `GET /api/users`، ووجودها على `GET /api/me` بانتظار التأكيد. المفاتيح التي يبحث عنها التطبيق: `customerDebts` و`companyDebts` و`libyanDeposits` و`egyptianDeposits` و`masraweya` و`purchases` و`treasury` و`reports`. قسم الاستلامات بلا مفتاح (`permission_codes.dart:39-41`).
- **الأثر إذا رفض الخادم أو اختلف:** خريطة غائبة أو فارغة مع دور `admin` وقائمة `permissions` فارغة تُعطي صلاحية كاملة. الخريطة الغائبة مع موظف يحمل أكوادًا تُغلق أقسام الكروت (المستوى المفقود = `none`) وتُبقي الاستلامات محكومة بالأكواد فقط. مفتاح باسم مختلف (مثل `customers` بدل `customerDebts`) يُخفي ذلك القسم عن غير المدير الكامل.
- **البديل المقترح:** إذا غابت الخريطة عن `/api/me`، طلبها من المسار الذي يرسلها فعلًا (اليوم `GET /api/users` إن كان هذا هو مصدرها) أو الإبقاء على قاعدة المدير ذي القوائم الفارغة، وإغلاق الأقسام للموظف إلى أن تصل الخريطة.
- **السؤال:** هل توجد خريطة `sectionAccess` داخل `GET /api/me` كما لوحظت على `GET /api/users`؟ وما المفاتيح المؤكدة من بين `customerDebts` و`companyDebts` و`libyanDeposits` و`egyptianDeposits` و`masraweya` و`purchases` و`treasury` و`reports`؟ وهل غياب `collections` من الخريطة مقصود؟

## 04 — قيم `sectionAccess`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:65-76`.
- **ما هو مفترض:** القيم الملاحظة على الخادم `none` و`manage`. القيمة `read` موجودة في كود الويب ولم يُنص على أنها شوهِدت في استجابة حية. أي قيمة أخرى أو غياب المفتاح يُفسَّر `none` (`SectionAccessLevel.parse`).
- **الأثر إذا رفض الخادم أو اختلف:** قسم بقيمة غير هذه الثلاث يختفي عن غير المدير الكامل (قراءة وكتابة). إذا كان اسم مستوى القراءة مختلفًا عن `read`، المستخدم المسموح له بالقراءة فقط لن يرى القسم. الكتابة تتطلب `manage` مع كودي `.read` و`.write`.
- **البديل المقترح:** الإبقاء على الفشل المغلق (`none`) لأي قيمة غير معروفة، وعرض القسم فقط بعد تأكيد النص الحرفي لمستوى القراءة.
- **السؤال:** ما القيم الحرفية المسموحة لـ `sectionAccess[<key>]`؟ الكود لاحظ `none` و`manage`، و`read` موجود في كود الويب. أي قيمة أخرى تُعامَل كـ `none` فيُخفى القسم. هل توجد قيمة ثالثة يجب أن يفهمها التطبيق؟

## 05 — `collections.assign`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:88`. الاستدعاء: `lib/features/accounts/account_list_screen.dart:197` وزر الإسناد في شاشتي العملاء والشركات. المسار: `POST /api/collections/assignments`.
- **ما هو مفترض:** كود صريح مقترح. الويب يفتح الإسناد باسم الدور لا بهذا الكود.
- **الأثر إذا رفض الخادم أو اختلف:** غير المدير الكامل لا يرى وضع الإسناد. المدير الكامل يرى الزر ويستدعي المسار؛ رفض الخادم للطلب يظهر كخطأ في النموذج ولا ينشئ إسنادًا.
- **البديل المقترح:** إظهار الإسناد للصلاحية الكاملة فقط إلى أن يُرجع الخادم الكود، وعدم إرسال الكود نفسه في جسم الطلب.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `collections.assign` داخل `permissions[]`؟ إن لم يُرجعه، هل يبقى `POST /api/collections/assignments` مسموحًا للمدير الكامل فقط؟

## 06 — `collections.decide`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:89`. الاستدعاء: `lib/features/collections/collections_screen.dart:30`. يخفي المؤشرات وإجماليات الموظفين وأزرار الاعتماد والرفض وربط الاستلام غير المربوط. المساران: `POST /api/collections/submissions/{id}/decision` و`POST /api/collections/unlinked-receipts/{id}/decision`.
- **ما هو مفترض:** كود صريح مقترح.
- **الأثر إذا رفض الخادم أو اختلف:** موظف التحصيل لا يرى أزرار القرار حتى لو سمح الخادم بالطلب. المدير الكامل يراها. قرار متزامن بلا `expectedVersion` يرفضه التطبيق محليًا قبل الإرسال (`collections_repository.dart` يشترط الإصدار).
- **البديل المقترح:** قصر أزرار القرار على الصلاحية الكاملة، والإبقاء على `expectedVersion` كما هو.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `collections.decide` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى قرارات الاعتماد والرفض والربط (`POST /api/collections/submissions/{id}/decision` و`POST /api/collections/unlinked-receipts/{id}/decision`) ومؤشرات الشاشة للمدير الكامل فقط؟

## 07 — `collections.cash_receive`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:90`. الاستدعاء: `lib/features/collections/collections_screen.dart:31` و`:468`. المساران: `POST /api/collections/submissions/{id}/cash-received` و`POST /api/collections/unlinked-receipts/{id}/cash-received`.
- **ما هو مفترض:** كود صريح مقترح. الزر يحتاج أيضًا `cashStatus == pending` (البند 13).
- **الأثر إذا رفض الخادم أو اختلف:** الزر مخفي عن غير المدير الكامل. المدير الكامل لا يراه هو الآخر إذا لم تكن حالة النقد `pending`. رفض المسار يظهر كخطأ بعد الضغط.
- **البديل المقترح:** إبقاء الزر مشروطًا بالصلاحية الكاملة وبقيمة `pending` القادمة من الخادم، وعدم اشتقاق «ينتظر النقد» من `status` أو `cashReceivedAt`.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `collections.cash_receive` داخل `permissions[]`؟ إن لم يُرجعه، هل يبقى `POST /api/collections/submissions/{id}/cash-received` و`POST /api/collections/unlinked-receipts/{id}/cash-received` للمدير الكامل فقط؟

## 08 — `collections.close_day`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:91`. الاستدعاء: `lib/features/collections/collections_screen.dart:32` و`:103`. المسار: `POST /api/collections/days/close`.
- **ما هو مفترض:** كود صريح مقترح. الزر يحتاج أيضًا `batchId` غير فارغ.
- **الأثر إذا رفض الخادم أو اختلف:** غير المدير الكامل لا يرى «إقفال اليوم». المدير الكامل لا يراه إذا غاب معرّف الدفعة. رفض المسار يظهر كخطأ ولا يُقفَل اليوم محليًا.
- **البديل المقترح:** إبقاء الإقفال للصلاحية الكاملة ومعرّف دفعة يرسله الخادم.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `collections.close_day` داخل `permissions[]`؟ إن لم يُرجعه، هل يبقى `POST /api/collections/days/close` للمدير الكامل فقط؟

## 09 — `payroll.manage`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:92`. الاستدعاء: `lib/features/collections/collections_screen.dart:33` و`:112` و`:704`.
- **ما هو مفترض:** كود صريح مقترح لعنوان «المرتبات». من يملك `collections.write` بلا هذا الكود يرى البلوك بعنوان «مرتبي». مسارات الحركة والراتب الأساسي والتأكيد موجودة في `collections_repository.dart` بلا نموذج في الشاشة.
- **الأثر إذا رفض الخادم أو اختلف:** الموظف صاحب `collections.write` ما زال يطلب `GET /api/collections/payroll` ويرى الباقي. إدارة المرتبات لا تظهر في الواجهة اليوم، فاختلاف قيم `kind` لا يُرسل من الشاشة (انظر البند 15).
- **البديل المقترح:** الإبقاء على العرض لصاحب الكتابة أو الصلاحية الكاملة، وتأجيل نماذج الإدارة حتى يُؤكد الكود والقيم.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `payroll.manage` داخل `permissions[]`؟ إن لم يُرجعه، هل يرى غير المدير «مرتبي» فقط عبر `collections.write`، وتبقى إدارة المرتبات (حركة، راتب أساسي، تأكيد) خارج الجوال؟

## 10 — `debts.zero_review`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:93`. الاستدعاء: `lib/features/accounts/account_list_screen.dart:167-171`. المسار: `POST /api/customers/{id}/zero-review` مع `expectedFinancialVersion`.
- **ما هو مفترض:** كود صريح مقترح، وقسم العملاء فقط.
- **الأثر إذا رفض الخادم أو اختلف:** زر «مراجعة التصفير» مخفي عن غير المدير الكامل، وعن كل الأقسام غير العملاء، وعن الكارت `systemManaged`. المدير الكامل يرسل الطلب؛ الرفض يظهر كخطأ.
- **البديل المقترح:** إبقاء الزر للصلاحية الكاملة على عملاء غير مُدارين من النظام.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `debts.zero_review` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى `POST /api/customers/{id}/zero-review` للمدير الكامل فقط؟

## 11 — `users.manage`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:94` (`accountRequestsDecide`). يظهر زرًا في الرئيسية بعنوان «طلبات الحسابات» ينقل إلى `/settings` (`lib/ui/section_labels.dart:63` و`:74-75`). لا مستودع يستدعي `POST /api/account-requests/{id}/decision`.
- **ما هو مفترض:** كود صريح مقترح. المسار نفسه في `api_endpoints.dart:88-90` غير موسوم «مقترح»؛ غير المؤكد هو كود الصلاحية.
- **الأثر إذا رفض الخادم أو اختلف:** غير المدير الكامل لا يرى زر الإجراء. المدير الكامل يرى الزر ويصل إلى شاشة إعدادات بلا قائمة طلبات. لا يُرسل قرار حسابات من التطبيق اليوم.
- **البديل المقترح:** إبقاء قرارات طلبات الحسابات على الويب إلى أن يُؤكد الكود وتُطلب شاشة الجوال صراحة.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `users.manage` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى قرارات `POST /api/account-requests/{id}/decision` خارج الجوال؟

## 12 — `settings.manage`

- **الملف والسطر:** `packages/api_layer/lib/core/permissions/permission_codes.dart:95`. الاستدعاء: `lib/features/home/home_shell.dart:205-206`، `lib/authentication/auth_gate.dart:47-50`، `lib/features/settings/settings_screen.dart:22-34`.
- **ما هو مفترض:** كود صريح مقترح لفتح الإعدادات. بلاطات الموظفين وسجل التدقيق ومركز التشغيل تعرض النص «لا تتوفر بيانات من الخادم» ولا تستدعي مسارًا.
- **الأثر إذا رفض الخادم أو اختلف:** غير المدير الكامل يُعاد من `/settings` إلى الرئيسية، إلا صاحب الصلاحية الكاملة الذي يدخل من أجل السجل المالي (`canViewFinancialLedger`). المدير الكامل يرى البلاطات الفارغة.
- **البديل المقترح:** إبقاء الإعدادات الإدارية للصلاحية الكاملة، والإبقاء على البلاطات كنص «لا تتوفر بيانات» حتى يقرر المالك إن كانت مطلوبة في الجوال.
- **السؤال:** هل سيُرجع `GET /api/me` الكود `settings.manage` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى شاشة الإعدادات (الموظفون، سجل التدقيق، مركز التشغيل) للصلاحية الكاملة فقط؟

## 13 — `cashStatus` / `cashPending`

- **الملف والسطر:** `packages/api_layer/lib/data/models/collection_models.dart:40-59` (الحقول في `:79-80` و`:117`). الواجهة: `lib/features/collections/collections_screen.dart:420` و`:468` و`:543`.
- **ما هو مفترض:** حقول مقترحة. `cashStatus` إحدى `pending` أو `received` أو `not_applicable`. إن غاب النص يُقرأ `cashPending == true` كـ `pending` فقط. الغياب يعيد `null`. التطبيق لا يشتق الحالة من `status` ولا من `cashReceivedAt`.
- **الأثر إذا رفض الخادم أو اختلف:** شارة «ينتظر النقد» وزر «استلام نقدي» لا يظهران إلا عند قيمة تُفسَّر `pending`. نص مختلف (مثل `awaiting` أو `waiting_cash`) يُخفي الزر حتى عن المدير الكامل الذي يملك `collections.cash_receive`. `cashPending: false` لا يعني `received`؛ يبقى العرض بلا شارة.
- **البديل المقترح:** إبقاء الزر مخفيًا عند الغياب أو عند قيمة غير معروفة. عرض `cashReceivedAt` كوقت فقط إن وُجد، بلا تحويله إلى حالة.
- **السؤال:** هل يرسل الخادم على الاستلام وعلى الاستلام غير المربوط الحقل `cashStatus` بالقيم `pending` أو `received` أو `not_applicable`، أو الحقل `cashPending: true`؟ ما النص الحرفي إن اختلف؟ بدون قيمة تُقرأ كـ `pending` لا يظهر شارة «ينتظر النقد» ولا زر تأكيد استلام النقد.

## 14 — شكل استجابة `GET /api/collections`

- **الملف والسطر:** `packages/api_layer/lib/data/models/collection_models.dart:3-4`. مواضع الأسماء البديلة: `:30`، `:96`، `:123`، `:144`، `:184-209`، `:236-237`.
- **ما هو مفترض:** التعليق يقول إن أشكال الاستجابة أبعد من أسماء الحقول غير مؤكدة (شوهِدت في واجهة الويب فقط) والتحليل دفاعي ويبقي `raw`. الأسماء التي يقرأها التطبيق:
  - مصفوفات `assignments` و`submissions` و`unlinkedReceipts` و`employeeTotals`.
  - للإسناد: `customerName` ثم `name`، و`section` و`phone` و`balanceUnits` و`assigneeName` و`status`.
  - للاستلام: `mode` و`amountUnits` و`status` و`version` و`submittedByName` ثم `employeeName` و`createdAt`.
  - لغير المربوط: `customerName` ثم `name`.
  - لإجمالي الموظف: `employeeName` ثم `displayName`، و`collectedUnits` و`approvedCount` و`pendingCount`.
  - للمؤشرات: `metrics.collectedUnits`؛ و`dayTotalUnits` من `metrics` ثم من الجذر؛ و`assignedCount` من الجذر ثم من `metrics`؛ و`metrics.pendingCount` و`metrics.unlinkedPendingCount` و`metrics.cashOutstandingUnits`؛ و`batchId` ثم `batch.id`.
  - للمرتب: `userId` ثم `employeeUserId` ثم `id`، و`displayName` ثم `name`، و`baseSalaryUnits` و`openingCarryUnits` و`commissionsUnits` و`withdrawalsUnits` و`remainingUnits`.
  - الواجهة تعامل `mode == full` كاستلام كامل وأي نص آخر كجزئي (`collections_screen.dart:431-433`). حالة غير `pending` / `approved` / `rejected` تُعرض كنصها الخام.
- **الأثر إذا رفض الخادم أو اختلف:** مصفوفة باسم آخر تُعرض فارغة بلا خطأ. مؤشر في مكان آخر يظهر «—». مبلغ ليس عدد JSON صحيح يُفشل الاستجابة كلها (`unitsOrNull` يرمي `INVALID_SERVER_RESPONSE`) فتظهر شاشة الاستلامات كخطأ. `mode` بقيمة غير `full` يُعنوَن «جزئي». غياب `batchId` و`batch.id` يخفي إقفال اليوم.
- **البديل المقترح:** الإبقاء على القراءة الدفاعية والأسماء البديلة الحالية، وإظهار «—» للحقل الغائب، وعدم جمع المؤشرات على الجهاز. أي مفتاح يختلف عن القائمة أعلاه يُصحَّح في المحوّل بعد جواب المالك لا بتخمين إضافي.
- **السؤال:** ما شكل JSON الفعلي لـ `GET /api/collections`؟ أكد أو صحّح: مصفوفات `assignments` و`submissions` و`unlinkedReceipts` و`employeeTotals`؛ و`metrics.collectedUnits` و`metrics.dayTotalUnits` (أو `dayTotalUnits` في الجذر) و`assignedCount` (في الجذر أو داخل `metrics`) و`metrics.pendingCount` و`metrics.unlinkedPendingCount` و`metrics.cashOutstandingUnits`؛ و`batchId` أو `batch.id`؛ وأسماء العرض البديلة `customerName`/`name` و`submittedByName`/`employeeName` و`employeeName`/`displayName`. وما قيم `mode` (`full`/`partial`) و`status` (`pending`/`approved`/`rejected`)؟

## 15 — `PayrollEntryKind`

- **الملف والسطر:** `packages/api_layer/lib/data/models/collection_models.dart:261`. الإرسال المحتمل: `collections_repository.dart:178-187` يضع الحقل `kind` كما يصله، ولا تستدعيه أي شاشة.
- **ما هو مفترض:** القيمتان `withdrawal` و`commission`، والتعليق يسميهما 🔶 «القيم الحرفية للخادم».
- **الأثر إذا رفض الخادم أو اختلف:** لا أثر على الشاشات الحالية لأن لا نموذج يرسل `kind`. عند وصل الإدارة لاحقًا، قيمة مرفوضة تُفشل `POST /api/collections/payroll/entries` وتظهر خطأ الحفظ.
- **البديل المقترح:** عدم بناء نموذج حركة المرتب حتى تصل القيم الحرفية. الإبقاء على عرض `remainingUnits` القادم من `GET /api/collections/payroll`.
- **السؤال:** ما القيم الحرفية لحقل `kind` في `POST /api/collections/payroll/entries`؟ النموذج يفترض `withdrawal` و`commission` (`PayrollEntryKind`). هل إدارة المرتبات مطلوبة في الجوال؟

## 16 — `GET /api/home`

- **الملف والسطر:** `packages/api_layer/lib/core/network/api_endpoints.dart:100-103` (`proposedHome`). الشكل: `packages/api_layer/lib/data/models/home_models.dart:3-11` و`:14-24` و`:49-50`. الاستدعاء الفعلي في الوضع الحقيقي: `packages/api_layer/lib/data/repositories/home_repository.dart:5-20` ثم `lib/features/home/home_fallback.dart:6-19`.
- **ما هو مفترض:** المسار غير موجود على الخادم. الشكل المقترح: `businessDate` و`generatedAt` و`summaries[]` (`key` و`section` و`title` و`valueUnits` و`currency` و`tone` و`note` و`status` و`updatedAt`) و`counters` و`oldDebts[]` (`id` و`section` و`name` و`balanceUnits` و`currency` و`debtAgeDays` و`ageStatus` و`ageStatusLabel`). `tone` يُقبل `positive` أو `negative` أو `neutral` وغير ذلك يصبح محايدًا. تعليق `status` داخل هذا الملف يذكر `normal` و`review` و`critical` و`missing_rate`، وهي مجموعة تختلف عن بند 26.
- **الأثر إذا رفض الخادم أو اختلف:** كل فتح للرئيسية في الوضع الحقيقي يستدعي `GET /api/home` أولًا. 404 أو أي خطأ ينتقل إلى بيانات الأقسام الموجودة (ملخص الكروت، ومؤشرات الاستلامات، والخزينة، وأول صف تقرير) بألوان محايدة وبلا `oldDebts`. استجابة 200 بجسم فارغ أو بمفاتيح مختلفة تُعرض كما هي ولا تسقط إلى البديل: بطاقات بلا عنوان أو قائمة فارغة. `tone` غير معروف يترك البطاقة محايدة. تعليق `api_layer.dart:91` («Real mode never calls proposed paths») ينطبق على تصدير PDF لا على هذا المسار.
- **البديل المقترح:** الاستمرار في `loadHome`: فشل المسار يعرض حقول الأقسام كما أعادها الخادم دون جمعها. بعد قرار المالك بعدم بناء المسار يُحذف الاستدعاء في تغيير لاحق حتى لا يبقى 404 في كل زيارة.
- **السؤال:** هل سيُبنى `GET /api/home`؟ إن نعم، هل الشكل هو `businessDate` و`generatedAt` و`summaries[]` بحقول `key` و`section` و`title` و`valueUnits` و`currency` و`tone` و`note` و`status` و`updatedAt`، و`counters` كخريطة أعداد، و`oldDebts[]` بحقول `id` و`section` و`name` و`balanceUnits` و`currency` و`debtAgeDays` و`ageStatus` و`ageStatusLabel`؟ وما قيم `tone` (`positive`/`negative`/`neutral`) وقيم `status`؟ إن لن يُبنى، هل نعتمد بيانات الأقسام الحالية ونتوقف عن استدعاء `/api/home`؟

## 17 — `GET /api/notifications/unread-count`

- **الملف والسطر:** `packages/api_layer/lib/core/network/api_endpoints.dart:101`. العلامة المماثلة: `packages/api_layer/lib/data/repositories/notifications_repository.dart:13-15` و`:40-41`. الشارة: `lib/state/notification_providers.dart:7-12`.
- **ما هو مفترض:** مسار خفيف مقترح. الكود لا يستدعيه. `fetchUnreadCount` يقرأ `unreadCount` من الصفحة الأولى لـ `GET /api/notifications`. غياب العدد يترك الشارة مخفية؛ الصفر عدد حقيقي (`notification_models.dart:45-46`).
- **الأثر إذا رفض الخادم أو اختلف:** غياب المسار المقترح لا يغيّر السلوك الحالي. غياب `unreadCount` من قائمة الإشعارات يخفي الشارة حتى لو وُجدت إشعارات غير مقروءة. اسم حقل مختلف يُخفي الشارة أيضًا. التطبيق لا يزيد العدد محليًا.
- **البديل المقترح:** الإبقاء على `unreadCount` داخل `GET /api/notifications`، وإخفاء الشارة عند غياب العدد، وعدم استدعاء المسار المقترح.
- **السؤال:** هل يبقى عدد غير المقروء في الحقل `unreadCount` داخل `GET /api/notifications`، أم سيُضاف `GET /api/notifications/unread-count`؟ وما اسم الحقل إن اختلف عن `unreadCount`؟

## 18 — `title` / `body` للإشعار

- **الملف والسطر:** `packages/api_layer/lib/data/models/notification_models.dart:4-6` (القراءة في `:27-36`). العرض: `lib/features/notifications/notifications_screen.dart:120-125` و`lib/ui/presentation.dart:200-206`.
- **ما هو مفترض:** التطبيق يطلب `title` و`body` من الخادم. إلى أن يصلا يعرض عنوانًا ثابتًا حسب `action` ولا يعرض أرقامًا من `details`. المفاتيح البديلة المقروءة: `type` بدل `action`، و`aggregateId` بدل `entityId`.
- **الأثر إذا رفض الخادم أو اختلف:** إشعار بلا `title` يظهر بعنوان ثابت (`collection.submit` مثلًا: «استلام جديد بانتظار المراجعة»، وأي `action` غير معروف: «إشعار»). نص الويب المخزّن في `details` لا يُرسم. مفتاح عنوان مختلف عن `title` يُسقط النص القادم من الخادم.
- **البديل المقترح:** الإبقاء على العنوان الثابت حسب `action` عند غياب `title`، وعدم بناء النص من `details` على الجهاز.
- **السؤال:** هل يرسل الإشعار `title` و`body`، أم النص يُبنى في الويب من `action` و`details` فقط؟ ما المفاتيح الفعلية للعنوان والنص و`entityId` (التطبيق يقبل أيضًا `type` و`aggregateId`)؟

## 19 — `POST /api/mobile-push/devices`

- **الملف والسطر:** `packages/api_layer/lib/core/network/api_endpoints.dart:102`. العلامة المماثلة: `packages/api_layer/lib/core/push/push_service.dart:1-6`، `lib/notifications/app_push_service.dart:5-8`.
- **ما هو مفترض:** تسجيل جهاز جوال غير مبني على الخادم. الخادم يملك دفع الويب `/api/browser-push/*` (VAPID وعامل خدمة) وهو غير قابل للاستخدام من تطبيق أصلي. لا FCM ولا APNs. الثابت غير مستدعى. `NoopPushService` لا يُصدر رمز جهاز.
- **الأثر إذا رفض الخادم أو اختلف:** لا تسجيل جهاز ولا إشعار خارج التطبيق. التحديث في المقدمة يعتمد `GET /api/events` ثم `GET /api/event-changes` كل 4 ثوانٍ. تعطل القناتين يحدّث الشارة عند إعادة الجلب فقط.
- **البديل المقترح:** الإبقاء على `NoopPushService` مع SSE ثم الاستقصاء، وعدم استدعاء `/api/mobile-push/devices`.
- **السؤال:** هل سيُضاف تسجيل جهاز الجوال على `POST /api/mobile-push/devices` (FCM/APNs)، أم يبقى الدفع للويب فقط عبر `/api/browser-push/*` والجوال يكتفي بـ `GET /api/events` و`GET /api/event-changes`؟

## 20 — `GET /api/statements/pdf`

- **الملف والسطر:** `packages/api_layer/lib/core/network/api_endpoints.dart:105-107`. الشكل: `packages/api_layer/lib/data/models/report_models.dart:136-137` (`filename` و`contentBase64`). الاستدعاء محصور بوضع Fake: `lib/ui/widgets/export_pdf_button.dart:9-11` و`:27` و`:49-50`، و`packages/api_layer/lib/data/repositories/reports_repository.dart:11-13`.
- **ما هو مفترض:** تصدير PDF غير موجود على الخادم. الجسم المتوقع `{filename, contentBase64}`. الزر يظهر لصاحب الصلاحية الكاملة أثناء الـ Fake فقط.
- **الأثر إذا رفض الخادم أو اختلف:** الوضع الحقيقي لا يرسل الطلب. لو استُدعي المسار لاحقًا بجسم ثنائي أو بمفتاح غير `contentBase64`، `StatementFile.fromData` يرمي `INVALID_SERVER_RESPONSE`.
- **البديل المقترح:** إبقاء الزر مخفيًا خارج الـ Fake، وعدم عرض تصدير في الوضع الحقيقي.
- **السؤال:** هل سيُضاف `GET /api/statements/pdf`؟ إن نعم، هل الجسم `{filename, contentBase64}` أم ملف ثنائي؟ وإن لن يُضاف، يبقى الزر مخفيًا خارج وضع Fake.

## 21 — `systemKind`

- **الملف والسطر:** `packages/api_layer/lib/data/models/account_models.dart:72-73` (القراءة في `:95`). `systemLinkKey` في `:69-70` موصوف بأنه مؤكد ولا يُستنبط منه `systemKind`.
- **ما هو مفترض:** الحقل بانتظار تأكيد الخادم. يُحفظ كما يصل. لا شاشة في `lib/` تقرأه. إخفاء الكتابة يعتمد `systemManaged` فقط.
- **الأثر إذا رفض الخادم أو اختلف:** غيابه لا يغيّر الشاشة. إذا كان الخادم يعلّم كارت النظام بـ `systemKind` دون `systemManaged`، أزرار الكتابة تبقى ظاهرة لأن التطبيق لا يستنتج أحدهما من الآخر.
- **البديل المقترح:** الإبقاء على `systemManaged` كبوابة الكتابة الوحيدة، وترك `systemKind` مخزّنًا بلا عرض إلى أن تُؤكد قيمه.
- **السؤال:** هل يرسل كارت الحساب الحقل `systemKind`، وما قيمه الحرفية؟ وهل يغني عن `systemManaged`؟ التطبيق لا يستنتج `systemKind` من `systemLinkKey` ولا يعرضه اليوم.

## 22 — `summary.tabCounts`

- **الملف والسطر:** `packages/api_layer/lib/data/models/account_models.dart:117-118` (القراءة في `:125-128`).
- **ما هو مفترض:** الكائن مطلوب من الخادم بالمفاتيح `active` و`today` و`debts` و`paid` و`pinned` و`pendingReview`. الواجهة لا تقرأ الخريطة؛ تبويب النشط يستخدم `activeCards`، وتبويب مراجعة التصفير يستخدم `pendingReviewCount`، وبقية التبويبات بلا عدد (`account_list_screen.dart:383-396`).
- **الأثر إذا رفض الخادم أو اختلف:** غياب `tabCounts` لا يغيّر التبويبات الحالية. غياب `activeCards` أو `pendingReviewCount` يخفي الرقم عن عنوان التبويب ويبقي التبويب قابلًا للاختيار.
- **البديل المقترح:** الإبقاء على العددين المعروضين (`activeCards` و`pendingReviewCount`) وتجاهل الخريطة حتى يؤكد المالك مفاتيحها.
- **السؤال:** هل يرسل `GET /api/{section}` الكائن `summary.tabCounts` بالمفاتيح `active` و`today` و`debts` و`paid` و`pinned` و`pendingReview`؟ الواجهة اليوم تعرض العدد من `activeCards` و`pendingReviewCount` فقط.

## 23 — عملة حقول فودافون

- **الملف والسطر:** `packages/api_layer/lib/data/models/purchase_models.dart:14-15` (`vodafoneCurrencyAssumption = Currency.egp`). العرض الفعلي يثبت `Currency.egp` في `lib/features/purchases/purchases_screen.dart:156-160` ولا يقرأ الثابت.
- **ما هو مفترض:** عملة `vodafoneConsumedUnits` و`vodafoneRemainingUnits` غير منصوصة في واجهة الويب، والمفترض EGP حتى التأكيد. `egpValueUnits` مسمّى صراحة بالجنيه؛ الناتج والمدفوع والمتبقي مسمّاة LYD في النموذج.
- **الأثر إذا رفض الخادم أو اختلف:** الخادم لا يرفض الطلب بسبب هذا الافتراض لأن التطبيق لا يرسل حقل عملة لهذه القيم. إذا كانت الوحدة دينارًا، الشاشة تعرض المبلغ بجانب «ج.م». الاتجاه («لنا» / «لنا عليه») في `vodafoneCaption` يعتمد إشارة العدد لا العملة.
- **البديل المقترح:** الإبقاء على عرض «ج.م» إلى جواب المالك، ثم تبديل الرمز فقط دون أي تحويل على الجهاز.
- **السؤال:** ما عملة `vodafoneConsumedUnits` و`vodafoneRemainingUnits`؟ الثابت `vodafoneCurrencyAssumption` يفترض `EGP`، وشاشة المشتريات تعرض «باقي فودافون» بـ `ج.م`.

## 24 — حالة يوم المشتريات

- **الملف والسطر:** `packages/api_layer/lib/data/models/purchase_models.dart:125`. التفسير في الواجهة: `lib/ui/presentation.dart:185-198`. زر الاعتماد: `lib/features/purchases/purchases_screen.dart:173` (`status == 'draft'` فقط).
- **ما هو مفترض:** التعليق يسمّي `draft` و`finalized` و`correction` بعلامة 🔶. الواجهة تقبل أيضًا `open` (تُعرض كمسودة وقابلة للتحرير) و`correctionOpen` (تُعرض كتصحيح مفتوح وقابلة للتحرير).
- **الأثر إذا رفض الخادم أو اختلف:** قيمة غير `draft` و`open` و`correction` و`correctionOpen` تخفي الإضافة والتعديل والحذف. زر الاعتماد لا يظهر إلا للنص `draft` حرفيًا؛ يوم مسودة اسمه `open` يبقى قابلًا للتحرير بلا زر اعتماد. نص غير معروف يُعرض كما هو.
- **البديل المقترح:** معاملة غير المعروف كغير قابل للتحرير، وإظهار الاعتماد فقط للقيمة التي يسمّيها المالك «مسودة».
- **السؤال:** ما القيم الحرفية لحالة يوم المشتريات `status`؟ النموذج يذكر `draft` و`finalized` و`correction`. الواجهة تعامل أيضًا `open` و`correctionOpen` كيوم قابل للتحرير، وزر الاعتماد يظهر فقط عندما تكون القيمة `draft` بالضبط.

## 25 — مفاتيح إجماليات سجل المشتريات

- **الملف والسطر:** `packages/api_layer/lib/data/models/purchase_models.dart:172-173` (`PurchasesLifetimeTotalsDto`، القراءة من `lifetimeTotals` ثم `totals` في `:165-167`).
- **ما هو مفترض:** أسماء المفاتيح بانتظار تأكيد الخادم. التطبيق يسمي `resultUnits` و`paidUnits` و`remainingUnits`، ويحتفظ بكل مفتاح قيمته عدد صحيح داخل `all`. التعليق: قيمة تالفة تُفشل الاستجابة كلها.
- **الأثر إذا رفض الخادم أو اختلف:** مفتاح باسم آخر يجعل سطر «منذ البداية» يظهر «—» بينما قد يبقى الرقم داخل `all` غير معروض. قيمة كسرية أو نصية لأي مفتاح في الكائن ترمي `INVALID_SERVER_RESPONSE` فيفشل تحميل الدفتر، لا السطر فقط.
- **البديل المقترح:** عند اختلاف الأسماء، عرض «—» للأسماء الثلاثة المعروفة وعدم تخمين مفتاح رابع في الواجهة. القيمة غير الصحيحة تبقى خطأ استجابة كما هي اليوم.
- **السؤال:** ما أسماء مفاتيح إجماليات سجل المشتريات (`lifetimeTotals` أو `totals`)؟ التطبيق يقرأ `resultUnits` و`paidUnits` و`remainingUnits`. أي قيمة ليست عدد JSON صحيح تُفشل استجابة الدفتر كلها (`INVALID_SERVER_RESPONSE`).

## 26 — حالة صف التقرير

- **الملف والسطر:** `packages/api_layer/lib/data/models/report_models.dart:34-35`. القبول في الواجهة: `lib/ui/presentation.dart:151-168`. مجموعة ثانية في تعليق الرئيسية: `home_models.dart:49-50`.
- **ما هو مفترض:** النموذج يذكر `normal` و`needs_review` و`urgent_review` و`rate_missing` بعلامة 🔶. الواجهة تقبل أيضًا `review` و`critical` و`missing_rate`. تعليق بطاقة الرئيسية يستخدم المجموعة الثانية.
- **الأثر إذا رفض الخادم أو اختلف:** قيمة خارج المجموعتين تخفي شارة الحالة (`ReportStatusChip` يعيد صندوقًا فارغًا) وتُبقي أرقام الصف. الصف يبقى للقراءة فقط. لا زر كتابة على التقارير أصلًا.
- **البديل المقترح:** إبقاء الشارة للمجموعتين إلى جواب المالك، ثم الإبقاء على المجموعة التي يرسلها الخادم وحذف المرادفات.
- **السؤال:** ما القيم الحرفية لحالة صف التقرير `status`؟ النموذج يذكر `normal` و`needs_review` و`urgent_review` و`rate_missing`. الواجهة تقبل أيضًا `review` و`critical` و`missing_rate` (وتعليق `GET /api/home` يستخدم هذه المجموعة الثانية). أي قيمة أخرى تُخفي شارة الحالة.

## 27 — `changeUnits`

- **الملف والسطر:** `packages/api_layer/lib/data/models/report_models.dart:62-64` (النص في `:66`). العرض: `lib/features/reports/reports_screen.dart:300-303`.
- **ما هو مفترض:** حقل مبلغ مقترح. الغياب يبقى `null` وتُعرض «—». نص السبب يُقرأ من `text` ثم `message` ثم `label`. المبلغ يُرسم بعملة `LYD` ثابتة في الواجهة.
- **الأثر إذا رفض الخادم أو اختلف:** غياب `changeUnits` يُظهر «—» بجانب النص ولا يُسقط الشاشة. مبلغ غير عدد صحيح يُفشل استجابة التقارير كلها. إذا كانت العملة EGP فالرموز المعروض «د.ل» خطأ، بلا تحويل حسابي.
- **البديل المقترح:** الإبقاء على «—» عند الغياب، وعدم اشتقاق المبلغ من نص السبب، وتثبيت العملة بعد جواب المالك.
- **السؤال:** هل يرسل سبب التقرير الحقل `changeUnits`، وما عملته؟ التطبيق يعرضه كـ `LYD`. وما مفتاح النص إن لم يكن `text` (يقبل أيضًا `message` و`label`)؟

## 28 — `activeCashTone`

- **الملف والسطر:** `packages/api_layer/lib/data/models/treasury_models.dart:29-31` (القراءة في `:49-50`: `totals.activeCashTone` ثم `totals.tone` ثم `activeCashTone` في الجذر). اللون: `lib/features/treasury/treasury_screen.dart:205-209`.
- **ما هو مفترض:** حقل مقترح بقيم `SummaryTone`: `positive` أو `negative` أو `neutral`. الغياب أو قيمة غير معروفة يبقى `null` والبطاقة محايدة.
- **الأثر إذا رفض الخادم أو اختلف:** بطاقة «الفلوس النشطة» تبقى بلون محايد. قيمة مثل `up` أو `down` لا تُلوَّن. الحقل لا يغيّر الرقم؛ الرقم يبقى `activeCashUnits` كما أرسله الخادم.
- **البديل المقترح:** الإبقاء على اللون المحايد عند الغياب، وعدم تلوين البطاقة من إشارة المبلغ.
- **السؤال:** هل يرسل `GET /api/treasury` الحقل `activeCashTone` أو `tone` بالقيم `positive` أو `negative` أو `neutral`؟ غياب القيمة أو قيمة غير معروفة يُبقي بطاقة الفلوس النشطة بلون محايد.

## 29 — `MONEY_UNIT_SCALE`

- **الملف والسطر:** `packages/api_layer/lib/core/config/api_config.dart:45-46` و`:62-63`. العلامة المماثلة: `packages/api_layer/lib/core/money/money_formatter.dart:33`، و`packages/api_layer/README.md:10`. الرفض عند اللاعدد الصحيح: `packages/api_layer/lib/data/models/common.dart:27-36`.
- **ما هو مفترض:** عدد الخانات الكسرية داخل أعداد `*Units` = 0، قياسًا على عرض الويب `maximumFractionDigits: 0`. أي دينار أو جنيه عدد صحيح. يمكن تمرير مقياس آخر بـ `--dart-define=MONEY_UNIT_SCALE`، والافتراضي 0.
- **الأثر إذا رفض الخادم أو اختلف:** مقياس فعلي 3 مع إرسال `125000` يعرض «125,000 د.ل» بدل «125.000 د.ل» لأن التنسيق لا يقسم. عدد JSON كسري أو نص أو أس يُفشل الاستجابة التي تحوي المبلغ (`INVALID_SERVER_RESPONSE`) فتظهر الشاشة خطأ لا شرطة.
- **البديل المقترح:** الإبقاء على المقياس 0 وعلى رفض غير العدد الصحيح، وتغيير `MONEY_UNIT_SCALE` فقط بعد تأكيد عدد الخانات، بلا حساب فروقات على الجهاز.
- **السؤال:** هل أعداد `*Units` أعداد صحيحة بلا كسور، أي `MONEY_UNIT_SCALE = 0`؟ أم فيها خانات عشرية ثابتة يجب أن يمرّرها التطبيق؟ وهل يرفض الخادم إرسال المبلغ كنص أو كعدد كسري (التطبيق يرمي `INVALID_SERVER_RESPONSE` في الحالتين)؟

## 30 — أكواد انتهاء الجلسة

- **الملف والسطر:** `packages/api_layer/lib/core/network/error_mapper.dart:12-17`.
- **ما هو مفترض:** `AUTH_REQUIRED` هو الكود الملاحظ. `SESSION_EXPIRED` و`SESSION_REVOKED` تخمين دفاعي. أي منها ينتج `SessionExpiredException`. على طلب مصادق، استراتيجية الكوكي تُجبر الخروج (`cookie_csrf_auth_strategy.dart:109-110`).
- **الأثر إذا رفض الخادم أو اختلف:** كود انتهاء حقيقي بغير هذه الثلاثة وبغير حالة 401 (انظر البند 32) لا يُخرج المستخدم؛ الطلب يفشل والجلسة تبقى. كود التخمين على حالة ليست 401، إن استُخدم لمعنى آخر، يُخرج المستخدم من الجلسة.
- **البديل المقترح:** معاملة `AUTH_REQUIRED` كخروج إجباري، وإضافة أي كود آخر حرفيًا بعد جواب المالك دون توسيع التخمين.
- **السؤال:** ما أكواد انتهاء الجلسة غير `AUTH_REQUIRED`؟ التطبيق يخمن أيضًا `SESSION_EXPIRED` و`SESSION_REVOKED`. أي كود منها على حالة غير 401 يُجبر تسجيل الخروج.

## 31 — كود خطأ CSRF

- **الملف والسطر:** `packages/api_layer/lib/core/network/error_mapper.dart:20-22`. إعادة المحاولة: `cookie_csrf_auth_strategy.dart:100-107` عبر `GET /api/auth/csrf` مرة واحدة.
- **ما هو مفترض:** الكود الحقيقي غير ظاهر في واجهة الويب. أي كود يحتوي المقطع `CSRF` (مثل `CSRF_INVALID`) يُعدّ خطأ CSRF.
- **الأثر إذا رفض الخادم أو اختلف:** كود بلا المقطع `CSRF` لا يُعاد جلب الرمز من أجله. الطلب يفشل بحالة HTTP (غالبًا 403) ويرى المستخدم «لا تملك صلاحية» أو رسالة الخادم، بلا إعادة محاولة. مقطع `CSRF` داخل كود بمعنى آخر يعيد المحاولة مرة ثم يمرّر الخطأ.
- **البديل المقترح:** الإبقاء على المطابقة بالمقطع إلى أن يصل الكود الحرفي، ثم حصر المطابقة فيه.
- **السؤال:** ما الكود الحرفي لخطأ CSRF؟ التطبيق يعدّ أي كود يحتوي المقطع `CSRF` خطأ CSRF ويعيد جلب `GET /api/auth/csrf` مرة واحدة. كود بلا هذا المقطع لا يُعاد المحاولة عليه.

## 32 — أي 401 آخر يعني انتهاء الجلسة

- **الملف والسطر:** `packages/api_layer/lib/core/network/error_mapper.dart:110-120`.
- **ما هو مفترض:** 401 وكوده يحتوي `CREDENTIALS` أو `LOGIN` يعني بيانات دخول خاطئة. أي 401 آخر يُعامَل انتهاء جلسة لأن جلسة الكوكي بلا تجديد. طلب الدخول نفسه غير مصادق (`authenticated: false`) فلا يُجبر خروجًا، لكن رسالته تتبع هذا التصنيف.
- **الأثر إذا رفض الخادم أو اختلف:** رفض كلمة المرور بكود لا يحتوي `CREDENTIALS` ولا `LOGIN` يظهر للمستخدم كرسالة انتهاء جلسة (افتراضيًا «يجب تسجيل الدخول أولًا.» إن بلا `message`) لا كخطأ كلمة مرور. 401 على طلب مصادق بأي كود آخر يُخرج المستخدم.
- **البديل المقترح:** إبقاء الخروج الإجباري لـ `AUTH_REQUIRED` على الطلبات المصادَقة، وتصنيف شاشة الدخول حسب الكود الحرفي لرفض كلمة المرور بعد جواب المالك.
- **السؤال:** هل كل استجابة 401 ليست خطأ دخول (الكود لا يحتوي `CREDENTIALS` ولا `LOGIN`) تعني انتهاء الجلسة حتى لو اختلف الكود عن `AUTH_REQUIRED`؟ ما كود رفض كلمة المرور الحرفي في `POST /api/auth/login`؟

## 33 — شكل `error.details`

- **الملف والسطر:** `packages/api_layer/lib/core/network/error_mapper.dart:199-210`. يُستخدم مع حالة 422.
- **ما هو مفترض:** `details` كائن على الخادم وشكله غير معروف. التطبيق يقبل أحد ثلاثة: `{ "fields": { "name": "msg" } }`، أو `{ "name": "msg" }` حيث القيمة نص، أو قائمة `[{field, code, message}]`.
- **الأثر إذا رفض الخادم أو اختلف:** شكل آخر (مثل `{errors: [...]}` أو رسالة ليست نصًا) يُسقط أخطاء الحقول. المستخدم يرى `error.message` العامة فقط، والنموذج لا يعلّم الحقل.
- **البديل المقترح:** الإبقاء على الرسالة العامة عند شكل غير معروف، وربط أخطاء الحقول بعد تثبيت شكل واحد.
- **السؤال:** ما شكل `error.details` في أخطاء التحقق؟ التطبيق يقبل `{fields: {name: msg}}` أو خريطة `{name: msg}` أو قائمة `[{field, code, message}]`. شكل آخر يُسقط أخطاء الحقول ويُبقي الرسالة العامة فقط.

---

## قائمة الأسئلة لمالك الخادم

1. هل تبقى مصادقة الجوال على Cookie مع `X-CSRF-Token` عبر `POST /api/auth/login` و`GET /api/auth/csrf` و`POST /api/auth/logout`، أم سيُضاف مخطط Bearer على `POST /api/auth/mobile/login` (يعيد `accessToken` و`refreshToken` و`expiresIn`) و`POST /api/auth/mobile/refresh` مع تدوير و`POST /api/auth/mobile/logout`؟ وهل سيُنتج الخادم لاحقًا `loginTicket` (وحقول `channel` و`maskedDestination`) لخطوة OTP؟
2. هل يرسل `GET /api/me` الحقل `fullAccess` أو الاسم البديل `isSuperuser` كـ boolean؟ إذا أُرسل `false`، هل يجب أن يلغي ذلك صلاحية المدير ذي القائمتين الفارغتين (`permissions` و`sectionAccess`)؟ وما القيم غير `true`/`false` إن وُجدت؟
3. هل توجد خريطة `sectionAccess` داخل `GET /api/me` كما لوحظت على `GET /api/users`؟ وما المفاتيح المؤكدة من بين `customerDebts` و`companyDebts` و`libyanDeposits` و`egyptianDeposits` و`masraweya` و`purchases` و`treasury` و`reports`؟ وهل غياب `collections` من الخريطة مقصود؟
4. ما القيم الحرفية المسموحة لـ `sectionAccess[<key>]`؟ الكود لاحظ `none` و`manage`، و`read` موجود في كود الويب. أي قيمة أخرى تُعامَل كـ `none` فيُخفى القسم. هل توجد قيمة ثالثة يجب أن يفهمها التطبيق؟
5. هل سيُرجع `GET /api/me` الكود `collections.assign` داخل `permissions[]`؟ إن لم يُرجعه، هل يبقى `POST /api/collections/assignments` مسموحًا للمدير الكامل فقط؟
6. هل سيُرجع `GET /api/me` الكود `collections.decide` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى قرارات الاعتماد والرفض والربط (`POST /api/collections/submissions/{id}/decision` و`POST /api/collections/unlinked-receipts/{id}/decision`) ومؤشرات الشاشة للمدير الكامل فقط؟
7. هل سيُرجع `GET /api/me` الكود `collections.cash_receive` داخل `permissions[]`؟ إن لم يُرجعه، هل يبقى `POST /api/collections/submissions/{id}/cash-received` و`POST /api/collections/unlinked-receipts/{id}/cash-received` للمدير الكامل فقط؟
8. هل سيُرجع `GET /api/me` الكود `collections.close_day` داخل `permissions[]`؟ إن لم يُرجعه، هل يبقى `POST /api/collections/days/close` للمدير الكامل فقط؟
9. هل سيُرجع `GET /api/me` الكود `payroll.manage` داخل `permissions[]`؟ إن لم يُرجعه، هل يرى غير المدير «مرتبي» فقط عبر `collections.write`، وتبقى إدارة المرتبات (حركة، راتب أساسي، تأكيد) خارج الجوال؟
10. هل سيُرجع `GET /api/me` الكود `debts.zero_review` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى `POST /api/customers/{id}/zero-review` للمدير الكامل فقط؟
11. هل سيُرجع `GET /api/me` الكود `users.manage` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى قرارات `POST /api/account-requests/{id}/decision` خارج الجوال؟
12. هل سيُرجع `GET /api/me` الكود `settings.manage` داخل `permissions[]`؟ إن لم يُرجعه، هل تبقى شاشة الإعدادات (الموظفون، سجل التدقيق، مركز التشغيل) للصلاحية الكاملة فقط؟
13. هل يرسل الخادم على الاستلام وعلى الاستلام غير المربوط الحقل `cashStatus` بالقيم `pending` أو `received` أو `not_applicable`، أو الحقل `cashPending: true`؟ ما النص الحرفي إن اختلف؟ بدون قيمة تُقرأ كـ `pending` لا يظهر شارة «ينتظر النقد» ولا زر تأكيد استلام النقد.
14. ما شكل JSON الفعلي لـ `GET /api/collections`؟ أكد أو صحّح: مصفوفات `assignments` و`submissions` و`unlinkedReceipts` و`employeeTotals`؛ و`metrics.collectedUnits` و`metrics.dayTotalUnits` (أو `dayTotalUnits` في الجذر) و`assignedCount` (في الجذر أو داخل `metrics`) و`metrics.pendingCount` و`metrics.unlinkedPendingCount` و`metrics.cashOutstandingUnits`؛ و`batchId` أو `batch.id`؛ وأسماء العرض البديلة `customerName`/`name` و`submittedByName`/`employeeName` و`employeeName`/`displayName`. وما قيم `mode` (`full`/`partial`) و`status` (`pending`/`approved`/`rejected`)؟
15. ما القيم الحرفية لحقل `kind` في `POST /api/collections/payroll/entries`؟ النموذج يفترض `withdrawal` و`commission` (`PayrollEntryKind`). هل إدارة المرتبات مطلوبة في الجوال؟
16. هل سيُبنى `GET /api/home`؟ إن نعم، هل الشكل هو `businessDate` و`generatedAt` و`summaries[]` بحقول `key` و`section` و`title` و`valueUnits` و`currency` و`tone` و`note` و`status` و`updatedAt`، و`counters` كخريطة أعداد، و`oldDebts[]` بحقول `id` و`section` و`name` و`balanceUnits` و`currency` و`debtAgeDays` و`ageStatus` و`ageStatusLabel`؟ وما قيم `tone` (`positive`/`negative`/`neutral`) وقيم `status`؟ إن لن يُبنى، هل نعتمد بيانات الأقسام الحالية ونتوقف عن استدعاء `/api/home`؟
17. هل يبقى عدد غير المقروء في الحقل `unreadCount` داخل `GET /api/notifications`، أم سيُضاف `GET /api/notifications/unread-count`؟ وما اسم الحقل إن اختلف عن `unreadCount`؟
18. هل يرسل الإشعار `title` و`body`، أم النص يُبنى في الويب من `action` و`details` فقط؟ ما المفاتيح الفعلية للعنوان والنص و`entityId` (التطبيق يقبل أيضًا `type` و`aggregateId`)؟
19. هل سيُضاف تسجيل جهاز الجوال على `POST /api/mobile-push/devices` (FCM/APNs)، أم يبقى الدفع للويب فقط عبر `/api/browser-push/*` والجوال يكتفي بـ `GET /api/events` و`GET /api/event-changes`؟
20. هل سيُضاف `GET /api/statements/pdf`؟ إن نعم، هل الجسم `{filename, contentBase64}` أم ملف ثنائي؟ وإن لن يُضاف، يبقى الزر مخفيًا خارج وضع Fake.
21. هل يرسل كارت الحساب الحقل `systemKind`، وما قيمه الحرفية؟ وهل يغني عن `systemManaged`؟ التطبيق لا يستنتج `systemKind` من `systemLinkKey` ولا يعرضه اليوم.
22. هل يرسل `GET /api/{section}` الكائن `summary.tabCounts` بالمفاتيح `active` و`today` و`debts` و`paid` و`pinned` و`pendingReview`؟ الواجهة اليوم تعرض العدد من `activeCards` و`pendingReviewCount` فقط.
23. ما عملة `vodafoneConsumedUnits` و`vodafoneRemainingUnits`؟ الثابت `vodafoneCurrencyAssumption` يفترض `EGP`، وشاشة المشتريات تعرض «باقي فودافون» بـ `ج.م`.
24. ما القيم الحرفية لحالة يوم المشتريات `status`؟ النموذج يذكر `draft` و`finalized` و`correction`. الواجهة تعامل أيضًا `open` و`correctionOpen` كيوم قابل للتحرير، وزر الاعتماد يظهر فقط عندما تكون القيمة `draft` بالضبط.
25. ما أسماء مفاتيح إجماليات سجل المشتريات (`lifetimeTotals` أو `totals`)؟ التطبيق يقرأ `resultUnits` و`paidUnits` و`remainingUnits`. أي قيمة ليست عدد JSON صحيح تُفشل استجابة الدفتر كلها (`INVALID_SERVER_RESPONSE`).
26. ما القيم الحرفية لحالة صف التقرير `status`؟ النموذج يذكر `normal` و`needs_review` و`urgent_review` و`rate_missing`. الواجهة تقبل أيضًا `review` و`critical` و`missing_rate` (وتعليق `GET /api/home` يستخدم هذه المجموعة الثانية). أي قيمة أخرى تُخفي شارة الحالة.
27. هل يرسل سبب التقرير الحقل `changeUnits`، وما عملته؟ التطبيق يعرضه كـ `LYD`. وما مفتاح النص إن لم يكن `text` (يقبل أيضًا `message` و`label`)؟
28. هل يرسل `GET /api/treasury` الحقل `activeCashTone` أو `tone` بالقيم `positive` أو `negative` أو `neutral`؟ غياب القيمة أو قيمة غير معروفة يُبقي بطاقة الفلوس النشطة بلون محايد.
29. هل أعداد `*Units` أعداد صحيحة بلا كسور، أي `MONEY_UNIT_SCALE = 0`؟ أم فيها خانات عشرية ثابتة يجب أن يمرّرها التطبيق؟ وهل يرفض الخادم إرسال المبلغ كنص أو كعدد كسري (التطبيق يرمي `INVALID_SERVER_RESPONSE` في الحالتين)؟
30. ما أكواد انتهاء الجلسة غير `AUTH_REQUIRED`؟ التطبيق يخمن أيضًا `SESSION_EXPIRED` و`SESSION_REVOKED`. أي كود منها على حالة غير 401 يُجبر تسجيل الخروج.
31. ما الكود الحرفي لخطأ CSRF؟ التطبيق يعدّ أي كود يحتوي المقطع `CSRF` خطأ CSRF ويعيد جلب `GET /api/auth/csrf` مرة واحدة. كود بلا هذا المقطع لا يُعاد المحاولة عليه.
32. هل كل استجابة 401 ليست خطأ دخول (الكود لا يحتوي `CREDENTIALS` ولا `LOGIN`) تعني انتهاء الجلسة حتى لو اختلف الكود عن `AUTH_REQUIRED`؟ ما كود رفض كلمة المرور الحرفي في `POST /api/auth/login`؟
33. ما شكل `error.details` في أخطاء التحقق؟ التطبيق يقبل `{fields: {name: msg}}` أو خريطة `{name: msg}` أو قائمة `[{field, code, message}]`. شكل آخر يُسقط أخطاء الحقول ويُبقي الرسالة العامة فقط.

## سجل القرار

يُملأ بعد جواب المالك. «مؤكد» يعني أن الخادم يرسل ما افترضه التطبيق. «مرفوض» يعني أن الافتراض يُلغى ويُستخدم البديل. «بديل» هو الاسم أو القيمة أو المسار المعتمد إن اختلف.

| # | البند | القرار (مؤكد / مرفوض / بديل) | البديل المعتمد | التاريخ |
|---|---|---|---|---|
| 01 | مخطط Bearer للجوال | | | |
| 02 | `fullAccess` / `isSuperuser` | | | |
| 03 | `sectionAccess` على `GET /api/me` | | | |
| 04 | قيم `sectionAccess` | | | |
| 05 | `collections.assign` | | | |
| 06 | `collections.decide` | | | |
| 07 | `collections.cash_receive` | | | |
| 08 | `collections.close_day` | | | |
| 09 | `payroll.manage` | | | |
| 10 | `debts.zero_review` | | | |
| 11 | `users.manage` | | | |
| 12 | `settings.manage` | | | |
| 13 | `cashStatus` / `cashPending` | | | |
| 14 | شكل `GET /api/collections` | | | |
| 15 | `PayrollEntryKind` | | | |
| 16 | `GET /api/home` | | | |
| 17 | `unread-count` | | | |
| 18 | `title` / `body` | | | |
| 19 | `mobile-push/devices` | | | |
| 20 | `statements/pdf` | | | |
| 21 | `systemKind` | | | |
| 22 | `tabCounts` | | | |
| 23 | عملة فودافون | | | |
| 24 | حالة يوم المشتريات | | | |
| 25 | مفاتيح `lifetimeTotals` | | | |
| 26 | حالة صف التقرير | | | |
| 27 | `changeUnits` | | | |
| 28 | `activeCashTone` | | | |
| 29 | `MONEY_UNIT_SCALE` | | | |
| 30 | أكواد انتهاء الجلسة | | | |
| 31 | كود CSRF | | | |
| 32 | تصنيف 401 | | | |
| 33 | شكل `error.details` | | | |
