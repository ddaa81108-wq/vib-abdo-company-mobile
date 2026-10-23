# تحليل الفجوة: طبقة API في التطبيق وFake API مقابل عقد الموقع الحقيقي

- **مرجع العقد:** commit الموقع `537f073`، apiVersion `1`، schema `50`. انظر `docs/api/SOURCE.md`.
- **مرجع التطبيق:** `main` على `82a6807`. كل مسار ملف بلا بادئة يقع تحت `packages/api_layer/lib/`. ما يبدأ بـ `lib/` هو كود التطبيق.
- **التحقق على staging:** فحص قراءة فقط على `https://staging.vip2100.com` في 2026-10-23 عند 01:17 بتوقيت طرابلس (UTC+2). التفاصيل في `docs/api/staging-readonly-check.ar.md`، وما يؤكده الفحص موسوم **[staging ✔]**.
- **ما في هذا الـ PR:** وثائق وتحليل فقط. لم يتغير كود الإنتاج.

**مقياس الشدة:**
- **حرج:** يكسر تدفقًا ماليًا أساسيًا، أو يعرض أرقامًا خاطئة أو فارغة على الخادم الحقيقي.
- **عالٍ:** يُفشل كتابة أو يكسر تدفقًا بعينه.
- **متوسط:** سلوك مختلف عن الموقع أو تجربة ناقصة.
- **منخفض:** تنظيف أو توثيق.

---

## 0. أهم الفجوات مرتبة حسب الشدة

| # | الفجوة | الشدة | القسم |
|---|---|---|---|
| G-01 | قرار التحصيل واستلام النقدية (المرتبط وغير المربوط) يشترطان `expectedVersion` من `submission.version`. العقد لا يعيد `version` في هذه الصفوف ولا يقبله في الجسم. `_versioned` يرمي `ArgumentError` قبل الإرسال، فلا يستطيع المدير الاعتماد أو الرفض أو تسجيل استلام النقدية | حرج | §6 |
| G-02 | شكل رد المشتريات مختلف كليًا. الخادم يعيد `day` و`entries` و`registerTotals` و`nextBefore`، والتطبيق يقرأ `days[]` و`lifetimeTotals`/`totals`. النتيجة دفتر فارغ وإجماليات «—» (DEF-034) | حرج | §2 |
| G-03 | تقديم التحصيل بلا exactly-once: الخادم لا يقرأ `requestId` على هذا المسار. ضياع الرد ثم إعادة المحاولة قد يُنشئ تقديمًا ثانيًا (DEF-037 مقترح) | حرج | §7 |
| G-04 | نسخة الخزينة اسمها `cashVersion` والتطبيق يقرأ `version`، فيُرسل `POST /api/treasury/cash-entries` بلا `expectedVersion` المطلوب | عالٍ | §2، §6 |
| G-05 | التثبيت (pin): العقد يطلب `isPinned` + `expectedVersion`، والتطبيق يرسل `pinned`. يتأثر أيضًا الكتابة الاختيارية في `staging_smoke_test.dart` | عالٍ | §2، §6 |
| G-06 | كتابات المشتريات تحتاج نسختين، `expectedVersion` للصف و`expectedDayVersion` لليوم، والتطبيق يرسل حقلًا واحدًا. التصحيح يطلب `expectedVersion` والتطبيق يرسل `expectedDayVersion` | عالٍ | §6 |
| G-07 | تحويل الأخطاء: كل 409 يصبح `ConflictException`. لا معالجة خاصة لـ `CLIENT_VERSION_MISMATCH` أو `DUPLICATE_SAME_WORKDAY` أو `REQUEST_ID_REUSED` أو `PENDING_SUBMISSION_EXISTS` أو `FULL_AMOUNT_CHANGED`. ولا تدفق MFA: `MFA_REQUIRED` يُعرض كأنه «بيانات دخول خاطئة» | عالٍ | §5 |
| G-08 | تجديد CSRF يلغي الرمز السابق. مع كتابات متوازية قد يُلغي تجديدٌ رمزَ طلب آخر جارٍ، فتتسلسل الإخفاقات. العقد يقول صراحة: لا تجدّد بالتوازي مع كتابة | عالٍ | §3 |
| G-15 | بوابة الصلاحيات في الواجهة تشترط `sectionAccess`، و`/api/me` الحقيقي لا يعيده، فيُحجب كل قسم عن الموظف المحدود مع أن الخادم يسمح | عالٍ | §3.3 |
| G-09 | ثلاثة مسارات غير موجودة في الخادم ويُنادى عليها فعلًا: `/api/notifications/unread-count` و`/api/mobile-push/devices` و`/api/admin/employee-totals`، وتعيد كلها 404 **[staging ✔]**. `/api/home` و`/api/statements/pdf` غير موجودين أيضًا | متوسط | §1 |
| G-10 | `checkDuplicate`/`allowDuplicate` لا يُرسلان أبدًا، فلا يظهر تحذير «معاملة مماثلة اليوم» الذي يعرضه الموقع | متوسط | §7 |
| G-11 | شريط الإجمالي يعرض `netBalance` عنوانًا رئيسيًا لكل الأقسام. العقد يقول إن العملاء والشركات يعرضون `totalDebt` والأمانات تعرض `netBalance` | متوسط | §2 |
| G-12 | حقول دفتر المالية: التطبيق يقرأ `section` و`status` و`createdAt`، والخادم يعيد `sectionKey` و`sourceStatus` و`occurredAt` **[staging ✔]**. كائنات التقرير في G-18 | متوسط | §2 |
| G-13 | سقف السداد المحلي (#53) يمنع مبلغًا أكبر من الرصيد. الخادم يقبله وينشئ رصيدًا سالبًا (DEF-031) | متوسط (قرار PM) | §2 |
| G-16 | رواتب التحصيل: العقد يعيد `employeeName`، والتطبيق لا يقرؤه ولا يعرضه. `PayrollEmployeeDto` يقرأ `displayName` أو `name` (`collection_models.dart:268`) فيبقى الاسم فارغًا. المالك UI+API. اختبار QA المتخطى «payroll employeeName is the displayed name» في PR #72 عند `packages/api_layer/test/contract/site_contract_test.dart:262-275` | متوسط | §2 |
| G-17 | إشعار `sectionKey`: لا يُقرأ ولا يُستخدم لتوجيه الإشعار أو تصفيته. `NotificationDto` يقرأ `section` (`notification_models.dart:40`). المالك API+UI. اختبار QA المتخطى «a notification row uses sectionKey» في PR #72 عند `packages/api_layer/test/contract/site_contract_test.dart:302-315` | متوسط | §2 |
| G-18 | التقارير `current` و`daily` و`summary`: لا تُقرأ ولا تُعرض على `main`. جزء api_layer في PR #77 (P-13) وجزء الواجهة في P-14. انظر صف «التقارير» في §2. اختبار QA المتخطى «reports expose current.daily and current.summary» في PR #72 عند `packages/api_layer/test/contract/site_contract_test.dart:332-349` | متوسط | §2 |
| G-14 | `Paged.hasMore` يتجاهل `nextBefore`. الأثر يقتصر على من يقرأ `hasMore`، والتطبيق حاليًا لا يقرؤه | منخفض | §4 |

---

## 1. المسارات والطرق

التطبيق يستخدم `GET /api/me`، وهذا ما يقوله العقد (`README.ar.md` البند 4). **لا يوجد `/api/auth/me` في العقد ولا ينادي عليه التطبيق.** الثوابت في `core/network/api_endpoints.dart`. عمود «من ينادي» مأخوذ من المستودعات تحت `data/repositories/`.

### 1.1 الجلسة والهوية

| الطريقة والمسار في التطبيق | من ينادي | العقد | الفجوة | الشدة |
|---|---|---|---|---|
| `POST /api/auth/login` | `auth_repository.dart:27` | موجود. يعيد `user` و`csrfToken` و`apiVersion` و`expiresAt` **[staging ✔]** | لا فجوة في المسار. التطبيق لا يقرأ `apiVersion` و`expiresAt` | منخفض |
| — | — | `POST /api/auth/mfa/verify` | التطبيق لا يدعم MFA (انظر §5) | عالٍ إن فُعّل MFA للحساب |
| `GET /api/auth/csrf` | `cookie_csrf_auth_strategy.dart:116` | موجود، ويلغي الرمز السابق | انظر §3 | عالٍ |
| `GET /api/me` | `profile_repository.dart:16`، و`lib/notifications/notification_poll_worker.dart:115` | موجود. يعيد `user` و`apiVersion` و`schemaVersion` **[staging ✔]** | لا يُقرأ `schemaVersion` ولا يُقارن | منخفض |
| `POST /api/auth/logout` | `auth_repository.dart:34` | موجود، ويعيد 200 ثم `/api/me` يعيد 401 **[staging ✔]** | لا فجوة | — |
| `POST /api/auth/change-password` | `auth_repository.dart:40` | موجود. الأخطاء `INVALID_CURRENT_PASSWORD` 401 و`PASSWORD_POLICY`/`PASSWORD_UNCHANGED` 400 | 401 هنا يأتي من طلب مصادَق عليه، فيُحوَّل إلى `SessionExpiredException` ويُمسح الجلسة بدل عرض «كلمة المرور الحالية خاطئة» (`error_mapper.dart:129-135`) | عالٍ |
| `/api/auth/mobile/{login,refresh,logout}` | ثوابت فقط، غير مستخدمة | غير موجود. «لا يوجد Bearer/JWT في هذا العقد» (`README.ar.md:27`) | يبقى `AUTH_BEARER` معطّلًا، ويُحذف لاحقًا | منخفض |
| `/api/setup/status`، `/api/health` | ثوابت غير مستخدمة | `/api/health` موجود، و`setup/status` غير موجود | يمكن استخدام health لفحص التوافق قبل الدخول | منخفض |

### 1.2 الحسابات (`{section}` ∈ customers | companies | libyan-deposits | egyptian-deposits)

| الطريقة والمسار | العقد | الفجوة | الشدة |
|---|---|---|---|
| `GET /api/{section}?limit&cursor&q&filter` | موجود بالمعاملات نفسها **[staging ✔]** | لا فجوة في المسار | — |
| `GET /api/{section}/suggestions?q` | موجود | — | — |
| `POST /api/{section}` | موجود: `name` و`phone` و`openingBalance` و`requestId` | لا فجوة | — |
| `GET /api/{section}/{id}` | موجود. الحساب مسطّح في `data` **[staging ✔]**، والتطبيق يرجع إلى `d` عند غياب `account`/`customer` (`accounts_repository.dart:79-84`) | لا فجوة | — |
| `PATCH /api/{section}/{id}` | `expectedVersion` و`name` مطلوبان | التطبيق يرسل `name` اختياريًا (`account_models.dart:349-350`). تعديل الهاتف وحده يفشل بخطأ 400 | متوسط |
| `GET /api/{section}/{id}/ledger?limit&before` | موجود **[staging ✔]** | — | — |
| `POST .../transactions` و`.../corrections` و`.../cancel` | موجودة | انظر §6 و§7 | — |
| `PATCH /api/{section}/{id}/pin` | الجسم `{expectedVersion, isPinned}` | التطبيق يرسل `pinned` (`accounts_repository.dart:133`) | عالٍ |
| `POST /api/customers/{id}/zero-review` | `expectedFinancialVersion` | يطابق (`accounts_repository.dart:138-142`) | — |
| `GET`/`PATCH /api/egyptian-deposits/exchange-rate` | `egpPerLyd`. يُعاد عددًا JSON صحيحًا في العيّنة **[staging ✔]** | يطابق `RateWireFormat.number` | — |

### 1.3 الاستلامات (Collections)

كل المسارات الخمسة عشر في `ApiEndpoints` موجودة في العقد بالطرق نفسها: `GET /api/collections` و`GET .../assignees` و`POST .../assignments` و`POST .../assignments/{id}/submissions` و`POST .../submissions/{id}/decision` و`POST .../submissions/{id}/cash-received` و`POST .../unlinked-receipts` و`GET .../link-candidates` و`POST .../unlinked-receipts/{id}/decision` و`POST .../unlinked-receipts/{id}/cash-received` و`POST .../days/close` و`GET .../payroll` و`POST .../payroll/entries` و`PUT .../payroll/employees/{id}/salary` و`POST .../payroll/entries/{id}/confirm`. الفجوات في الأجسام لا في المسارات، وهي في §6.

### 1.4 المصراوية والمشتريات والخزينة والتقارير

| الطريقة والمسار | العقد | الفجوة | الشدة |
|---|---|---|---|
| `GET`/`PUT /api/masraweya/day` | موجود | — | — |
| `GET`/`POST /api/purchases/{merchant}`، و`PATCH`/`DELETE .../entries/{id}`، و`PATCH .../opening`، و`POST .../finalize`، و`PATCH .../days/{id}/correction` | موجودة كلها | الفجوة في شكل الرد (§2) والنسخ (§6) | — |
| `GET /api/treasury`، `GET .../cash-ledger?before`، `POST .../cash-entries` | موجودة | §2 و§6 | — |
| `GET /api/reports?limit` | موجود. الحد 1–366 والافتراضي 30 | — | — |
| `GET /api/financial-ledger?before&section&currency&q` | موجود | §2 | — |
| `GET /api/statements/pdf` | **غير موجود** | الزر يعمل مع Fake فقط (`api_endpoints.dart`، `lib/ui/widgets/export_pdf_button.dart`). يُخفى في الوضع الحقيقي | متوسط |

### 1.5 الإشعارات والأحداث والإدارة

| الطريقة والمسار | من ينادي | العقد | الفجوة | الشدة |
|---|---|---|---|---|
| `GET /api/notifications?before` | `notifications_repository.dart:47` | موجود: `items` و`unreadCount` و`nextBefore` **[staging ✔]** | — | — |
| `PATCH /api/notifications/{id}/read`، `POST .../read-all` | `notifications_repository.dart:61,73` | موجودان بلا جسم | يطابق | — |
| `GET`/`PATCH /api/notification-preferences` | `notifications_repository.dart:97` | `soundEnabled` و`speechEnabled` مطلوبان | — | — |
| `GET /api/notifications/unread-count` | `lib/state/notification_providers.dart:34,281` | **غير موجود: 404 `ROUTE_NOT_FOUND`** **[staging ✔]** | `build()` في `UnreadNotificationsCountController` يفشل على الخادم الحقيقي. البديل `unreadCount` في رد القائمة | متوسط |
| `POST /api/mobile-push/devices` | `lib/notifications/device_registration_client.dart:20,28` | **غير موجود**. Push في الموقع خاص بالمتصفح ومعزول في staging (`README.ar.md:12`) | التسجيل يفشل بخطأ 404. يُعطّل في الوضع الحقيقي، ويُعتمد على استطلاع WorkManager (#46). لا نطلب API جديدًا | متوسط |
| `GET /api/home` | `home_repository.dart:21` | **غير موجود: 404** **[staging ✔]**. «لا يوجد `/api/home`» (`README.ar.md:55`) | يوجد بديل (`lib/features/home/home_fallback.dart`). يُستحسن عدم النداء أصلًا | منخفض |
| `GET /api/admin/employee-totals` | `employee_totals_repository.dart` عند `standalone` (الافتراضي) | **غير موجود: 404** **[staging ✔]**. البيانات في `GET /api/collections` `employeeTotals` للمدير فقط **[staging ✔]** | يُضبط `EMPLOYEE_TOTALS_SOURCE=collections` أو يُغيَّر الافتراضي | متوسط |
| `GET /api/events` (SSE)، `GET /api/event-changes?after` | `sse_realtime_service.dart`، `polling_realtime_service.dart:53` | موجودان. الرد `events` و`latest` و`fullResync` **[staging ✔]** | يطابق | — |
| ثوابت `/api/settings` و`/api/staff` و`/api/employees` و`/api/admins` و`/api/audit` و`/api/operations` | غير مستخدمة | البدائل في العقد `/api/organization-settings` و`/api/users` و`/api/audit-log` | تُحذف الثوابت أو تُصحَّح | منخفض |

**مسارات في العقد لا يستخدمها التطبيق، وهذا مقبول:** `/api/organization-branding` و`/api/users*` و`/api/account-requests*` و`/api/audit-log` و`/api/organization-settings` و`/api/auth/mfa/verify`.

---

## 2. أسماء الحقول وأشكال الردود

| المورد / الحقل | التطبيق اليوم | العقد (وstaging) | الفجوة | الشدة |
|---|---|---|---|---|
| رصيد الكارت `balanceUnits` | `account_models.dart` يقرأ `balanceUnits` | `balanceUnits` int **[staging ✔]** | يطابق | — |
| ملخص القسم `summary.totalDebt` / `summary.netBalance` | `AccountsSummaryDto` يقرأ `netBalance` ثم `netBalanceUnits`، و`totalDebt` ثم `totalDebtUnits` (`account_models.dart:150-187`) | `summary.{netBalance,totalDebt,activeCards,pendingReviewCount}` كلها int **[staging ✔]**. `totalDebt` مجموع الموجب فقط، و`netBalance` الصافي الموقّع، على كامل القسم (`README.ar.md:51`) | الأسماء تطابق. **العرض:** الشريط يعرض `netBalance` كبيرًا و`totalDebt` صغيرًا (`lib/features/accounts/account_list_screen.dart:605-612`). الموقع يعرض `totalDebt` للعملاء والشركات و`netBalance` للأمانات | متوسط |
| `tabCounts` | مطلوب من الخادم (`account_models.dart:166`) | غير موجود في العقد ولا في staging | التبويبات بلا أعداد. لا يُطلب API جديد | منخفض |
| `totalItems` | يُقرأ من أعلى `data` | int، عدد نتائج الفلتر **[staging ✔]** | يطابق | — |
| كشف الحساب | `items` و`pageOpeningBalanceUnits` و`customer` و`nextCursor` | المفاتيح نفسها **[staging ✔]** | يطابق | — |
| رد كتابة الحركة | `MutationAck` | `transaction` و`customerVersion` و`balanceUnits` و`meta.replayed` (`evidence/api-samples.json` `partial`/`replay`) | `meta.replayed` لا يُقرأ. لا يكسر شيئًا لأن الواجهة تعيد الجلب | منخفض |
| **الخزينة** | `TreasurySummaryDto` يقرأ `data.totals.*`، وإن غاب `totals` يقرأ `data` نفسه، ثم `version` (`treasury_models.dart:36-52`) | مسطّح في `data`: `receivablesUnits` و`liabilitiesUnits` و`activeCashUnits` و`egyptianSourceUnits` و`egyptianConvertedUnits` و`egyptianRate` و`netUnits` و`cashVersion` و`sources.*` و`currency` **[staging ✔]** | القيم تُقرأ بفضل الرجوع إلى `d`. لكن **`version` يصبح `null`** لأن الاسم `cashVersion` (G-04). `sources.*` لا يُقرأ | عالٍ |
| `netUnits` / `egyptianConvertedUnits` | `MoneyValue?`، و`null` يُعرض «—» | `null` عند غياب السعر مع رصيد مصري غير صفري، لا 0 (`README.ar.md:62`) | يطابق (DEF-032 مغلق) | — |
| **المشتريات** | `PurchasesBookPage` يقرأ `days[]`، وفي كل يوم `entries[]` و`totals`، ثم `lifetimeTotals` أو `totals` و`opening` (`purchase_models.dart:184-206`) | `merchant` و`day{...}` و`entries[]` (مسطّحة، وفي كل صف `dayVersion` و`version`) و`nextBefore` (عدد) و`registerTotals{resultUnits,paidUnits,remainingUnits,vodafoneConsumedUnits,vodafoneRemainingUnits}` **[staging ✔]** | **لا تطابق في الشكل.** `days` غير موجود، فالقائمة فارغة. `registerTotals` لا يُقرأ، فالإجماليات «—». نسخة اليوم في `day.version` لا تُقرأ (G-02، DEF-034) | حرج |
| عملة فودافون | `vodafoneCurrencyAssumption = EGP` 🔶 (`purchase_models.dart:15`) | EGP مؤكد (`README.ar.md:60-61`) | الافتراض صحيح. يُزال الوسم | منخفض |
| **الاستلامات** `metrics.collectedUnits` | يُقرأ من `metrics` (`collection_models.dart:205-230`) | `metrics.{collectedUnits,pendingCount,executedCount,cashOutstandingUnits,unlinkedPendingCount}` int **[staging ✔]** | يطابق. `executedCount` لا يُقرأ | — |
| `metrics.dayTotalUnits`، `batchId` | يقرأهما التطبيق | غير موجودين. البديل `openBatches[]{id,businessDate,batchNumber,openedAt}` و`assignedCount` **[staging ✔]** | «إغلاق اليوم» يحتاج `batchId` من `openBatches` | متوسط |
| `submissions[].version`، `unlinkedReceipts[].version` | مطلوبان (`collection_models.dart:87-103,127-140`) | **غير موجودين** **[staging ✔]** | G-01 | حرج |
| `employeeTotals` | يُقرأ `userId` ثم `employeeId` | `employeeId` و`employeeName` و`collectedUnits` و`approvedCount` و`pendingCount`. للمدير فقط **[staging ✔]** | يطابق عند ضبط المصدر على `collections` | — |
| عملة الاستلامات | `Currency.lyd` ثابت (`collection_models.dart:198`) | LYD (`README.ar.md:59`). لا حقل `currency` في الرد **[staging ✔]** | يطابق (DEF-035) | — |
| **دفتر المالية** | `section` و`status` و`createdAt` و`description`، و`scopeTotals` ثم `pageTotals` (`report_models.dart:122-170`) | `sectionKey` و`sourceStatus` و`occurredAt` و`entryKind` و`effectUnits` و`counterpartyName`. `pageTotals.{LYD,EGP}` **إجمالي الصفحة فقط** **[staging ✔]** | القسم والحالة والتاريخ فارغة. يجب أن تقول التسمية «إجمالي الصفحة» | متوسط |
| **التقارير** | `items` ثم `rows`، و`egyptianUnits` و`netChangeUnits` و`note`/`systemNote` (`report_models.dart:40-120`) | `current` و`items[]{...,daily,reasons,fiveAmClosing,summary}` و`methodology` **[staging ✔]** | **G-18:** `current` و`daily` و`summary` لا تُقرأ على `main`. جزء api_layer في PR #77 (P-13) والعرض في P-14. `netChangeUnits` غير موجود | متوسط |
| الإشعار | `items` و`unreadCount` و`nextBefore` | يطابق **[staging ✔]**. `details` كائن حر وقد يحمل `amountUnits` و`subjectName` | لا تُعرض مبالغ ولا أسماء في الإشعار المحلي (قاعدة الأمان) | منخفض |
| `/api/me` | `role` و`permissions` و`sectionAccess` و`mustChangePassword` (`profile_models.dart`) | `user.{id,username,displayName,role,isOwner,permissions,mustChangePassword}`. **`sectionAccess` غير موجود في `/api/me`** **[staging ✔]**. `role=admin` يتجاوز القائمة، و`permissions` للمدير `[]` | انظر §3.3 | عالٍ |
| سعر الصرف | `DecimalString` | `egpPerLyd` عدد JSON، و`factorMicros` في الكشف | يطابق | — |
| سداد يتجاوز الرصيد | الحوار يرفض المبلغ الأكبر من الرصيد المخزَّن (`lib/features/accounts/ledger_screen.dart:431-443`، #53) | الخادم **لا يرفض** وينشئ رصيدًا سالبًا. لا كود `OVERPAYMENT` (`README.ar.md:66`) | سلوك مختلف عن الموقع (DEF-031) | متوسط |

---

## 3. المصادقة والجلسة وCSRF

### 3.1 الكوكي والرؤوس

| البند | التطبيق اليوم | العقد / staging | الفجوة | الشدة |
|---|---|---|---|---|
| كوكي الجلسة | `SecureCookieStore` على `FlutterSecureStorage` مع `encryptedSharedPreferences` (`core/auth/cookie_store.dart:34-44`). يُرسل `Cookie` يدويًا | `abdo_session`: HttpOnly وSecure وSameSite=Strict وPath=/ وExpires (12 ساعة) **[staging ✔]** | يطابق. التطبيق ليس متصفحًا وSameSite لا يؤثر | — |
| كوكي `abdo_mfa` | لا معالجة خاصة | يظهر في رد الدخول الناجح بـ `Max-Age`، وغالبًا لمسحه. SameSite=Lax **[staging ✔]** | يجب أن يحذف المخزن الكوكي عند `Max-Age=0` أو تاريخ انتهاء ماضٍ (يُتحقق منه في اختبار) | منخفض |
| `X-CSRF-Token` | على كل طلب غير GET/HEAD، والرمز في الذاكرة فقط (`cookie_csrf_auth_strategy.dart:54-64`) | كل POST/PUT/PATCH/DELETE مصادَق عليه (`README.ar.md:28`) | يطابق | — |
| `X-Client-Api-Version: 1` | في `BaseOptions` لكل طلب (`core/network/dio_api_client.dart:44`)، وفي العامل الخلفي | مطلوب على الكتابات. `GET /api/me` بلا الرأس أعاد 200، فالقراءة لا تفحصه **[staging ✔]**. الخطأ `409 CLIENT_VERSION_MISMATCH` مع `details.requiredApiVersion` | يطابق. لكن `CLIENT_VERSION_MISMATCH` يُعامل كتعارض بيانات (§5) | عالٍ |
| `Origin` | لا يُرسل | لا تضف Origin مصطنعًا، وإلا `400 ORIGIN_MISMATCH` (`README.ar.md:37`) | يطابق | — |
| User-Agent | الافتراضي `Dart/x (dart:io)` | Cloudflare على staging يحجب `Python-urllib` بخطأ 403 ويقبل `Dart/3.13 (dart:io)` و`okhttp` **[staging ✔]** | لا فجوة للتطبيق. ملاحظة لأدوات CI: لا تُستخدم UA مكتبات Python الافتراضية | منخفض |
| `API_BASE` | يجب أن يكون أصلًا فقط (`api_config.dart` `requireRealBaseUrl`) | الواجهة على `/erp`، والـ API على الأصل `/api` (`README.ar.md:8,11`). `.../erp/api/health` يعيد HTML **[staging ✔]** | يجب أن يكون السر `STAGING_API_BASE=https://staging.vip2100.com` بلا `/erp` | متوسط (إعداد) |

### 3.2 401 و419 وتجديد CSRF

| البند | التطبيق اليوم | العقد | الفجوة | الشدة |
|---|---|---|---|---|
| انتهاء الجلسة | كل 401 مصادَق عليه، وكل 419 غير CSRF، يمسحان الجلسة مرة واحدة (single-flight `_wipeInFlight`، `core/session/session_manager.dart:146-176`، `error_mapper.dart:124-135`) | `401 AUTH_REQUIRED`. **لا يوجد 419 في الكتالوج** (`error-catalog.json`) | المنطق آمن، وفرع 419 دفاعي فقط. **استثناء:** `401 INVALID_CURRENT_PASSWORD` على تغيير كلمة المرور يمسح الجلسة خطأً | عالٍ |
| خطأ CSRF | أي كود يحوي «CSRF» يصبح `CsrfInvalidException` (`error_mapper.dart:29,106`)، ثم تجديد مرة واحدة single-flight، ثم إعادة الطلب مرة واحدة (`cookie_csrf_auth_strategy.dart:100-111`، `auth_interceptor.dart:76-91`) | `403 CSRF_REJECTED` (`evidence/api-samples.json` `csrfError`) | الكود يُلتقط صحيحًا | — |
| **تجديد يلغي الرمز السابق** | التجديد single-flight، لكن الكتابات غير مُسلسلة. السيناريو: الطلبان A وB يرسلان بالرمز T1، ثم A يفشل، ثم التجديد يصدر T2 ويلغي T1، ثم B (بـ T1) يفشل، ثم تجديد ثانٍ يصدر T3 ويلغي T2 الذي يستخدمه replay A. كل طلب لا يُعاد إلا مرة، فقد يفشل الاثنان | «يلغي الرمز السابق لنفس الجلسة. لا تنفذه بالتوازي مع كتابة» (`README.ar.md:29`) | يلزم تسلسل الكتابات (طابور واحد للطرق غير الآمنة)، والتجديد فقط حين لا تكون كتابة جارية. ويُعاد الطلب برمز أحدث إن تغيّر أثناء انتظاره | عالٍ |
| الاستئناف البارد | `onSessionResumed` يجدد CSRF (`cookie_csrf_auth_strategy.dart:89-91`) | الموقع يجلبه عند bootstrap | يطابق. العامل الخلفي يرسل GET فقط، فلا يتأثر | — |
| جلسة لكل تثبيت | جلسة لكل تثبيت | «لا تشارك كوكي جلسة بين الموقع والتطبيق أو أجهزة متعددة» | يطابق | — |
| `mustChangePassword` | الموجِّه يعرض شاشة التغيير (`lib/authentication/auth_gate.dart:32`) | بقية النظام يعيد `403 PASSWORD_CHANGE_REQUIRED` | يطابق في المسار الرئيسي. 403 بهذا الكود يجب أن يعيد إلى شاشة التغيير | منخفض |
| MFA | غير مدعوم | الدخول يعيد `401 MFA_REQUIRED` ويضع `abdo_mfa` لخمس دقائق، ثم `POST /api/auth/mfa/verify {code}` | 401 على الدخول يصبح `InvalidCredentialsException` (`error_mapper.dart:116-123`)، فيرى المستخدم «بيانات الدخول غير صحيحة». الحسابات الثلاثة في staging لا تطلب MFA **[staging ✔]** | عالٍ إن فُعّل MFA للمدير |
| حد الدخول | `RateLimitedException` مع `Retry-After` (`error_mapper.dart:212-222`) | 8 محاولات لكل حساب و40 لكل عنوان خلال 15 دقيقة. `429 LOGIN_RATE_LIMITED`/`LOGIN_BUSY` (`Retry-After: 2`) | يطابق. لا إعادة دخول آلية | — |

### 3.3 الصلاحيات

| البند | التطبيق اليوم | العقد / staging | الفجوة | الشدة |
|---|---|---|---|---|
| مصدر الصلاحية | `permissions[]` و`sectionAccess` من `/api/me` (`profile_models.dart:3-43`). للموظف، القراءة تشترط `<section>.read` **و** `sectionAccess != none`، والمدخل الغائب يُعدّ `none` (`core/permissions/permission_service.dart:16-22`). المدير الذي قائمتاه فارغتان غير مقيّد | `/api/me` يعيد `permissions[]` فقط بلا `sectionAccess`. المدير `permissions=[]` و`role=admin` يتجاوز. الحكم النهائي للخادم في كل طلب (`README.ar.md:30`) **[staging ✔]** | **المدير سليم. الموظف (المحدود والمحصّل) لن يرى أي قسم حسابات أو مشتريات أو خزينة في الواجهة**، لأن `sectionAccess` غائب فيُعدّ `none`، مع أن الخادم يعيد 200 للمحدود على كل هذه الأقسام **[staging ✔]**. يجب أن يكفي رمز الصلاحية عند غياب `sectionAccess` | عالٍ |
| رموز الصلاحيات | `core/permissions/permission_codes.dart` | المرصود على staging: `debts.read` و`companies.read` و`libyan_deposits.read` و`egyptian_deposits.read` و`purchases.read` و`treasury.read` و`reports.read` و`collections.read` و`collections.write`. الكتالوج يذكر أيضًا `events.read` و`notifications.read` و`collections.review` | تُراجَع خريطة الرموز مقابل هذه الأسماء | متوسط |
| 403 | `ForbiddenException`. لا يُحوَّل إلى صفر | `403 PERMISSION_DENIED` مع `details.permission` **[staging ✔]** | يطابق. «لا تحوّل 403 إلى صفر» (`README.ar.md:55`) | — |

---

## 4. الترقيم

| المورد | التطبيق اليوم | العقد (`README.ar.md:92-99`) | الفجوة | الشدة |
|---|---|---|---|---|
| قوائم الحسابات | `limit=100&cursor` من `nextCursor` (`accounts_repository.dart:53-57`) | `limit` بين 20 و200 والافتراضي 100، و`cursor` معتم من `nextCursor` **[staging ✔: `nextCursor` null/string]** | يطابق | — |
| كشف الحساب | `limit&before` حيث `before` = `Paged.nextCursor` (`common.dart:107`) | `before` من `nextCursor` «رغم الاسم» | يطابق | — |
| المشتريات | `limit&before` | `before` من `nextBefore` **العددي**، والصفوف صاعدة | `strOrNull` يحوّل العدد إلى نص فيعمل، لكن `itemsKey: 'days'` خطأ (G-02) | حرج (بسبب الشكل) |
| الخزينة / الإشعارات / التدقيق | `before` | `before` من `nextBefore`، حتى 100 صف **[staging ✔]** | الإشعارات تقرأ `nextBefore` (`notification_models.dart:77`). الخزينة تمر عبر `Paged`: المؤشر يعمل، لكن `hasMore` يتجاهل `nextBefore` (`common.dart:108`) | منخفض |
| الاستلامات | لقطة كاملة | بلا page/cursor | يطابق | — |
| التقارير | `limit=30` | `limit` بين 1 و366، بلا cursor | يطابق | — |
| الأحداث | `after=N` ثم `latest` | `after` و`latest` و`fullResync` **[staging ✔]** | يطابق | — |
| ملاحظة | — | «لا تعوّل على pagination لبناء أرصدة» | التطبيق لا يجمع الصفحات | — |

---

## 5. كتالوج الأخطاء مقابل تحويل التطبيق

الغلاف `{ok:false, error:{code,message,details?,correlationId}}` يطابق `ErrorMapper.fromResponse`. الكتالوج فيه 161 كودًا مميزًا (`error-catalog.json`).

| الكود / الحالة | التطبيق اليوم (`error_mapper.dart`) | العقد | الفجوة | الشدة |
|---|---|---|---|---|
| `AUTH_REQUIRED` 401 | `SessionExpiredException`، ثم إنهاء الجلسة | 401 | يطابق | — |
| `INVALID_CREDENTIALS` 401 على الدخول | `InvalidCredentialsException` | 401 | يطابق | — |
| `MFA_REQUIRED` 401، `MFA_INVALID` 400/401/403 | تصبح «بيانات خاطئة»، أو تنهي الجلسة | تدفق MFA | لا دعم | عالٍ (شرطي) |
| `INVALID_CURRENT_PASSWORD` 401 | `SessionExpiredException`، فتُمسح الجلسة | خطأ إدخال | خطأ في التحويل | عالٍ |
| `CSRF_REJECTED` 403 | `CsrfInvalidException`، ثم تجديد وإعادة مرة | 403 | يطابق (انظر §3.2) | — |
| `PERMISSION_DENIED` 403 | `ForbiddenException` | 403 مع `details.permission` | يطابق | — |
| `PASSWORD_CHANGE_REQUIRED` 403 | `ForbiddenException` عام | يجب التوجيه لشاشة التغيير | معالجة ناقصة | منخفض |
| `CLIENT_VERSION_MISMATCH` 409 | `ConflictException`، وتعرض الواجهة «تغيرت البيانات» | «احتفظ بالمسودة ثم حدّث الواجهة»، مع `requiredApiVersion` | نوع خاطئ. يجب أن يكون «تحديث التطبيق مطلوب» مع حفظ المسودة | عالٍ |
| `VERSION_CONFLICT` 409 | `ConflictException`، ثم إعادة جلب (`lib/ui/widgets/mutation_form.dart`) | مع `details.expectedVersion/currentVersion` | يطابق | — |
| `REQUEST_ID_REUSED` 409، `LEGACY_REQUEST_REVIEW_REQUIRED` 409 | `ConflictException` عام | معرّف استُخدم لمحتوى مختلف | يجب ألا يُعاد بالمعرّف نفسه. تُعرض رسالة الخادم ويُولَّد معرّف جديد بقرار المستخدم | متوسط |
| `DUPLICATE_SAME_WORKDAY` 409 | لا يحدث، لأن التطبيق لا يرسل `checkDuplicate` | تحذير، ثم إعادة **الطلب نفسه والمعرّف نفسه** مع `allowDuplicate:true` | ميزة ناقصة (§7) | متوسط |
| `PENDING_SUBMISSION_EXISTS`، `FULL_AMOUNT_CHANGED`، `NO_POSITIVE_DEBT`، `SUBMISSION_ALREADY_DECIDED`، `ASSIGNMENT_CLOSED` 409 | `ConflictException` عام | لكل منها معنى في التحصيل | تُعرض رسالة الخادم وتُعاد قراءة الاستلامات. لا يُعامل كتعارض نسخة | متوسط |
| `FULL_PAYMENT_NOT_ALLOWED` 400، `INVALID_AMOUNT` 400 مع `details.field` | `BadRequestException`، أو `ValidationException` إن وُجدت حقول | `details: {field: "inputValue"}` | `_fieldErrors` يقرأ `{field: "inputValue"}` على أنه حقل اسمه `field` ورسالته `inputValue` (`error_mapper.dart:257-280`) | منخفض |
| `EXPECTED_VERSION_REQUIRED`، `REQUEST_ID_REQUIRED` 400 | `BadRequestException` | 400 | ستظهر فعليًا بسبب G-04 وG-06 | — (عَرَض) |
| `ROUTE_NOT_FOUND` 404 | `NotFoundException` | 404 | يظهر في المسارات المقترحة (§1.5) | — |
| `LOGIN_RATE_LIMITED`، `LOGIN_BUSY` 429 | `RateLimitedException` + `Retry-After` | 429 | يطابق | — |
| `EVENT_STREAM_LIMIT` 429 | `RateLimitedException`. SSE ثم الاستطلاع | 429 | يطابق مبدئيًا. يجب أن يرجع SSE إلى الاستطلاع بلا حلقة | منخفض |
| `ORIGIN_MISMATCH`، `CONTENT_TYPE_REQUIRED`، `INVALID_JSON` 400 | `BadRequestException` | 400 | لا تحدث مع Dio وJSON | — |
| `REQUEST_BODY_TOO_LARGE` 413 | `UnknownApiException` | 413، والحد 1MiB | منخفض | منخفض |
| 419، 422، 423، 426 | لها فروع | **غير موجودة في الكتالوج** | فروع دفاعية، وتبقى | — |

---

## 6. `requestId` و`expectedVersion` لكل مسار كتابة

`MutationMeta.toBody` يرسل دائمًا `requestId` (UUID v4 بطول 36 حرفًا)، ومعه `expectedVersion` إن وُجد، باسم يمكن تغييره (`core/network/idempotency.dart:14-27`). المرجع: جسم الطلب في `openapi.json` و`README.ar.md:74-82`.

| المسار | العقد: المعرّف | العقد: النسخة | التطبيق يرسل | الفجوة | الشدة |
|---|---|---|---|---|---|
| `POST /api/{section}` | `requestId` مطلوب (8–128) مع بصمة | — | `requestId` | يطابق | — |
| `PATCH /api/{section}/{id}` | — | `expectedVersion` مطلوب | `requestId` (زائد) + `expectedVersion` | حقل زائد. سلوك الخادم مع الحقول الزائدة غير موثق (لا `additionalProperties` في العقد) | منخفض (يُؤكَّد) |
| `PATCH .../pin` | — | `expectedVersion` + `isPinned` | `requestId` + `expectedVersion` + `pinned` | اسم الحقل خطأ (G-05) | عالٍ |
| `POST .../transactions` و`.../corrections` | `requestId` مطلوب (8–128) مع بصمة. `meta.replayed` | `expectedVersion` مطلوب | الاثنان | يطابق. يُعاد المعرّف فقط مع الحمولة نفسها (`SubmissionLock`) | — |
| `POST .../cancel` | `requestId` | `expectedVersion` | الاثنان | يطابق | — |
| `POST /api/customers/{id}/zero-review` | — | `expectedFinancialVersion` | الاثنان (`requestId` زائد) | يطابق | — |
| `PATCH /api/egyptian-deposits/exchange-rate` | — | — | `requestId` زائد | يُؤكَّد | منخفض |
| `POST /api/collections/assignments` | — | — | `requestId` زائد | يُؤكَّد | منخفض |
| **`POST .../assignments/{id}/submissions`** | **لا يقرأ `requestId`** | **لا** | `requestId` يُهمل | **لا exactly-once** (G-03، §7) | حرج |
| **`POST .../submissions/{id}/decision`** | — | **لا**. الحماية بشرط `pending` ذري، ثم `SUBMISSION_ALREADY_DECIDED` | `_versioned` **يشترط** `expectedVersion`، والصف لا يحمل `version`، فيُرمى `ArgumentError` (`collections_repository.dart:71-77`) | لا يُرسل الطلب أصلًا (G-01) | حرج |
| **`POST .../submissions/{id}/cash-received`** | — | **لا**، وبلا جسم | مثل الصف السابق | G-01 | حرج |
| **`POST .../unlinked-receipts/{id}/decision`** و**`.../cash-received`** | — | **لا** | مثل الصف السابق | G-01 | حرج |
| `POST /api/collections/unlinked-receipts` | `requestId` مطلوب، **بلا بصمة** | — | `requestId` | يطابق، مع خطر: إعادة استخدام المعرّف بمبلغ مختلف تعيد الاستلام القديم. يجب تخزين المعرّف مع الحمولة. `SubmissionLock` يغيّر المعرّف إن تغيّرت المدخلات | متوسط |
| `POST /api/collections/days/close` | — | — | `requestId` زائد + `batchId` + `confirmed` | `batchId` يأتي من `openBatches[].id` | متوسط |
| `POST .../payroll/entries` | `requestId` مطلوب (`IDEMPOTENCY_KEY_REUSED`) | — | `requestId` | يطابق | — |
| `PUT .../payroll/employees/{id}/salary`، `POST .../entries/{id}/confirm` | — | — | `requestId` زائد | يُؤكَّد | منخفض |
| `PUT /api/masraweya/day` | — (لا تستخدم `requestId` الديون) | `expectedVersion` مطلوب، ونفس المحتوى يعيد `replayed:true` | `requestId` زائد + `expectedVersion` | يُؤكَّد أن الحقل الزائد لا يُرفض | منخفض |
| `POST /api/purchases/{m}` | `requestId` (8–120، `[A-Za-z0-9_-]`) | `expectedDayVersion` | الاثنان | يطابق. UUID ضمن الحروف المسموحة. لكن `day.version` لا يُقرأ (G-02) | عالٍ (بسبب G-02) |
| `PATCH /api/purchases/{m}/entries/{id}` | `requestId` | `expectedDayVersion` **و** `expectedVersion` (للصف) | `expectedDayVersion` فقط | نقص `expectedVersion` (G-06) | عالٍ |
| `DELETE /api/purchases/{m}/entries/{id}` | `requestId` | `expectedVersion` **و** `expectedDayVersion` | `expectedDayVersion` فقط | G-06 | عالٍ |
| `PATCH .../opening` | — | `expectedDayVersion` | الاثنان (`requestId` زائد) | يطابق | — |
| `POST .../finalize` | `requestId` | `expectedDayVersion` | الاثنان | يطابق | — |
| `PATCH .../days/{id}/correction` | — | **`expectedVersion`** + `open` | `expectedDayVersion` + `open` | اسم خطأ (G-06) | عالٍ |
| `POST /api/treasury/cash-entries` | `requestId` (8–100، `[A-Za-z0-9._:-]`) | `expectedVersion` من **`cashVersion`** | `requestId` + `expectedVersion` = `null`، فلا يُرسل | G-04: `400 EXPECTED_VERSION_REQUIRED` متوقع | عالٍ |
| `PATCH /api/notifications/{id}/read`، `POST .../read-all` | — | — | لا جسم | يطابق | — |

---

## 7. منع التكرار: `checkDuplicate` و`allowDuplicate` وexactly-once

| البند | التطبيق اليوم | العقد | الفجوة | الشدة |
|---|---|---|---|---|
| `checkDuplicate:true` على الإنشاءات المدعومة | **لا يُرسل في أي مسار** (لا ظهور في `lib/` ولا `packages/api_layer/lib/` خارج Fake) | مدعوم على: الحركات والتصحيحات (الأقسام الأربعة)، وتقديم التحصيل، والاستلام غير المربوط، وقيود الرواتب، والمشتريات، والخزينة، والمصراوية (`openapi.json`) | لا تحذير تكرار | متوسط |
| `409 DUPLICATE_SAME_WORKDAY` ثم التأكيد | لا معالجة | حوار بسيط. عند التأكيد تُعاد **الحمولة نفسها والمعرّف نفسه** مع `allowDuplicate:true`. لا تجعله `true` تلقائيًا (`README.ar.md:84`) | يحتاج دعمًا في `MutationMeta`/`SubmissionLock` وحوارًا في الواجهة | متوسط |
| إعادة المحاولة بعد timeout | الكتابات لا تُعاد آليًا. `GetRetryInterceptor` يعيد GET/HEAD فقط. الإعادة اليدوية تحتفظ بالمعرّف للمدخلات نفسها | «عند timeout مالي احتفظ بنفس الحمولة والمفتاح، وافحص الاستعلام أولًا» (`README.ar.md:86`) | يطابق في مسارات البصمة. ينقص «افحص الاستعلام أولًا» قبل الإعادة | متوسط |
| **تقديم التحصيل** | يرسل `requestId` ويعتقد أن الإعادة آمنة | **«لا يقرأ requestId أو expectedVersion. لا توجد exactly-once للتقديم بعد ضياع الرد ثم اعتماد الطلب السابق. لا تعاود POST آليًا عند timeout؛ أعد GET وافحص الحالة»** (`README.ar.md:79`). «لا تعتمد التطبيق ماليًا قبل حسم فجوة exactly-once لمسار تقديم التحصيل» (`README.ar.md:86`) | **G-03.** التفصيل في `defect-decisions.ar.md` (DEF-037 مقترح) | حرج |

---

## 8. وحدة المال

| البند | التطبيق اليوم | العقد | الفجوة | الشدة |
|---|---|---|---|---|
| مقياس `*Units` | `ApiConfig.moneyUnitScale` افتراضه 0 وموسوم 🔶 (`core/config/api_config.dart:56,73-75`) | **وحدات عملة كاملة، لا ×100 ولا ×1000.** «250 يعني 250 دينارًا» (`README.ar.md:45`). `openapi.json` `Transaction.inputValue`: «Whole currency units, not minor units» | **الافتراض 0 صحيح.** يُزال الوسم ويُغلق P0-04 بهذا الدليل. لا يُغيَّر الكود | منخفض |
| نوع القيم | `precise_json` + `unitsOrNull`: int فقط، وأي قيمة أخرى `MoneyValue.invalid` (#62) | أعداد صحيحة آمنة، والرصيد قد يكون سالبًا. السعر وحده حتى 6 منازل، و`factorMicros` بالمليونيات وليس مبلغًا | يطابق. **[staging ✔]** كل حقول المال المفحوصة int: 149 للمدير و111 للمحدود و13 للمحصّل، صفر غير int | — |
| التقريب | لا تقريب في العميل. الخادم يحسب | الحسابات تقطع للأسفل، والمشتريات نصف لأعلى، وتحويل الأمانات متناظر. «استعمل نتيجة الخادم» (`README.ar.md:47`) | يطابق | — |
| الإدخال | يرفض `.` و`٫`، ويقبل فواصل الآلاف الصحيحة (`lib/ui/widgets/common.dart:429-444`) | «لا ترسل `1.000` بمعنى ألف؛ أرسل `1000`» | يطابق | — |
| فاصل العرض | `,` للآلاف (`money_formatter.dart`) | لقطات الموقع تعرض `1.000` في الكروت و`5,160` في الخزينة والمشتريات (`evidence/01-*.png`، `09-*.png`) | اختلاف عرض فقط. يُقرر من الواجهة | منخفض |
| جمع العملات | لا جمع LYD مع EGP | «لا تجمع LYD وEGP مباشرة» | يطابق | — |

---

## 9. Fake API مقابل العقد

`data/fake/fake_api_client.dart` و`fake_fixtures.dart` يُستخدمان في الاختبارات وحدها. القاعدة: **يُزيَّف النقل/الخادم فقط**. الفجوات أدناه تعني أن الاختبارات الخضراء اليوم لا تثبت التوافق مع الخادم الحقيقي.

| السلوك | Fake اليوم | العقد | الإجراء |
|---|---|---|---|
| ملخص القسم بعد حركة | يضيف الفرق إلى `netBalance` **و** `totalDebt` معًا (`fake_api_client.dart:1490-1513`) | `totalDebt` مجموع الأرصدة الموجبة فقط | تصحيح الـ Fake (DEF-028) |
| السداد الأكبر من الرصيد | `400 VALIDATION_ERROR` مؤقت (`docs/acceptance/defects.md`) | مقبول، والرصيد يصبح سالبًا | تصحيح الـ Fake |
| شكل المشتريات | `days[]` و`lifetimeTotals` | `day` و`entries` و`registerTotals` و`nextBefore` | تحويل الـ Fake إلى شكل العقد مع المحلّل (G-02) |
| الخزينة | `totals{...}` و`version` | مسطّح و`cashVersion` | كذلك (G-04) |
| `version` في التقديمات | موجود | غير موجود | كذلك (G-01) |
| `checkDuplicate` و`DUPLICATE_SAME_WORKDAY` و`CSRF_REJECTED` و`CLIENT_VERSION_MISMATCH` | غير محاكاة أو بأسماء أخرى | في الكتالوج | إضافة سيناريوهات |
| المسارات المقترحة (`/api/home` و`unread-count` و`mobile-push` و`admin/employee-totals` و`statements/pdf`) | تعيد 200 | 404 | الـ Fake يعيد 404 في وضع «عقد صارم»، أو يُحذف النداء |

**الأساس المقترح:** `docs/api/evidence/api-samples.json` يصبح fixtures لاختبار عقد (contract test) يحلل كل رد بالـ DTO الحقيقي. هذا لا يُزيّف المتحكم، فقط بيانات النقل.
