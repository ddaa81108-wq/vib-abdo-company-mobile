# المرحلة 7 — تنفيذ الاختبار

**الدور:** قائد الاختبار. هذه خطة تنفيذ ومصفوفة تتبع. ليست توقيع قبول.

**الأساس:** `main` عند `a5ca26809578dd013430dcaae78c517043e95491`. الفرع يضيف هذه الوثيقة فقط. لا تغيير لكود الإنتاج. لم يُمس فرع #12.

**معرّفات القبول السابقة** (`P0`–`P6`) موثّقة على [#12](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/12) في `docs/acceptance/phase-0.md` … `phase-6.md`. سجل العيوب هناك أيضًا: [`defects.md`](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/blob/cursor/acceptance-docs-13b0/docs/acceptance/defects.md). عند كتابة الخطة كان التالي الحر DEF-020. بعد مراجعة #51 كان التالي الحر DEF-023. بعد مراجعة #49 التالي الحر DEF-026. بعد تأكيد `main` `2a45cfb` فُتح DEF-026 وصار التالي الحر **DEF-027**.

**المالكون:** مهندس API = 1 و2 و3 و11 و12 و13. Senior Flutter = 4 و5 و6 و7 و8 و9. مطور الواجهة = 10 و14 و15 و16. DevOps = 17 و18 و19 (البند 19 تجهيز تشغيل الهاتف الحقيقي).

**قاعدة منع الاستبدال (درس DEF-018):** الاختبار الذي يستبدل `deviceTokenRegistrarProvider` أو `notificationOpenSeamProvider` أو `homeDashboardProvider` أو متحكّم الشاشة لا يُغلق البند. المسار الناجح يمر على المزوّد الجذر أو `buildAppRoot` أو المسجّل أو المتحكّم الحقيقي. يُسمح بتزييف النقل أو الخادم فقط (`FakeApiClient`، `FakePushTransport`، محوّل HTTP). جلسة مبنية يدويًا مسموحة لاختبار وحدة منعزل، وممنوعة حين يكون الادعاء «الدور أو الإذن أو النقر كما يراه المستخدم».

استُخرجت أسماء `test` / `testWidgets` / `group` من `test/` و`packages/api_layer/test/` و`integration_test/` على هذا الالتزام: **508**.

## ملخص الحالة

| الحالة | العدد | البنود |
|---|---|---|
| Covered | 3 | 4، 14، 15 |
| Partial | 15 | 1، 2، 3، 5، 6، 7، 8، 9، 10، 11، 12، 13، 16، 17، 18 |
| Missing | 0 | — |
| Device-only | 1 | 19 |
| Staging-only | 0 | — |

| المالك | البنود | Covered | Partial | Device-only |
|---|---|---|---|---|
| مهندس API | 6 | 0 | 6 | 0 |
| Senior Flutter | 6 | 1 | 5 | 0 |
| مطور الواجهة | 4 | 2 | 2 | 0 |
| DevOps | 3 | 0 | 2 | 1 |

لقطة الأساس على `a5ca268` كانت Partial ‏15 وDevice-only ‏2 (البندان 17 و19). مراجعة #52 تنقل البند 17 إلى Partial. مراجعة #51 تنقل البند 4 إلى Covered. إعادة اختبار #52 على `f8f7812` لا تغيّر الأعداد. مراجعة #49 و#50 وملحق #49 لا تغيّر الأعداد. إعادة اختبار #51 على `e34504c` لا تغيّر الأعداد. مراجعة #56 على `9c0fa4f` لا تغيّر الأعداد: Covered ‏3 وPartial ‏15 وDevice-only ‏1. مراجعة #53 و#54 و#55 لا تغيّر الأعداد. مراجعة #57 على `714c6ea` لا تغيّر الأعداد. إعادة اختبار #52 على `f347a8a` بعد دمج `main` `c40e03d` لا تغيّر الأعداد. إعادة اختبار #51 على `721edef` لا تغيّر الأعداد. DEF-019 وDEF-020 وDEF-021 وDEF-022 صارت Verified closed على `main` `c40e03d`. تأكيد `main` `2a45cfb` (squash #52 ثم #57 ثم #51) وإعادة اختبار #49 على `653a07c` لا يغيّران الأعداد. DEF-023 وDEF-024 وDEF-025 صارت Verified closed على `2a45cfb`. فُتح DEF-026 وغير مانع. مراجعة #58 على `6e7a76c` لا تغيّر الأعداد. فُتح DEF-027 وغير مانع. البند 17 يبقى Partial. البند 18 يبقى Partial. البند 10 يبقى Partial لنصف الجهاز. البند 14 يبقى Covered. البند 15 يبقى Covered. البند 16 يبقى Partial لنصف الجهاز. البند 7 يبقى Partial لأن P7-11 staging. البند 9 يبقى Partial لأن P7-15 staging. البند 19 يبقى Device-only. التالي الحر DEF-028. لا توقيع.

أكبر الفجوات لكل مالك في نهاية القسم أ.

---

## أ. مصفوفة التتبع

صف واحد لكل بند من بنود علي التسعة عشر. التفصيل تحت الجدول يسمي الملفات والاختبارات والفجوة `P7-xx`.

| البند | المالك | الحالة | المستوى الحالي | فجوات `P7` |
|---|---|---|---|---|
| 1 اختبارات API | مهندس API | Partial | unit | P7-01 |
| 2 الدخول | مهندس API | Partial | widget | P7-02، P7-03 |
| 3 الصلاحيات | مهندس API | Partial | unit + widget | P7-04 |
| 4 أدوار المدير والموظف | Senior Flutter | Covered | widget على #51 | — |
| 5 كل قسم | Senior Flutter | Partial | widget على #51 | P7-07 |
| 6 الحسابات | Senior Flutter | Partial | widget | P7-08، P7-09 |
| 7 سداد جزئي وكامل | Senior Flutter | Partial | widget على #51 | P7-10، P7-11 |
| 8 اعتماد ورفض | Senior Flutter | Partial | widget على #51 | P7-13 |
| 9 كروت مربوطة وغير مربوطة | Senior Flutter | Partial | widget على #51 | P7-14، P7-15 |
| 10 الإشعارات | مطور الواجهة | Partial | unit + widget | P7-16، P7-17، P7-18 |
| 11 انقطاع الإنترنت | مهندس API | Partial | widget | P7-19 |
| 12 إعادة المحاولة | مهندس API | Partial | unit + widget | P7-20 |
| 13 بلا حركة مكررة | مهندس API | Partial | unit + widget | P7-21 |
| 14 الوضع الداكن والفاتح | مطور الواجهة | Covered | widget | — |
| 15 RTL | مطور الواجهة | Covered | widget | — |
| 16 مقاسات الشاشة | مطور الواجهة | Partial | widget | P7-22 |
| 17 الأداء | DevOps | Partial | release مسجّل على #52؛ القص افتراضيًا على #58 | P7-23، P7-24 |
| 18 سجل أو تاريخ طويل | DevOps | Partial | widget على #52؛ فجوة القص DEF-027 على #58 | P7-25 |
| 19 هاتف حقيقي | DevOps | Device-only | سير محاكٍ منفصل على #52 | P7-26 |

### 1 — اختبارات API

- **المالك:** مهندس API
- **الموجود:** مجلد `packages/api_layer/test/` كله هو مجموعة البند. أمثلة: `fake_flow_test.dart` `fake login -> me -> accounts -> mutation with requestId -> logout`؛ `qa_defects_round1_test.dart` `partial payment stores the new balance and rejects a stale version`؛ `permission_service_test.dart` `employee: write needs BOTH *.write and sectionAccess=manage; read needs *.read and != none`؛ `staging_http_test.dart` (محوّل داخل العملية، لا مضيف)؛ `get_retry_auth_header_test.dart`؛ `release_fake_api_guard_test.dart` `release mode rejects a fake client at runtime`؛ `cookie_csrf_strategy_test.dart`؛ `notification_repository_test.dart`. معرّفات القبول: P0-04، P1-16، وعقود P2 وP3 على الخادم التجريبي.
- **الفجوة:** **P7-01** دخان staging حي: `POST /api/auth/login` ثم `GET /api/me` ثم قراءة قسم وكتابة واحدة على `STAGING_API_BASE`. المستوى staging. السؤال المفتوح لمالك الخادم: هل `GET /api/me` هو العقد؟ العميل لا ينادي `GET /api/auth/me`.
- **بعد #56:** `staging_smoke_test.dart` ينادي `markTestSkipped` ويعود قبل `ApiLayer.create` إذا غاب `STAGING_API_BASE` أو `STAGING_ADMIN_USERNAME` أو `STAGING_ADMIN_PASSWORD`. تشغيل `tool/check.sh` على `9c0fa4f` طبع رسالة التخطي ثم `+197 ~1`. هذا **not run** وليس Pass. لا أسرار في المستودع. الحالة Partial.
- **منع الاستبدال:** لا `FakeApiClient` ولا `HttpClientAdapter` يدوي في P7-01. `staging_http_test.dart` لا يُغلق هذا الصف.
- **المستوى:** unit اليوم، staging للدخان.
- **الحالة:** Partial

### 2 — الدخول

- **المالك:** مهندس API
- **الموجود:** `test/login_flow_test.dart`: `employee sees only server-granted sections and the server unread count`، `admin with no permission list sees the sections the flag opens`، `rejected sign-in stays on the login screen and shows the server message`، `empty sign-in does not call the session`. `test/authentication/auth_gate_test.dart`: `unknown session stays on the splash route`، `signed-out session is sent to login`، `authenticated session leaves login and splash`، `a required password change blocks every other route`. `test/fake_server_defects_test.dart` `DEF-008 mustchange.demo is kept on the change-password screen`. `test/session_logout_presentation_test.dart` `logout asks first, cancel stays signed in, confirm uses the existing logout`. الحزمة: `packages/api_layer/test/fake_qa_defects_test.dart` `DEF-008 mustchange.demo returns mustChangePassword until it is changed`؛ `permissions/session_permission_negative_test.dart` `login 401 stays invalid credentials and any later 401 or bare 419 does not`. القبول: P1-01، P1-02، P1-03، P1-04، P1-12، P1-13، P1-14، P1-17، P5-13، P5-14.
- **الفجوة:** **P7-02** دخول staging للأدوار عبر نموذج الدخول و`CookieCsrfAuthStrategy`، وكلمة خاطئة تبقى `INVALID_CREDENTIALS`. **P7-03** إغلاق العملية ثم فتحها فيستعيد `SecureDeviceTokenStore` / مخزن الجلسة الجلسة بلا حقن `SessionAuthenticated`. المستوى: staging ثم device.
- **بعد #56:** سبعة اختبارات `P7-02` على `SessionManager` و`AuthInterceptor` و`CookieCsrfAuthStrategy`، والمحوّل وحده مزيّف. ودجت واحد لنموذج الدخول على `FakeApiClient`. طلبان مصادقان بـ 401 ينتجان `session_expired` مرة واحدة بلا `GET /api/auth/csrf`. 419 برمز `PAGE_EXPIRED` ينهي الجلسة ولا يجلب CSRF. 419 الذي يحمل CSRF يجدّد مرة ويعيد الكتابة والجلسة تبقى `SessionAuthenticated`؛ الفشل الثاني يرمي `CsrfInvalidException` بلا خروج. دخول 401 يبقى `InvalidCredentialsException` و`INVALID_CREDENTIALS` ولا يمسح جلسة قائمة. دخول الأدوار على staging وP7-03 باقيان. لا اسم اختبار لـ P7-03. الحالة Partial.
- **منع الاستبدال:** لا تمرير `sessionStateProvider` جاهز في P7-02 وP7-03. لا `MemoryDeviceTokenStore` حين الادعاء إعادة التشغيل.
- **المستوى:** widget على Fake. الفجوة staging وdevice.
- **الحالة:** Partial

### 3 — الصلاحيات

- **المالك:** مهندس API
- **الموجود:** وسم `permissions-negative`. التطبيق: `test/employee_permission_negative_test.dart`، `test/employee_totals_permission_negative_test.dart` `limited admin provider state is forbidden until DEF-002`، `test/permissions/employee_gating_permission_negative_test.dart` `an employee does not see totals or decide, and the fake server rejects both`، `test/permissions/session_permission_negative_test.dart`، `test/permissions/treasury_section_permission_negative_test.dart`، `test/permissions/push_transport_permission_negative_test.dart`، `test/permissions/system_tray_permission_negative_test.dart`. الحزمة: `packages/api_layer/test/employee_permission_negative_test.dart` `a missing session is 401 and limited admin still has decide`، `employee_totals_permission_negative_test.dart`، `permissions/session_permission_negative_test.dart`، `permissions/session_wipe_permission_negative_test.dart` `employee cannot decide, reject, or reach management routes on the fake`، `permissions/treasury_section_permission_negative_test.dart`، `permissions/notifications_permission_negative_test.dart`. أيضًا `permission_service_test.dart` و`test/permissions_ui_test.dart` `explicit fullAccess false opens no sections and no actions`. القبول: P1-05 إلى P1-11، P1-15، P5-10، P5-11، P5-20، P5-21، P5-30، P5-32، P5-40، P5-42، P3-02، P3-03.
- **الفجوة:** **P7-04** مصفوفة staging: الموظف 403 على الاعتماد والخزينة والإعدادات، والمدير 200 على قراءة قسم، ومن `GET /api/me` لا من `PermissionService()` مبني في الاختبار. DEF-002 يبقى Pending PM: نجاح اعتماد `limited.admin` على Fake لا يُغلق البند.
- **سؤال مفتوح لمالك الخادم:** هل `GET /api/me` هو عقد الصلاحيات؟ الثابت `ApiEndpoints.me` هو `/api/me`. `ProfileRepository.get` وعامل الاستطلاع `notification_poll_worker.dart` يناديانه، وتعليق `SessionManager` يصف الدخول ثم `GET /api/me`. لا سلسلة `auth/me` تحت `lib/` ولا `packages/api_layer/lib`. #56 لا يضيف المسار الآخر.
- **بعد #56:** سبعة اختبارات باسم P7-04. خمسة أدوار ثم المدير على `FakeApiClient` عبر `session.login`. اختبار الجسم يغيّر رد `GET /api/me` على المحوّل ويؤكد أن المسارات لا تحتوي `/api/auth/me`. مصفوفة staging وDEF-002 باقيان. الحالة Partial.
- **منع الاستبدال:** لا `applyFromServer` يدوي مكان رد الدخول في P7-04. اختبار الوحدة على `PermissionService` يبقى دليل عقد، لا دليل خادم.
- **المستوى:** unit + widget. الفجوة staging.
- **الحالة:** Partial

### 4 — أدوار المدير والموظف

- **المالك:** Senior Flutter
- **الموجود:** `test/login_flow_test.dart` (الاختباران الأولان أعلاه). `test/shell_group_test.dart`: `an employee does not see settings or admin routes`، `guest and flag admin see no sections and no settings`، `limited admin has no settings entry`. `test/collections_presentation_test.dart` `each fake role only sees the collections actions it may use`. `test/forbidden_presentation_test.dart`: `employee hides management totals, decisions, and admin tiles`، `admin still sees totals, approve, reject, and admin tiles`. `test/ledger_presentation_test.dart`: `an employee does not see ledger writes`، `a limited admin does not see ledger writes`. القبول: P5-10، P5-20، P5-30، P5-40، P3-12.
- **بعد #51:** `test/phase7_roles_test.dart` خمسة أدوار من `login-screen` و`signIn` على الحقول `username-field` و`password-field` وزر `login-button`. السكة من `SectionKey` والجلسة. لا `SessionAuthenticated` مسبق.
- **الفجوة:** **P7-05** أُغلق على مستوى الودجت والخادم التجريبي. لم يُدمج #51.
- **منع الاستبدال:** لا `SessionAuthenticated` مسبق. لا إخفاء الأزرار بشرط اختبار بدل `PermissionService` القادم من `me`.
- **المستوى:** widget
- **الحالة:** Covered

### 5 — كل قسم

- **المالك:** Senior Flutter
- **الموجود:** `SectionKey` في `packages/api_layer/lib/core/permissions/permission_codes.dart`: `customers`، `collections`، `companies`، `libyan-deposits`، `egyptian-deposits`، `masraweya`، `purchases`، `treasury`، `reports`. `test/section_errors_test.dart`: خطأ ثم إعادة لكل من الديون، والدفتر، والاستلامات، والمشتريات، والخزينة، والتقارير، ودفتر الإعدادات، والبحث. `test/shell_group_test.dart` `DEF-010 view all for ${section.key} opens /${section.key}` و`companies-only debts open the companies section`. `test/home_contract_test.dart` `home, cash status, version, and rates stay server text`. `test/qa_round_test.dart` `home sections lay out for $user`. شاشات: `collections_presentation_test.dart`، `purchases_presentation_test.dart`، `treasury_reports_polish_test.dart`، `masraweya_save_test.dart`، `account_list_ui_test.dart`. القبول: P1-05، P1-18، P4-01 إلى P4-08، P5-03، P5-04، P5-05، P5-06.
- **بعد #51:** `P7-06 admin reads every section from the signed-in session` يفتح `HomeDashboard` ثم المسارات التسعة لكل `SectionKey`. لا `homeDashboardProvider.override`. **P7-07** ما زال `employeesEmpty` و`auditEmpty` و`operationsEmpty`. الاختبار على #51 يثبت النص ولا يغلق الصف. DEF-012 يبقى Fail.
- **الفجوة:** **P7-06** أُغلق على الودجت. **P7-07** شاشات الإعدادات على staging أو بعد بيانات حقيقية. هذا Fail معروف، لا Pass.
- **منع الاستبدال:** تجاوز `homeDashboardProvider` في اختبار DEF-010 يثبت التوجيه فقط. لا يُحتسب زيارة قسم. لا استبدال `collectionsProvider` بقائمة ثابتة في P7-06.
- **المستوى:** widget. P7-07 staging.
- **الحالة:** Partial

### 6 — الحسابات

- **المالك:** Senior Flutter
- **الموجود:** `test/account_list_actions_test.dart`: `zero review is per card and only when the server allows it`، `Egyptian deposits send the pinned filter`، `phone show-all loads the remaining pages for the active filter`. `test/account_list_logic_test.dart` `load-more rows clear when that section filter or query changes`. `test/edit_account_card_test.dart`: `edit follows section write, allowedActions, and system cards`، `admin can open edit from each card section`، `a blank name does not send, and a retry reuses the request id`. `packages/api_layer/test/account_list_query_test.dart` `list sends filter for Egyptian deposits the same way as customers`. `packages/api_layer/test/zero_review_read_test.dart`. القبول: P2-01، P2-07، P2-09، P2-10، P2-11، P2-12، P4-004.
- **بعد #51:** لا اختبار لإنشاء كارت أو رفض التكرار. P7-08 وP7-09 باقيان.
- **الفجوة:** **P7-08** إنشاء كارت والبحث قبل التكرار عبر متحكّم الحساب و`FakeApiClient`، لا مستودع مستبدل. **P7-09** عينة staging من 10 كروت لكل قسم تطابق الويب (P2-01). المستوى widget ثم staging.
- **منع الاستبدال:** لا حقن رصيد في الودجت ثم مقارنته بنفسه. الرصيد المعروض هو حقل الرد.
- **المستوى:** widget. P7-09 staging.
- **الحالة:** Partial

### 7 — سداد جزئي وكامل

- **المالك:** Senior Flutter
- **الموجود:** `packages/api_layer/test/qa_defects_round1_test.dart`: `DEF-003 full payment stores balance 0`، `partial payment stores the new balance and rejects a stale version`، `DEF-016 partial payment and cancel publish the stored home balance`. `test/qa_defects_round1_test.dart`: `DEF-003 full payment refreshes the ledger header and the list`، `DEF-016 a partial payment shows the stored home balance`، `DEF-016 full payment no longer shows the 320 home debt row`. `test/transaction_correction_test.dart` `full payment sends a chosen date and omits an unchosen one`. `packages/api_layer/test/v027_fields_test.dart` `full payment omits a date the user did not choose`. `test/write_safety_test.dart` `a payment dialog ignores a second confirm while the send is in flight`. القبول: P2-03، P2-04، P2-05، P2-06.
- **بعد #51:** `P7-10 a partial payment then a full payment on the same card` من `add-payment` ثم `full-payment` على `c_55`، والنقرة الثانية أثناء الإيقاف طلب واحد، والرأس 220 ثم 0. DEF-020 وDEF-022 يمنعان إغلاق الصف. P7-11 staging باقٍ.
- **الفجوة:** **P7-10** المسار السعيد موجود والصف Partial بسبب DEF-020 وDEF-022 على `main`. **P7-11** المطابقة على staging مقابل الويب.
- **بعد #53:** حوار السداد المباشر يرفض 400 و321 قبل POST، ويقبل 320. `320.01` يرفضه `parseUnits`. المقارنة من رصيد المزوّد المخزَّن لا من GET جديد. رد الخادم التجريبي 400 `VALIDATION_ERROR` مؤقت. القسمة والضرب بلا مقارنة، والسؤال مفتوح. لم يُدمج. الحالة Partial.
- **بعد #55:** تعارض الإصدار يعيد الرمي، والرأس يصير `319 د.ل` قبل إغلاق الحوار وبعد العودة. لم يُدمج. الحالة Partial.
- **على `main` `c40e03d`:** اختبارا DEF-020 وDEF-022 داخل `tool/check.sh` **384/0**، ثم مرة أخرى على #52 `f347a8a` **393/0** مع التحميل الكسول. العيبان Verified closed. P7-11 staging باقٍ. الحالة Partial.
- **على #51 `721edef`:** حُذف اختبارا `known-bug` اللذان يتوقعان رأس `-80 د.ل` وبقاء الرأس 320 بعد 409. تغطية السلوك المصحّح على `main`: `DEF-020 the payment dialog refuses an amount above the server balance` (حوار 400 على `c_55`، بلا POST، الرأس `320 د.ل`، المخزَّن 320 والإصدار 4) و`DEF-022 a payment conflict refetches the card and the ledger` (الرأس `319 د.ل` قبل إغلاق الحوار وبعد العودة، المخزَّن 319 والإصدار 5). مسار P7-10 السعيد بقي. الحالة Partial.
- **منع الاستبدال:** لا متحكّم دفتر يضع الرصيد 0 محليًا. الأمانات لا تُمرَّر فيها سداد كامل إن كان الزر غائبًا (P2-04).
- **المستوى:** unit + widget. P7-11 staging.
- **الحالة:** Partial

### 8 — اعتماد ورفض

- **المالك:** Senior Flutter
- **الموجود:** `test/unlinked_receipt_actions_test.dart`: `reject and cash stay hidden without the action permission`، `decide without cash receive shows reject and hides cash`، `retrying an unchanged reject reuses the request id and version`، `confirming cash on a rejected receipt sends its version`. `test/forbidden_presentation_test.dart` `admin still sees totals, approve, reject, and admin tiles`. `test/qa_defects_round1_test.dart` `DEF-002 limited admin can approve because the server grants decide`. `packages/api_layer/test/qa_defects_round1_test.dart` `unlinked decision stores status and version and rejects a stale one` و`DEF-002 limited admin has collections.decide and the server accepts it`. `test/permissions/employee_gating_permission_negative_test.dart`. القبول: P3-02، P3-03، P3-04، P3-10، P3-11، P3-12.
- **بعد #51:** `P7-12 admin approves one submission and rejects another` من `approve-sb_1` و`reject-sb_9` ثم قراءة المستودع. الموظف لا يرى الأزرار و`decide` يعيد 403. DEF-002 يبقى مفتوحًا وليس Pass. P7-13 staging باقٍ.
- **الفجوة:** **P7-12** أُغلق على الودجت والخادم التجريبي. **P7-13** اعتمادان متزامنان بإصدار واحد على staging.
- **منع الاستبدال:** لا `onDecide` مستبدل. DEF-002 لا يُحسب Pass للمدير المحدود.
- **المستوى:** widget. P7-13 staging.
- **الحالة:** Partial

### 9 — كروت مربوطة وغير مربوطة

- **المالك:** Senior Flutter
- **الموجود:** `test/collections_presentation_test.dart`: `the unlinked and assignment forms stay inside a narrow large-text sheet`، `approved unlinked receipts keep the locked status colour`. `test/unlinked_receipt_actions_test.dart` `a pending receipt is not offered cash until the server says so`. `packages/api_layer/test/qa_defects_round1_test.dart` `unlinked decision stores status and version and rejects a stale one`. القبول: P3-07، P3-08، P3-09، P3-10.
- **بعد #51:** الإرسال من `submit-as_1` و`save-unlinked` حقيقي، والنظرة لا تحتوي الصف الجديد (DEF-021). ربط `ur_1` يخزّن `customerId` ولا يحرّك رصيد `c_55`. P7-15 staging باقٍ.
- **الفجوة:** **P7-14** Partial. الإبطال وإعادة القراءة كانا على الشاشة. الغياب من النظرة عيب `FakeApiClient`. **P7-15** الزوج نفسه على staging.
- **بعد #54:** الخادم التجريبي يخزّن `sb_posted_1` و`ur_posted_1`، والحواران الحقيقيان يُظهرانهما على الشاشة نفسها. لا فرق في `lib/`. DEF-021 صار عيب بديل اختبار. فحص الخادم الحقيقي باقٍ. لم يُدمج. الحالة Partial.
- **على `main` `c40e03d`:** اختبار DEF-021 داخل **384/0** وعلى `f347a8a` داخل **393/0**. العيب Verified closed كبديل اختبار. P7-15 staging باقٍ. الحالة Partial.
- **على #51 `721edef`:** حُذف اختبار `known-bug` الذي يتوقع غياب الصف من النظرة. التغطية على `DEF-021 the next collections overview shows the submitted rows`: الحواران 40 و25، والصفان `sb_posted_1` و`ur_posted_1`، والمبلغان، وبعد المغادرة والعودة. اختبار الحزمة يثبت الإصدار 1. سلاسل `mutationPaths` الخام لم تُنسخ. الحالة Partial.
- **منع الاستبدال:** لا `onSubmit` فارغ. حالة الربط تُقرأ من الرد (`assignment` / غياب الربط) لا من علم اختبار.
- **المستوى:** widget. P7-15 staging.
- **الحالة:** Partial

### 10 — الإشعارات

- **المالك:** مطور الواجهة
- **الموجود:** `test/notifications_controller_test.dart` `push and poll dedupe, and a push does not increment the count` و`mark-read updates readAt and the server count, without a second decrement`. `test/notifications_presentation_test.dart`: `rows and the bell use the server notification fields`، `a foreground event shows a banner and the tap uses origin banner`، `notification permission asks, then grants, denies, or opens settings`. `test/notifications_wiring_test.dart`: `a list tap marks the row read once`، `below Android 33 registers without asking`، `Android 33 asks before the device post`، `allow posts the device token once`. `test/system_tray_bg_poll_test.dart`: `scheduling uses at least 15 minutes, the network, and keep`، `tray dedup is shared by push, poll, and the worker`. `test/system_tray_navigation_test.dart` `a cold tray payload for the signed-in user opens collections`. `test/permissions/system_tray_permission_negative_test.dart` `the lock-screen public version has no name and no amount`. `test/notifications/notification_channels_test.dart` `collections channel id, Arabic name, and badge flag stay stable`. `integration_test/android_notifications_test.dart` `notification permission matches NOTIF_CASE` غير داخل `check.sh` وهذا التشغيل بلا محاكٍ. القبول: P6-01 إلى P6-40. حكم المرحلة 6 على #12: مقبول بشروط، بلا توقيع.
- **الفجوة:** **P7-16** جهاز: صينية المقدمة، حوار الإذن على API 33، نص القفل `إشعار جديد`، والنقر يفتح الكيان وينقص العدد مرة. **P7-17** الخلفية، ثم العملية المقتولة. إن لم يصل شيء بعد الإيقاف الإجباري فالنتيجة Not supported (لا FCM) لا Fail وهمي. **P7-18** API 29 بلا حوار تشغيل، وAPI 34 كـ 33. المستوى device.
- **بعد #49:** ودجت للحوار والقفل والنقرة والاستطلاع و`sdkInt` ‏29/33/34. نصف الجهاز مفتوح. DEF-019 ما زال مفتوحًا على `main` `a5ca268` في تلك المراجعة. التفاصيل في مراجعة #49 و#50. الحالة Partial.
- **على `main` `c40e03d`:** اختبارات DEF-019 الخمسة **+5** وخروج 0، وعلى `f347a8a` أيضًا **+5**. العيب Verified closed. نصف الجهاز من P7-16 وP7-17 وP7-18 ما زال مفتوحًا. الحالة Partial.
- **بعد #49 على `653a07c`:** `_skipDef019` صار `false`. اختبار `a granted login does not register again on the first notifications visit` نجح داخل التطبيق **466/0** بلا تخطي. النقل `FakePushTransport` والمسجّل عبر `pumpFakeApp`. نصف الجهاز من P7-16 وP7-17 وP7-18 ما زال مفتوحًا. قتل العملية Not supported بلا FCM. الحالة Partial.
- **منع الاستبدال:** `granting permission registers with signedIn true` يستبدل المسجّل (`RecordingDeviceTokenRegistrar`) ولا يُغلق الإرسال. درس DEF-018: الموافقة تُقاس على `buildAppRoot` والمسجّل الحقيقي. لا `notificationOpenSeamProvider` مسجّل حين يُحكم على النقر. نقل `FakePushTransport` مسموح في ودجت Fake فقط.
- **المستوى:** unit + widget. الفجوة device.
- **الحالة:** Partial

### 11 — انقطاع الإنترنت

- **المالك:** مهندس API
- **الموجود:** حقن انقطاع، لا وضع طيران. `test/review_round_test.dart` `offline disables writes and the status line follows connectivity`. `test/review_round2_test.dart`: `an open form save is disabled while offline`، `missing platform connectivity follows the last API result`. `test/ledger_presentation_test.dart` `offline disables ledger writes until the link returns`. `test/account_list_ui_test.dart` `offline keeps permitted writes visible and disabled`. `test/purchases_presentation_test.dart` `offline keeps purchase actions visible and disabled`. `test/collections_presentation_test.dart` `empty, loading, payroll error, and offline stay consistent`. `test/shell_group_test.dart` `offline disables notification writes and account edits`. `test/treasury_reports_polish_test.dart` `treasury tone, empty ledger, offline, and hidden writes`. القبول: P6-21، L6-06.
- **الفجوة:** **P7-19** وضع الطيران على الجهاز أثناء سداد وأثناء جلب قائمة. بعد القطع لا صف جديد. المستوى device.
- **بعد #56:** اختبارا ودجت يفقدان الاتصال على Dio (`useFakeApi: false` ومحوّل). القراءة تبقي القائمة والمسودة وتعرض رسالة الشبكة و`AppStrings.offline`. الكتابة تبقي النص وترسل POST واحدًا. `connectivityPortProvider` يُقلب إلى none أثناء الطلب، والصدفة `_CustomersShell` لا `buildAppRoot`، و`retry` يرجع `null`. الحقن لا يُغلق P7-19. وضع الطيران يبقى يدويًا على الجهاز. الحالة Partial.
- **منع الاستبدال:** `connectivityProvider` أو `ConnectivityResult.none` المحقون لا يُغلق P7-19. الراديو الحقيقي هو الشرط.
- **المستوى:** widget للعقد. الفجوة device.
- **الحالة:** Partial

### 12 — إعادة المحاولة

- **المالك:** مهندس API
- **الموجود:** `packages/api_layer/test/get_retry_auth_header_test.dart` يعيد GET بعد 502/503 بلا ترويسة قديمة. `docs/staging.md`: GET/HEAD قد تُعاد لأخطاء الاتصال و502/503/504 مرتين كحد أقصى؛ الكتابة لا يعيدها النقل. `test/section_errors_test.dart` أزرار إعادة الجلب. `test/shell_group_test.dart` `a failed startup offers retry on the splash` و`notifications show an error with retry and an empty state`. `test/submission_lock_test.dart` `a retry of the same inputs reuses the request id`. `packages/api_layer/test/staging_http_test.dart` `401 clears the session once and is not retried`.
- **الفجوة:** **P7-20** بعد عودة الراديو في P7-19: إعادة السداد من الواجهة تحمل `requestId` المحاولة نفسها، والنقل لا يرسل POST ثانيًا من تلقاء نفسه. جلب القائمة قد يُعاد كـ GET. المستوى device مع staging.
- **بعد #56:** ثمانية اختبارات لإعادة GET/HEAD (400ms ثم 1200ms، و502/503/504، والمهلات، وRetry-After) ولعدم إعادة الكتابة و4xx و500 و401 و419. إعادة سداد فاشل تعيد `requestId` نفسه وتترك صف دفتر واحدًا. الصف الواحد على المعرّف المكرر من `FakeApiClient._mutate`، لا من `unique()` في الاختبار. المبلغ 10 فلا يُغلق DEF-020. تعارض 409 في المستودع لا يفتح حوار السداد فلا يُغلق DEF-022. عودة الراديو ودفتر staging باقيان. الحالة Partial.
- **منع الاستبدال:** لا مستودع يعيد النجاح محليًا. لا عدّاد اختبار بدل `GetRetryInterceptor` و`PendingMutation`.
- **المستوى:** unit + widget. الفجوة device.
- **الحالة:** Partial

### 13 — بلا حركة مكررة

- **المالك:** مهندس API
- **الموجود:** `packages/api_layer/test/fake_qa_defects_test.dart` `DEF-011 a repeated requestId returns the original success once`. `packages/api_layer/test/masraweya_day_test.dart` `DEF-013 a repeated requestId returns the first day and is not applied again`. `packages/api_layer/test/purchase_day_finalized_test.dart` `DEF-014 a stored requestId does not bypass the finalized-day check`. `test/write_safety_test.dart` `a collection form ignores a second tap while the send is in flight`. `test/submission_lock_test.dart`. `test/guarded_mutation_test.dart` `a version conflict keeps the request id when nothing changed`. `test/masraweya_save_test.dart` `a failed retry keeps the request id until the inputs or version change`. القبول: P2-05، P3-04. `requestId` على السلك ما زال بانتظار مالك الخادم (سؤال على #12، ليس عيبًا).
- **الفجوة:** **P7-21** نقرتان على تأكيد السداد أو الاعتماد ضد staging: محاولة واحدة ظاهرة في الدفتر. إن غاب `requestId` من الجسم يُسجَّل سؤال خادم لا Pass صامت. المستوى staging.
- **بعد #56:** معرّف مكرر وكتابتان معلّقتان ونقرة ثانية على `save-movement` تترك صف `tx_partial` واحدًا. النقرة الثانية تصطدم بـ `GuardedMutation`: `_lock.busy` يعيد فورًا و`onPressed` يصير `null`. الصف الواحد بعد اكتمال المعرّف هو `_pendingMutations` و`_completedMutations` داخل `FakeApiClient._mutate`. المبلغ 10. لا يُغلق DEF-020 ولا DEF-022. مراقبة دفتر staging باقية. الحالة Partial.
- **منع الاستبدال:** لا قفل إرسال مستبدل ولا مولّد معرّف ثابت داخل الاختبار. المعرّف يأتي من قفل النموذج الحقيقي.
- **المستوى:** unit + widget على Fake. الفجوة staging.
- **الحالة:** Partial

### 14 — الوضع الداكن والفاتح

- **المالك:** مطور الواجهة
- **الموجود:** `test/screens_ui_test.dart` `allowed screens render RTL in dark mode`. `test/shell_group_test.dart` `login, home, settings, account, and notifications hold at phone sizes (light|dark)`. `test/collections_presentation_test.dart` `light and dark keep status colours, RTL, and amount direction`. `test/purchases_presentation_test.dart` `purchases renders RTL in light and dark`. `test/ledger_presentation_test.dart` `ledger layout stays whole across widths, scales, and themes`. `test/treasury_reports_polish_test.dart` `both screens lay out on phones in light and dark`. `test/notifications_presentation_test.dart` `the notifications list fits a small and a large phone in both themes`. `test/forbidden_presentation_test.dart` `forbidden pane fits a small phone in light and dark`. لقطات `screenshots` مستبعدة من `flutter test --exclude-tags screenshots`.
- **الفجوة:** لا اختبار آلي جديد لإغلاق الصف. التأكيد على الجهاز خطوة 23 في البروتوكول. تباين #49 مسجّل DEF-023 وDEF-024 وDEF-025 ولا ينقل الصف عن Covered.
- **بعد #57:** الرأس `714c6ea` يرفع الأزواج الثلاثة فوق AA على فرعه. الصف يبقى Covered. العيوب كانت Open على `main` حتى الدمج.
- **على `main` `2a45cfb`:** DEF-023 وDEF-024 وDEF-025 Verified closed. اختبارات `contrast_tokens_test.dart` نجحت داخل **432/0**. `#7C6100` في سمة الوضع الفاتح. الصف يبقى Covered. DEF-026 (`#6D7C77` تحت 4.5:1 للنص العادي وفوق 3:1) مفتوح وغير مانع ولا ينقل الصف.
- **منع الاستبدال:** لا `ThemeData` مفروض فوق `themeModeProvider` حين يُختبر مبدّل السمة. تثبيت `_DarkTheme` مقبول لمعاينة الشاشة لا لزر التبديل.
- **المستوى:** widget
- **الحالة:** Covered

### 15 — RTL

- **المالك:** مطور الواجهة
- **الموجود:** `test/screens_ui_test.dart` `login is RTL and does not offer an external account`. `test/shell_group_test.dart` `disclosure chevrons mirror in RTL`. `test/account_list_ui_test.dart` `amounts sit on the RTL start edge in light and dark`. `test/purchases_opening_correction_test.dart` `opening balance renders RTL in light mode`. `test/edit_account_card_test.dart` `the edit screen stays RTL on a small phone in both themes`. `test/transaction_correction_test.dart` `the correction form is RTL in both themes on small and large phones`. `test/unlinked_receipt_actions_test.dart` `unlinked actions stay RTL in both themes on a small phone`. `test/ledger_presentation_test.dart` `a missing sequence is a dash and dates stay LTR`.
- **الفجوة:** لا اختبار آلي جديد. اتجاه التاريخ LTR مقصود. التأكيد البصري في الخطوة 23.
- **بعد #49 على `653a07c`:** `test/phase7_rtl_ui_test.dart` مطابق بايتًا لـ `546a623`. الصف يبقى Covered.
- **منع الاستبدال:** لا `Directionality(textDirection: TextDirection.rtl)` يلف الشاشة من خارج التطبيق. الاتجاه من `MaterialApp` الحقيقي.
- **المستوى:** widget
- **الحالة:** Covered

### 16 — مقاسات الشاشة

- **المالك:** مطور الواجهة
- **الموجود:** عرض 320 و360 و393 و430 في `test/shell_group_test.dart` `login, home, settings, account, and notifications hold at phone sizes` ومع `text scale` 1 و1.3 و2. `admin bottom bar stays on one row at 320 and 360`. `test/collections_presentation_test.dart` `receipt cards do not overflow across phone widths and text scales`. `test/treasury_reports_polish_test.dart` `the cash form stays reachable at 320 and text scale 2`. `test/employee_totals_screen_test.dart` `a 320 phone fits the cards in both themes`. `test/purchases_opening_correction_test.dart` مقاس 320 و430. `test/screens_ui_test.dart` `a wide window uses the side list instead of a bottom bar`.
- **الفجوة:** **P7-22** تدوير عمودي/أفقي على 320 و430 لدخول والرئيسية والاستلامات والدفتر والإشعارات، بلا فيض. ثم الجهاز الصغير والكبير في البروتوكول. المستوى widget ثم device.
- **بعد #49:** التدوير على 320 و430 موجود في الودجت. نصف الجهاز مفتوح. الحالة Partial.
- **بعد #49 على `653a07c`:** `test/phase7_layout_ui_test.dart` مطابق بايتًا لـ `546a623`. نصف الجهاز من P7-22 ما زال مفتوحًا. الحالة Partial.
- **منع الاستبدال:** `tester.view` يثبت المقاس في الودجت. لا يُغلق جهازًا حقيقيًا. لا `overflow: clip` لإخفاء الخطأ.
- **المستوى:** widget. الفجوة تدوير + device.
- **الحالة:** Partial

### 17 — الأداء

- **المالك:** DevOps
- **الموجود على الأساس:** لا اختبار `Timeline` ولا ميزانية إقلاع ولا قياس تمرير. `integration_test/android_notifications_test.dart` يفحص قناة الإشعار لا الزمن.
- **بعد #52:** `tool/measure_release_cold_start.sh` يبني release بـ `USE_FAKE_API=false` ويطبع وسيط `am start -W`. `integration_test/p7_long_history_test.dart` يطبع أزمنة الإطارات. الحكم والأدلة في مراجعة #52. العتبة ما زالت قرار علي، والرقم في نموذج الهاتف فارغ.
- **إعادة الاختبار `f8f7812`:** الميزانيات مسمّاة engineering proposal وعمود القبول يبقى `recorded`. PSS وRSS وDart heap تقرير فقط في أثر السير المنفصل. التفاصيل في إعادة اختبار #52. الحالة Partial.
- **بعد #58 على `6e7a76c`:** `tool/android_performance_emulator_test.sh` و`tool/measure_release_cold_start.sh` وCI لا يمررون `HISTORY_WINDOW_TRIM`، فالقص يعمل في قياس المحاكي لأن الافتراض صار true. الميزانيات ونموذج الجهاز ونصف P7-24 ما زالت مفتوحة. الحالة Partial.
- **الفجوة:** **P7-23** إقلاع بارد لإصدار release على جهاز ضعيف حتى الرئيسية التفاعلية، مع رقم الثواني في النموذج. **P7-24** تمرير أطول دفتر حتى آخر صفحة مع عدد الصفحات. المستوى device. العتبة الرقمية يكتبها علي في النموذج قبل أول تشغيل؛ بلا عتبة تُسجَّل الأرقام ولا يُخترع Pass.
- **منع الاستبدال:** لا وضع debug ولا `FakeApiClient` في قياس الإصدار. لا قائمة من سطرين تُسمى سجلًا طويلًا.
- **المستوى:** device للنموذج. القياس على #52 release للعملية، وprofile للتاريخ الطويل.
- **الحالة:** Partial

### 18 — سجل أو تاريخ طويل

- **المالك:** DevOps
- **الموجود على الأساس:** صفحات قصيرة. `test/qa_round_test.dart` `load older shows the error and a retry`. `test/treasury_reports_polish_test.dart`: `treasury shows server cards, movements, and older pages`، `treasury load older shows the error and retries`. `test/account_list_actions_test.dart` `phone show-all loads the remaining pages for the active filter`. `test/account_list_logic_test.dart` `a late load-more page is not mixed into the new filter`.
- **بعد #52:** `test/p7_long_history_test.dart` يمشي 20 صفحة عبر زر `load-older` الحقيقي و`FakeDataset.large`. `packages/api_layer/test/fake_large_dataset_test.dart` يجمع 800 سطرًا على 20 صفحة من `FakeApiClient`. نصف الجهاز ما زال مفتوحًا. التفاصيل في مراجعة #52.
- **إعادة الاختبار `f8f7812`:** مع `HISTORY_WINDOW_TRIM` مطفأ يبقي المتحكّم `ledger-retained-760`. مجموعة `ltx_00000`..`ltx_00799` في مشي `FakeApiClient` داخل الحزمة، لا على الشاشة. الحالة Partial.
- **بعد #58 على `6e7a76c`:** الافتراض صار القص. اختبار العلم المطفأ يضبط `HistoryWindow.trimEnabled = false` ويتوقع `ledger-retained-760`. اختبار العلم المشغّل يتوقع `ledger-retained-80` وسقف إشعارات 120. الشاشة مع الافتراض تُبقي الصفحة الأولى ثم أبعد 80، فوسط الدفتر فجوة (DEF-027). نصف الجهاز من P7-25 ما زال مفتوحًا. الحالة Partial.
- **الفجوة:** **P7-25** دفتر من عدة صفحات عبر `load more` الحقيقي حتى الصفحة الأخيرة، على `FakeApiClient` بعدد صفحات معلوم، ثم على جهاز P7-24. المستوى widget ثم device.
- **منع الاستبدال:** لا حقن صفحتين ثم ادّعاء تاريخ طويل. مصدر الصفوف المستودع أو الخادم.
- **المستوى:** widget للصفحات. القياس device.
- **الحالة:** Partial

### 19 — هاتف حقيقي

- **المالك:** DevOps (تجهيز التشغيل). التنفيذ على قائد الاختبار والمالكين حسب البروتوكول.
- **الموجود على الأساس:** لا مصفوفة جهاز في CI التشغيل `39699625496`. `tool/android_notification_emulator_test.sh` يبني debug بـ `USE_FAKE_API=true` وهو خارج هذه البوابة. `integration_test/android_notifications_test.dart` لا يطلب الإذن بنفسه.
- **بعد #52:** `.github/workflows/android-performance.yml` سير منفصل لمستويات API ‏29 و33 و34. `docs/testing/PHASE7_PERFORMANCE.md` يطابق أعمدة النموذج وينص على أن سجل المحاكي ليس نموذج البروتوكول. النموذج نفسه فارغ.
- **إعادة الاختبار `f8f7812`:** عينات الذاكرة تدخل أثر المحاكي ولا تملأ نموذج الهاتف. الحالة Device-only.
- **الفجوة:** **P7-26** تنفيذ القسم ب على API 29 و33 و34، وشاشة صغيرة وكبيرة، وجهاز ضعيف، وإرفاق النموذج. المستوى device.
- **منع الاستبدال:** بناء release المشار إليه في القسم ب. لقطة محاكٍ بلا راديو لا تغلق وضع الطيران ولا الصينية.
- **المستوى:** device
- **الحالة:** Device-only

### أكبر الفجوات حسب المالك

| المالك | ما يُكتب أولًا |
|---|---|
| مهندس API | بعد #56 على `9c0fa4f` يبقى: دخان P7-01 (not run بلا أسرار staging)، ودخول الأدوار على staging، وP7-03 على الجهاز، ومصفوفة P7-04 الحية، وطيران P7-19، وعودة الراديو، ودفتر staging لـ P7-20 وP7-21. السؤال المفتوح: هل `GET /api/me` هو العقد؟ |
| Senior Flutter | على `main` `c40e03d` أُغلق DEF-020 وDEF-022، وأُغلق DEF-021 كبديل اختبار. البند 7 يبقى Partial لـ P7-11. البند 9 يبقى Partial لـ P7-15. P7-07 مع DEF-012، وP7-08، وصفوف staging P7-09 وP7-13 باقية. إعادة اختبار #51 على `721edef` و#52 على `f347a8a` لم تنقل عددًا |
| مطور الواجهة | بعد #49 على `653a07c` الحكم **YES**. DEF-023 وDEF-024 وDEF-025 Verified closed على `main` `2a45cfb`. DEF-026 مفتوح وغير مانع. الجهاز لـ P7-16 وP7-17 وP7-18 وP7-22 باقٍ. قتل العملية Not supported بلا FCM. البنود 10 و16 Partial، و14 و15 Covered |
| DevOps | بعد #58 على `6e7a76c` يبقى: رقم P7-23 وP7-24 على الجهاز الضعيف في النموذج، وعتبة علي، ونصف الجهاز من P7-25، ونموذج P7-26 على الهواتف A–D. سير المحاكي لا يملأ النموذج. القص صار الافتراض لأن السكربتات لا تمرر `HISTORY_WINDOW_TRIM`. DEF-027 مفتوح وغير مانع: فجوة وسط الدفتر والحسابات، وسقف الإشعارات 120، ولا سحب يعيد النافذة. الذاكرة تقرير فقط |

### فهرس `P7`

| المعرف | البند | المستوى |
|---|---|---|
| P7-01 | دخان staging: دخول، `me`، قراءة، كتابة | staging |
| P7-02 | دخول أدوار staging من النموذج | staging |
| P7-03 | استعادة الجلسة بعد قتل العملية | device |
| P7-04 | مصفوفة صلاحيات من `GET /api/me`. السؤال المفتوح: هل هذا مسار العقد؟ | staging |
| P7-05 | دور واحد لكل حساب من نموذج الدخول على Fake | widget |
| P7-06 | قراءة كل `SectionKey` بلا استبدال لوحة الرئيسية | widget |
| P7-07 | إعدادات الموظفين والتدقيق والعمليات ببيانات أو تبقى DEF-012 | staging |
| P7-08 | إنشاء كارت ورفض التكرار عبر المتحكّم | widget |
| P7-09 | 10 كروت لكل قسم تطابق الويب | staging |
| P7-10 | سداد جزئي ثم كامل من الحوار | widget |
| P7-11 | السداد الجزئي والكامل على staging | staging |
| P7-12 | اعتماد ورفض من `CollectionsScreen` | widget |
| P7-13 | اعتماد متزامن بإصدار واحد | staging |
| P7-14 | إرسال مربوط وغير مربوط ثم اعتماد | widget |
| P7-15 | المربوط وغير المربوط على staging | staging |
| P7-16 | صينية، إذن، قفل، نقر | device |
| P7-17 | خلفية وعملية مقتولة | device |
| P7-18 | إشعارات API 29 و33 و34 | device |
| P7-19 | وضع طيران أثناء الكتابة والجلب | device |
| P7-20 | إعادة بعد عودة الشبكة بنفس `requestId` | device |
| P7-21 | نقرتان تتركان حركة واحدة على staging | staging |
| P7-22 | تدوير 320 و430 | widget |
| P7-23 | إقلاع بارد release | device |
| P7-24 | تمرير السجل الطويل | device |
| P7-25 | صفحات load-more حتى الأخيرة | widget |
| P7-26 | نموذج الهاتف على 29 و33 و34 | device |

---

## ب. بروتوكول الهاتف الحقيقي

### الأجهزة المطلوبة

| الجهاز | الشرط |
|---|---|
| A | Android API 29 على الأقل، شاشة صغيرة |
| B | API 33، شاشة كبيرة |
| C | API 34 |
| D | جهاز ضعيف للإقلاع والتمرير. يكفي أن يكون أحد A–C إن كان ضعيفًا، ويُذكر اسمه |

يُملأ لكل جهاز: الاسم، `ro.build.version.sdk`، مقاس الشاشة، ومساحة حرة تكفي للتثبيت.

### البناء الذي يُثبَّت

تمريرة البروتوكول على **release** مع أصل staging:

```bash
flutter build apk --release \
  --dart-define=USE_FAKE_API=false \
  --dart-define=API_BASE=https://<staging-host>
```

`<staging-host>` أصل فقط كما في `docs/staging.md`: `https`، بلا مسار ولا مستخدم ولا استعلام. يجب أن يقبله `tool/staging_negative_tests/preflight.py` (وسم `staging` أو `test`، ويرفض `prod` / `production` / `live`).

`USE_FAKE_API=true` في release مرفوض عند الترجمة. الدليل الآلي: `tool/check_release_rejects_fake_api.sh`. بناء debug بـ `USE_FAKE_API=true` (`tool/android_notification_emulator_test.sh`) حلقة مطور ولا يُملأ به نموذج هذا البروتوكول.

بناء debug مع `USE_FAKE_API=false` ونفس `API_BASE` مسموح كتمريرة تمهيدية إذا كُتب `debug` في عمود البناء. صف القبول للجهاز يبقى release.

يُسجَّل SHA المصدر `git rev-parse HEAD` ووقت البناء. لا أسرار ولا `google-services.json` داخل Git.

### الشروط السابقة

1. حساب لكل دور من البيئة لا من المستودع: `STAGING_ADMIN_*`، `STAGING_EMPLOYEE_*`، `STAGING_EMPLOYEE2_*`. الزوج `STAGING_LIMITED_MANAGER_*` إن وُجد (DEF-002). الضيف و`flag.admin` إن سلّمهما علي، وإلا تُكتب «غير مسلَّم» ولا يُختلق حساب.
2. تثبيت نظيف: إزالة التطبيق ثم تثبيته. لا جلسة قديمة.
3. شبكة تصل إلى staging قبل خطوات الطيران.
4. لكل دور: قسم قابل للقراءة، كارت فيه رصيد، واستلام معلّق إن كان الدور يعتمد. إن غاب الكيان تُكتب «Blocked» لا Fail للمنتج.

### الخطوات

1. ثبّت APK الإصدار. تأكد أن التشغيل لا يفتح `FakeApiClient` (طلب حقيقي يظهر في سجل staging أو يفشل بلا شبكة). سجّل SHA.
2. ادخل بحساب المدير. الرئيسية تظهر وأقسام المصفوفة ظاهرة.
3. اخرج إلى نموذج الدخول. كلمة خاطئة تبقى على النموذج برسالة الخادم، بلا جلسة.
4. دخول فارغ لا يتنقل.
5. ادخل ثم أكّد الخروج. الرجوع يبقى على الدخول. ألغِ الخروج مرة وتبقى الجلسة.
6. ادخل بالموظف. الأقسام الممنوحة فقط. لا إعدادات. لا أزرار اعتماد أو رفض.
7. ادخل بالإداري المحدود إن وُجد الحساب. لا مدخل إعدادات. إن ظهر الاعتماد فسجّل DEF-002 ولا تغلقه.
8. افتح رابط قسم ممنوع. النص «القسم غير مصرح لهذا الحساب». لا جملة خادم خام ولا بيانات الكيان.
9. بحساب المدير افتح بالترتيب: الرئيسية، `customers`، `collections`، `companies`، `libyan-deposits`، `egyptian-deposits`، `masraweya`، `purchases`، `treasury`، `reports`. كل شاشة إما صفوف خادم أو فراغ حقيقي، بلا انهيار.
10. افتح `/settings/employees` و`/settings/audit` و`/settings/operations`. إن بقيت جمل الفراغ فالحكم DEF-012 لا Pass.
11. افتح كارتًا. سجّل الرصيد الظاهر وقارنه بعينة الويب لذلك المعرف.
12. سداد جزئي بمبلغ أصغر من الرصيد. الرصيد الجديد من الجلب التالي. سطر واحد في الدفتر.
13. سداد كامل على كارت ليس أمانات. الرصيد 0 من الخادم. على الأمانات الزر غير متاح (P2-04).
14. على كارت آخر اضغط تأكيد السداد مرتين بسرعة. حركة واحدة.
15. فعّل وضع الطيران قبل تأكيد سداد. لا حركة. أعد الشبكة وأعد المحاولة من الواجهة. ما زالت حركة واحدة. جلب القائمة يعود.
16. اعتمد استلامًا معلّقًا. ارفض آخر. الموظف لا يرى الزرين، ومحاولة مباشرة لا تُطبَّق.
17. أنشئ استلامًا من إسناد (مربوط) واستلامًا بلا ربط. اعتمد غير المربوط إن سمح الخادم.
18. على API 33: ادخل الإشعارات. الشرح العربي ثم حوار النظام. بعد الموافقة: إشعار مقدمة. النص بلا مبلغ ولا هاتف ولا كوكي. شاشة القفل نص عام (`إشعار جديد`) إن كانت القناة خاصة. النقر يفتح الكيان والعدد ينقص مرة. النقرة الثانية لا تنقص.
19. أرسل التطبيق إلى الخلفية. إشعار واحد في الصينية. عند العودة الشارة من الخادم.
20. أوقف التطبيق من النظام ثم أعد الإرسال. إن لم يصل شيء سجّل Not supported (لا رمز FCM). لا تكتب Fail على اختبارات Fake.
21. على API 29: لا حوار `POST_NOTIFICATIONS` والقائمة تفتح. على API 34: الحوار كالـ 33.
22. ارفض الإذن مرة. القائمة والشارة تعملان بلا انهيار. الرفض الدائم يفتح الإعدادات ولا يعيد حوارًا فارغًا.
23. بدّل الداكن ثم الفاتح على الرئيسية وقسم والإشعارات. تأكد RTL والمبالغ على حافة البداية. دوّر الشاشة على الجهاز الصغير والكبير.
24. على الجهاز الضعيف، بعد تثبيت نظيف: زمن الإقلاع البارد حتى الرئيسية. ثم مرّر أطول دفتر حتى آخر صفحة واكتب عدد الصفحات وأي تقطيع ظاهر.
25. اخرج. ادخل بالحساب الثاني. لا قائمة ولا إشعار من الحساب السابق.

### نموذج النتيجة

انسخ صفًا لكل خطوة على كل جهاز.

| device | OS/API | build SHA | tester | date | step | expected | actual | pass/fail | screenshot ref | defect id |
|---|---|---|---|---|---|---|---|---|---|---|
| | | | | | | | | | | |

قيم `pass/fail`: `Pass`، `Fail`، `Blocked`، `Not supported`. DEF-020 حتى DEF-026 مسجّلة في `defects.md` على #12. التالي الحر DEF-027.

---

## ج. مراجعة طلبات الفريق في المرحلة 7

قبل اعتبار الطلب جاهزًا للمراجعة:

1. **منع الاستبدال.** الاختبار الجديد يمر على المزوّد الجذر أو `buildAppRoot` أو المسجّل أو المتحكّم. الاستبدال المسموح: `FakeApiClient` أو محوّل HTTP أو `FakePushTransport` حين الحالة Fake. يُرفض طلب يغلق P7-16 بـ `RecordingDeviceTokenRegistrar`، أو P7-06 بتجاوز `homeDashboardProvider`، أو P7-19 بـ `ConnectivityResult` محقون.
2. **وسم `permissions-negative`.** كل حالة 403/401 لدور بلا صلاحية في ملف تحت `test/permissions/` أو `packages/api_layer/test/permissions/` أو الملفات الموسومة الحالية، و`tool/run_permissions_negative_tests.sh` أخضر. صفر اختبارات موسومة يفشل السكربت.
3. **`tool/check.sh` أخضر** على رأس الطلب: تحليل، اختبارات بلا وسم `screenshots`، حزمة API، السالب، `preflight_test.sh`، `scan_release_apk.py --self-test`، ورفض ترجمة `USE_FAKE_API=true` في release.
4. **لا Fake في release.** لا `--dart-define=USE_FAKE_API=true` في بناء release ولا في وثيقة التثبيت. debug بـ Fake يبقى حلقة مطور ويُسمّى كذلك.
5. **العيوب.** عيب جديد من DEF-020 فصاعدًا في [`docs/acceptance/defects.md`](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/blob/cursor/acceptance-docs-13b0/docs/acceptance/defects.md) على [#12](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/12). عند كتابة الخطة كان التالي الحر DEF-020. بعد مراجعة #51 كان التالي الحر DEF-023. بعد مراجعة #49 التالي الحر DEF-026. بعد تأكيد `main` `2a45cfb` فُتح DEF-026 وصار التالي الحر **DEF-027**. لا يُغلق DEF-002 ولا DEF-012 من طلب مرحلة 7 إلا بقرار علي أو ببيانات الإعدادات. DEF-019 كان مفتوحًا وغير مانع عند كتابة القاعدة، وأُغلق على `main` `c40e03d`. مسبار #50 لم يغلقه قبل ذلك الدمج.
6. **لا دمج من هذه الخطة.** المراجعة لا تدمج `main`. لا دفع قسري.
7. **المستوى مكتوب** على الاختبار أو في وصف الطلب: unit أو widget أو integration أو device أو staging. اختبار Fake لا يُغلق صفًا حالته Device-only أو شرطه staging.

### مراجعة #52 — الأداء والتاريخ الطويل

الطلب [#52](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/52) مسودة. الرأس `dc713ffd09442d0499ab2270ef88ce7f5f47a1a1`. الأب والأساس `main` `a5ca26809578dd013430dcaae78c517043e95491`. الفرع `cursor/phase7-performance-cc01`. 31 ملفًا. لم يُدمج. هذه المراجعة لم تدفع إلى فرعه ولم تغيّر كود الإنتاج. لا توقيع.

**الحكم:** yes with notes. لم يُفتح DEF-020.

`tool/check.sh` على هذا الرأس، شجرة محلية `/tmp/wt-52`، رمز الخروج 0:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 4.9s)` |
| `flutter test --exclude-tags screenshots` | **375/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.5s)` |
| `flutter test` في `packages/api_layer` | **155/0** |
| `--tags permissions-negative` التطبيق | **27/0** |
| `--tags permissions-negative` الحزمة | **23/0** |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

CI التشغيل `39707007033` أخضر: Analyze, test, and debug APK نجاح (7m38s)، وNegative permission tests نجاح (1m21s)، وRelease build rejects fake API نجاح (4m51s). الرابط: https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39707007033

**تغيير `lib/` و`packages/api_layer/lib`:** 16 ملفًا، +1205/−91. المبرر: نافذة `HistoryWindow` (`eagerLimit` ‏24، `retainLimit` ‏80، `notificationRetain` ‏120) حتى يمشي دفتر 800 سطرًا دون بناء كل الصفوف، وكتالوج `FakeLargeCatalog` يُختار بـ `FAKE_DATASET=large` في debug وprofile والاختبار. بانٍ الإصدار `fake_client_builder_release.dart` يرمي `StateError` إذا وُجد `fakeDataset` ولا يستورد الكتالوج ولا `FakeApiClient`. القوائم التي طولها 24 أو أقل تبقى شجرة كاملة، واختبار المجموعة القياسية يتوقع أقل من 24 زبونًا وبلا `lc_00000`. الأثر: أثناء مشي الدفتر تُحذف الصفوف الأقدم بعد 80 سطرًا في `_extra`، و`NotificationsController.loadOlder` يرجع عند 120 صفًا ويصفّر `nextBefore`. القوائم القصيرة لم تتغير. هذا لا يغلق نموذج الهاتف.

**P7-24 وP7-25 ومنع الاستبدال.** `test/p7_long_history_test.dart` يبني الطبقة بـ `ApiLayer.create` و`useFakeApi: true` و`FakeDataset.large` داخل `pumpFakeApp`، ثم يسجّل الدخول ويفتح `/customers/lc_00000` عبر `GoRouter`. زر `load-older` هو `TextButton` الشاشة، و`_LoadOlderLedgerState._load` ينادي `apiLayerProvider.accounts.ledger(section, id, before: cursor)`. لا تجاوز لمتحكّم الدفتر. الصفحة الأولى معروضة، و19 ضغطة تصل إلى المفتاح `ledger-pages-20`. الاختبار يستدعي `onPressed` لأن شريط الصدفة العريض يغطي مركز الزر؛ المعالج هو `_load`. الحزمة `pumpFakeApp` تستبدل أيضًا بوابة الدفع والاتصال ومخازن الإشعار، وهذه ليست متحكّم القائمة.

`packages/api_layer/test/fake_large_dataset_test.dart` يمشي `FakeApiClient` مباشرة: 20 صفحة و`seen == 800` (`ledgerLineCount`). زيادة الطول تكشف التداخل، ونقصه يكشف الفجوة. لا مجموعة معرّفات، فتبديل معرّف مع ثبات العدد يمر. الشاشة لا تجمع المعرّفات لأن `_extra` يُقص إلى آخر 80. الصفحة الأولى تبقى في قائمة الشاشة الأولى. صفوف الكتالوج تُولَّد من الفهرس `ltx_` و`_ledgerStart` يقدّم المؤشر بمقدار واحد. اختبارا الزبائن والإشعارات في الودجت يتحققان من أن المبني أقل من `pageSize` ولا يمشيان حتى آخر صفحة. مشي الإشعارات في المتحكّم يتوقف عند 120، وهو ليس مشي دفتر P7-25.

**P7-23.** القياس في `tool/measure_release_cold_start.sh`: `flutter build apk --release` مع `USE_FAKE_API=false` و`API_BASE` من `STAGING_API_BASE`. السكربت يخرج إن كان الأصل فارغًا أو `classify_origin` ليس `ok`، ولا يطبع السر. `am start -W` ثلاث عينات ووسيط `TotalTime`، ثم `flutter drive --release` لاختبار `integration_test/p7_release_cold_start_test.dart`، ثم حذف `build/app/outputs/flutter-apk` و`build/app/outputs/apk`. النسخة التي تحمل اسم المدير وكلمة المرور لا تُرفع. السطر `PHASE7 p7_23_acceptance=recorded`. إن تجاوز الوسيط 5000 مللي ثانية على جهاز أو 20000 على محاكٍ يصير خروج السكربت 1. اختبار التكامل يتخطى المضيف وأي تشغيل `USE_FAKE_API` (الافتراضي true) ويطبع `p7_23=skipped`. على الوضع الحقيقي يفشل إن نقص `API_BASE` أو اسم المدير أو كلمة المرور، ويفشل إن تجاوز زمن المنزل 60000. زمن المنزل داخل العملية رقم ثانٍ. إقلاع العملية حتى أول إطار هو `am start -W`. الجهاز D هاتف ضعيف. `release_fake_api_guard_test.dart` يتحقق أن مصدر الباني لا يحتوي `FakeApiClient` ولا `fake_large_catalog` ولا `FakeLargeCatalog` ولا `FAKE_DATASET`. لا مقياس ذاكرة (لا RSS ولا heap).

**الإطارات.** `integration_test/p7_long_history_test.dart` يطبع `PHASE7 p7_24_frame_count` و`p7_24_worst_build_ms` و`p7_24_average_build_ms` و`p7_24_acceptance=recorded`. على المضيف النتيجة `report-only`. على الجهاز والمحاكي `fail()` إذا غابت الإطارات أو تجاوزت `PerfBudget` (تجميد 500 مللي ثانية، وأسوأ إطار جهاز 32، ومتوسط جهاز 16.7). الودجت يفرض ساعة حائط أقل من 8 ثوانٍ داخل المجموعة العادية. `docs/testing/PHASE7_PERFORMANCE.md` يقول إن بوابة خضراء تبقى `recorded` في جدول البروتوكول حتى يكتب علي العتبة. سير التاريخ الطويل profile مع `USE_FAKE_API=true` و`FAKE_DATASET=large`، وهو ليس APK الإصدار.

**P7-26.** `.github/workflows/android-performance.yml` اسمه `Android performance`. ليس من فحوص طلب السحب المطلوبة. المشغّلات `workflow_dispatch` و`schedule` `30 4 * * *`. لا `pull_request` ولا `push`. التعليق في الملف يقول إن `workflow_dispatch` لا يُشغَّل حتى يصل الملف إلى الفرع الافتراضي. المصفوفة API ‏29 و33 و34، صورة Nexus 6 ‏`google_apis` ‏`x86_64`. الصلاحيات `contents: read` و`actions: write`. أسرار `STAGING_API_BASE` و`STAGING_ADMIN_USERNAME` و`STAGING_ADMIN_PASSWORD` من بيئة `staging` عبر `${{ secrets.* }}`، غير مكتوبة في المستودع. لا `google-services.json` في ملفات الطلب. بناء الحجم release مع `USE_FAKE_API=false` و`API_BASE=https://staging.example.com`؛ الوثيقة تقول إن preflight يرفض هذا المضيف وإن هذا الـ APK ليس تثبيت البروتوكول. إقلاع الإصدار يفشل مغلقًا إذا كان `STAGING_API_BASE` غير مضبوط. الرفع `if: always()` بالأسماء `phase7-apk-size` و`phase7-long-history-api-*` و`phase7-cold-start-api-*`، و`if-no-files-found: warn`.

**النموذج.** أعمدة `docs/testing/PHASE7_PERFORMANCE.md` هي أعمدة القسم ب: device، OS/API، build SHA، tester، date، step، expected، actual، pass/fail، screenshot ref، defect id. القيم Pass وFail وBlocked وNot supported. P7-23 وP7-24 يبقيان `recorded` حتى عتبة علي. النص يقول إن سجل المحاكي ليس نموذج البروتوكول، وإن الجهاز D هاتف ضعيف. الربط يغطي الخطوات 1 و9 و24 و25 من قائمة الخمس والعشرين. تمرير التاريخ الطويل على الهاتف يُبنى profile مع Fake ويُسمّى كذلك. صف الإصدار هو إقلاع الخطوة 24. الوثيقة لا تغلق DEF-002 ولا DEF-012 ولا DEF-019، وتوجّه العيب الجديد إلى `defects.md` على #12.

**merge-tree.** ضد `origin/main` `a5ca26809578dd013430dcaae78c517043e95491`: خروج 0 وشجرة `f61019fa9729779228b9ef6a3cf67a8501ed0a43`. ضد رأس #48 `e98d85e5b1a7853384ab2885717418ce00649ff3`: خروج 0 وشجرة `e0de622c4854e4c81bb7f0cd6c5d84e5d8d866fa`. لم يُنشأ دمج.

| المعرف | الحالة بعد #52 | الدليل |
|---|---|---|
| P7-23 | Partial | release و`am start -W` يطبعان `acceptance=recorded`، ويفشلان مغلقين بلا أصل staging مقبول. ميزانية هندسية إضافية (5000 / 20000 وخروج 1، وسقف منزل 60000). نموذج الجهاز فارغ. |
| P7-24 | Partial | إطارات الشاشة الحقيقية تُطبع `recorded`، وسير المحاكي profile مع Fake يفشلها إن تجاوزت الميزانية. لا مقياس ذاكرة. النموذج فارغ. |
| P7-25 | Partial | 20 صفحة عبر `load-older` و`FakeApiClient`، والمجموع 800. الشاشة تحتفظ بآخر 80 سطرًا أقدم. نصف الجهاز مفتوح. ساعة الودجت أقل من 8 ثوانٍ مفروضة. |
| P7-26 | Device-only | سير المحاكي نصف البروتوكول. أعمدة النموذج مطابقة والصفوف فارغة. التشغيل اليدوي ينتظر وصول الملف إلى `main`. |

### مراجعة #51 — البنود 4–9

الطلب [#51](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/51) مسودة. الرأس `8aec37ee29107bb33541499f9e3be595f422919d`. الأساس `main` `a5ca26809578dd013430dcaae78c517043e95491`. ثلاثة التزامات. 11 ملفًا، كلها اختبارات و`dart_test.yaml`. فرق `lib/` و`packages/api_layer/lib` فارغ. لم يُدمج. هذه المراجعة لم تدفع إلى فرعه. لا توقيع.

**الحكم:** yes with notes. DEF-020 وDEF-021 وDEF-022 مفتوحة ومانعة لمساراتها. التالي الحر DEF-023.

CI التشغيل `39708173062` أخضر على هذا الرأس: Analyze, test, and debug APK، وNegative permission tests، وRelease build rejects fake API.

`tool/check.sh` على الرأس، شجرة `/tmp/wt-51`، خروج 0. الأرقام تطابق ادعاء الوصف:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 4.2s)` |
| `flutter test --exclude-tags screenshots` | **410/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.5s)` |
| `flutter test` في `packages/api_layer` | **153/0** |
| `--tags permissions-negative` التطبيق | **32/0** |
| `--tags permissions-negative` الحزمة | **26/0** |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

42 اختبارًا جديدًا. أسماؤها موجودة في الملفات. 41 اسمًا مذكور في وصف الطلب. اسم ودجت DEF-020 `DEF-020 a partial payment above the remaining balance is stored` موصوف في قسم العيوب وليس في جدول الأسماء. وسم المكتبة `@Tags(['permissions-negative'])` على `test/permissions/phase7_role_denials_permission_negative_test.dart` و`packages/api_layer/test/permissions/phase7_status_order_permission_negative_test.dart`. حالات 403/401 داخل هذين الملفين موسومة. `known-bug` و`pending-decision` داخل التشغيل الافتراضي.

**منع الاستبدال.** لا `homeDashboardProvider.override` ولا استبدال متحكّم الاستلامات ولا حوار السداد ولا مزوّد جلسة ولا مزوّد صلاحية قسم في الملفات الجديدة. `pumpFakeApp` يبني `ApiLayer.create(useFakeApi: true)` ويستبدل `apiLayerProvider` بهذه الطبقة، ومعها بوابة الدفع والاتصال ومخازن الإشعار. هذا الحزام القائم. `signIn` يكتب `username-field` و`password-field` ويستدعي `login-button.onPressed`.

- **P7-05.** خمسة أدوار من نموذج الدخول. `_expectSections` يمر على `SectionKey.values`. الموظف الممنوع في ملف السالب يفتح `/treasury` و`/masraweya` و`/companies` ويرى `ForbiddenPane`.
- **P7-06.** الاختبار الرئيسي يفتح `HomeDashboard.screenKey` ثم customers وcollections وcompanies وlibyan-deposits وegyptian-deposits وmasraweya وpurchases وtreasury وreports. هذه قيم `SectionKey` التسع. اختبارات الإجماليات والإشعارات وصفر الدين موسومة `pending-decision` ولا تغلق سؤالًا زائدًا.
- **P7-07.** يثبت جمل DEF-012 ولا يغلق الصف. الوسم `known-bug`.
- **P7-08.** غير موجود في الطلب.
- **P7-10.** حوار `add-payment` ثم `save-movement` ثم `full-payment` على `c_55`. أثناء `pauseMutations` النقرة الثانية لا تضيف `requestId`. الرأس 220 ثم 0. الأمانات الليبية بلا زر سداد كامل.
- **P7-12.** `approve-sb_1` و`reject-sb_9` ثم `collections.overview()`. الموظف بلا أزرار و`decide` يرمي 403 `FORBIDDEN`. تعارض الإصدار على الاستلامات يبقي الزر ويعيد الجلب. DEF-002 موسوم `pending-decision` وليس Pass.
- **P7-14.** الإرسال من الحوارين حقيقي. النظرة لا تضم الصف. ربط `ur_1` يخزّن `customerId` والرصيد يبقى 320.

ملاحظة واحدة على الاستبدال: `a 403 is not retried by the buildAppRoot callback` ينسخ دالة إعادة المحاولة من `lib/main.dart` ويستبدل `apiLayerProvider` فقط. لا يضخ `buildAppRoot`. ليس إغلاقًا لبند شاشة.

**العيوب على `main` `a5ca268`.** مسبار محلي 4/4 ثم حُذف. لم يُلتزم.

| المعرف | الشدة | التصنيف | التأكيد |
|---|---|---|---|
| DEF-020 | عالية | Blocking | العميل والخادم التجريبي يقبلان 400 على 320. الرأس `-80 د.ل` والمخزَّن −80. العقد يكلّف الخادم بحساب المبلغ ولا ينص على سقف. الحارس على الحوار مطلوب. |
| DEF-021 | عالية | Blocking لإغلاق P7-14 | المساران سُجّلا. النظرة تبقى `sb_1` `sb_2` `ur_1` `ur_2`. الإبطال على الشاشة حقيقي والسقوط في `_mutateCollections`. |
| DEF-022 | عالية | Blocking لحوار السداد | بعد 409 الجملة هي نص الخادم. الرأس يبقى `320 د.ل` بعد المغادرة. المخزَّن 319. |

**merge-tree.** ضد `main` `a5ca268`: خروج 0 وشجرة `2174c58cc41f7facff8e07a5a8fff38d5c265457`. ضد #52 `dc713ffd09442d0499ab2270ef88ce7f5f47a1a1`: خروج 0 وشجرة `d22b7b27cc9d65498b50e4e7168542ea6768e606`. لا ملف مشترك في الفرقين. لم يُنشأ دمج.

| المعرف | الحالة بعد #51 |
|---|---|
| P7-05 | Covered |
| P7-06 | Covered |
| P7-07 | مفتوح (DEF-012) |
| P7-08 | لم يُضف |
| P7-09 | Staging، لم يُغلق |
| P7-10 | Partial (DEF-020، DEF-022) |
| P7-11 | Staging، لم يُغلق |
| P7-12 | Covered |
| P7-13 | Staging، لم يُغلق |
| P7-14 | Partial (DEF-021) |

البندان 4 Covered. البنود 5 و6 و7 و8 و9 Partial. DEF-002 وDEF-012 وDEF-019 على حالها.

### إعادة اختبار #51 — الرأس `e34504c`

الطلب [#51](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/51) ما زال مسودة. الرأس `e34504c5ee28bca367575ffe9ba2f0edde2817e0`. السابق `8aec37ee29107bb33541499f9e3be595f422919d`. الأساس `main` `a5ca268`. الفرع `cursor/phase7-tests-3169`. التزام واحد فوق المراجعة الأولى: «Use the real buildAppRoot retry callback for the 403 test». الفرق عن `8aec37e` ملف اختبار واحد، +30/−22. فرق `lib/` و`packages/api_layer/lib` فارغ مقابل `8aec37e` ومقابل `main`. مقابل `main` ما زال 11 ملف اختبار، +1451. لم يُدمج. هذه الجولة لم تدفع إلى فرعه. لا توقيع.

**الحكم:** yes with notes. الأعداد لم تتغير. P7-10 يبقى Partial. DEF-020 يبقى Open ومانعًا.

CI التشغيل [39710370296](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39710370296) أخضر على هذا الرأس: Analyze, test, and debug APK، وNegative permission tests، وRelease build rejects fake API. الالتزام في التشغيل هو `e34504c`.

`tool/check.sh` على `/tmp/wt-51b`، خروج 0. الأرقام تطابق الادعاء:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 5.7s)` |
| `flutter test --exclude-tags screenshots` | **410/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 3.2s)` |
| `flutter test` في `packages/api_layer` | **153/0** |
| `--tags permissions-negative` التطبيق | **32/0** |
| `--tags permissions-negative` الحزمة | **26/0** |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

**جدول الوصف.** صف DEF-020 صار في جدول المصفوفة في وصف الطلب: `DEF-020 a partial payment above the remaining balance is stored`، والنتيجة المكتوبة «Known bug. 400 on a 320 balance is stored as -80. Does not close a cap.» الاختبار في `test/phase7_payments_test.dart` يتوقع الرأس `-80 د.ل` بعد إدخال 400 على `c_55`، والوسم `known-bug`. تعليق `dart_test.yaml` يقول إن الوسم يثبت السلوك الحالي وليس Pass. التشغيل الافتراضي يضم الوسم، فالاختبار داخل الـ 410 الناجحة. هذا توثيق للعيب المفتوح، لا إغلاق لمتطلب السقف. P7-10 يبقى Partial بسبب DEF-020 وDEF-022. البند 7 يبقى Partial.

**منع الاستبدال في اختبار 403.** `a 403 is not retried by the buildAppRoot callback` يستدعي `buildAppRoot` ويقرأ الحقل `retry` من `ProviderScope` الراجع. الدالة الممرَّرة إلى `ProviderContainer` هي تلك الدالة، لا نسخة منسوخة من فرع `lib/main.dart`. الاستثناء يُرمى من `FutureProvider` محلي، والنداء مرة واحدة عند 403. نفس الدالة تُستدعى مباشرة: 401 جلسة و403 يرجعان `null`، و404 يطابق `ProviderContainer.defaultRetry`. البديل هو `ApiLayer.create(useFakeApi: true)` و`MemoryDeviceTokenStore` لأن توقيع الجذر يطلبهما. `CompanyApp` لا يُضخ. الاختبار في جدول «اختبارات أخرى» وليس صف إغلاق. ملاحظة النسخ في مراجعة `8aec37e` انتهت على هذا الرأس.

**merge-tree.** خروج 0. لم يُنشأ دمج. لا ملف مشترك مع #48 أو #49 أو #50 أو #52.

| الطرف | الشجرة |
|---|---|
| `main` `a5ca26809578dd013430dcaae78c517043e95491` | `9da14af43073e3fc7a67a8ee693e087fe9c2f20d` |
| #48 `f376b9bb5a0d6a9932f55957131794fbf37d16bc` | `b0da38ec9a60640bf442bff6c829ab6fe68245a0` |
| #52 `f8f7812d203bd09fe0c5c124748d043694f3f5f9` | `410b8e52346c38bfa8ac3aa7caa4391d4f19e824` |
| #49 `546a62342eb78140d550abdfd138de5e0821c77a` | `8406bbc3e892c307f50c6a2c55b91f5c345a411e` |
| #50 `b7900a2c555aa3cccb3b562ed5f33b6f787fd527` | `71ad271eca01245934b761f1369b280b19123e87` |

| المعرف | الحالة بعد إعادة #51 |
|---|---|
| P7-05 | Covered |
| P7-06 | Covered |
| P7-07 | مفتوح (DEF-012) |
| P7-08 | لم يُضف |
| P7-10 | Partial (DEF-020، DEF-022) |
| P7-12 | Covered |
| P7-14 | Partial (DEF-021) |

البند 4 يبقى Covered. البنود 5–9 تبقى Partial. التالي الحر DEF-026.

### إعادة اختبار #52 — الرأس `f8f7812`

الطلب [#52](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/52) ما زال مسودة. الرأس `f8f7812d203bd09fe0c5c124748d043694f3f5f9`. الأساس `main` `a5ca26809578dd013430dcaae78c517043e95491`. الفرع `cursor/phase7-performance-cc01`. 34 ملفًا. لم يُدمج. هذه الجولة لم تدفع إلى فرعه ولم تغيّر كود الإنتاج. لا توقيع. لم يُفتح عيب. التالي الحر DEF-023. قسم «مراجعة #52» أعلاه يبقى وصف الرأس `dc713ff`.

**الحكم:** yes with notes.

CI التشغيل `39709190829` أخضر على هذا الرأس: Analyze, test, and debug APK، وNegative permission tests، وRelease build rejects fake API. الرابط: https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39709190829

`tool/check.sh` على شجرة محلية `/tmp/wt-52b` منفصلة عند هذا الرأس. رمز الخروج 0. لم يُشغَّل محاكٍ.

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 3.7s)` |
| `flutter test --exclude-tags screenshots` | **380/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.3s)` |
| `flutter test` في `packages/api_layer` | **155/0** |
| `--tags permissions-negative` التطبيق | **27/0** |
| `--tags permissions-negative` الحزمة | **23/0** |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

**القص.** الالتزام `22d71430a861f30e03940c7238de2678953c2029` يعزل العلم. `HistoryWindow.trimEnabledFromEnvironment` هو `bool.fromEnvironment('HISTORY_WINDOW_TRIM', defaultValue: false)`، و`trimEnabled` يبدأ منه. الاختبارات تعيّن الحقل الثابت وتعيده في `tearDown`. لا مفتاح في الواجهة. `docs/testing/PHASE7_PERFORMANCE.md` يعلّق القرار عند علي.

يُضبط بـ `--dart-define=HISTORY_WINDOW_TRIM=true` وقت الترجمة، أو بتعيين الاختبار للحقل الثابت. لا يمرّره `.github/workflows/ci.yml` ولا `android-performance.yml` ولا `tool/measure_release_cold_start.sh` ولا `tool/android_performance_emulator_test.sh` ولا `tool/check_release_rejects_fake_api.sh`. بناء release بلا هذا التعريف يبقى مطفأً. لا يُفعَّل من سر أو من ملف إعدادات في وقت التشغيل. إضافته صراحة إلى أمر الترجمة تشغّله في ذلك البناء، بما فيه release.

مع العلم مطفأ، `P7-25 walks the long ledger to the last page` يتوقع `trimEnabled` كاذبًا و19 ضغطة على `load-older` و`ledger-pages-20` و`ledger-retained-760`. 760 هي `(20 − 1) × 40`. الصفحة الأولى خارج `_extra`. `_load` يقص فقط إذا `trimEnabled` والطول فوق `retainLimit`، فالصفوف المحمّلة لا تُسقط. الإشعارات: `load-older-notifications` غائب والمفتاح `notifications-retained-40`. `loadOlder` يجعل السقف `null` حين العلم مطفأ، فلا قص عند 120. الشاشة لا تمشي صفحات الإشعار الأقدم لأن الزر مخفي، وتبقى الصفحة الأولى كما كتبت الوثيقة.

مع العلم مشغّل داخل الاختبار: الدفتر `ledger-retained-80` وما زال `ledger-pages-20`. الإشعارات `notifications-retained-120`.

**رجوع واجهة الاستلامات.** `542723878d2c0c5989b6fa01ba0ba0591e830999` أرجع `lib/features/collections/collections_screen.dart` و`packages/api_layer/lib/data/repositories/collections_repository.dart`. المساران غائبان من فرق `a5ca268..f8f7812`.

ملفات الإنتاج الباقية مقابل `a5ca268`: 15 ملفًا، +1111/−83 مع `pubspec.yaml`.

| الملف | السبب |
|---|---|
| `lib/features/accounts/account_list_screen.dart` | قائمة كسولة. العلم مطفأ يعيد مؤشر الصفحة الأولى. العلم مشغّل يبقي آخر 80. |
| `lib/features/accounts/ledger_screen.dart` | `load-older` الحقيقي، وقص مشروط، ومفتاح `ledger-retained-`. |
| `lib/features/notifications/notifications_screen.dart` | قائمة كسولة. زر الأقدم يظهر فقط والعلم مشغّل. |
| `lib/performance/history_window.dart` | الحدود والعلم. الافتراضي مطفأ ومعلّق عند علي. |
| `lib/performance/perf_budget.dart` | أرقام هندسية. ليست عتبة قبول. |
| `lib/performance/perf_surface.dart` | المضيف والجهاز والمحاكي. المضيف لا يفشل ميزانية الإطار. |
| `lib/state/notification_providers.dart` | سقف 120 فقط والعلم مشغّل. |
| `lib/state/section_providers.dart` | `retainLimit` اختياري على إلحاق الكروت. |
| `packages/api_layer/lib/api_layer.dart` و`api_client_factory.dart` و`fake_client_builder.dart` | توصيل `FakeDataset`. |
| `fake_client_builder_release.dart` | يرمي إذا وُجد `fakeDataset` ولا يبني العميل التجريبي. |
| `fake_api_client.dart` و`fake_large_catalog.dart` | كتالوج 800 سطر لـ debug وprofile والاختبار. |
| `pubspec.yaml` | `vm_service: 15.4.0` تحت `dev_dependencies` فقط. |

`pubspec.lock` ينقل `vm_service` من اعتماد عابر إلى `direct dev`. ليس اعتماد إصدار.

**مجموعة المعرّفات.** `b0db1617384bf6f6a7e839c5a5ce587a95428f8c` يغيّر `packages/api_layer/test/fake_large_dataset_test.dart` فقط. `_walkLedger` ينادي `FakeApiClient.get`، يرفض التكرار، ويتوقع `ltx_00000`..`ltx_00799` و`seen == 800` وصفحات لا تزيد على 20. هذا ليس الشاشة ولا المتحكّم. ودجت `test/p7_long_history_test.dart` يضغط `load-older` ثم `_LoadOlderLedgerState._load` ثم `apiLayerProvider.accounts.ledger`. `pumpFakeApp` يبني `ApiLayer.create(useFakeApi: true)`. الودجت يثبت `ledger-pages-20` والعدد 760 أو 80. لا يجمع `ltx_`. القائمة الكسولة لا تبني كل المفاتيح، فتبديل معرّف مع ثبات الطول يمر على الشاشة. الملاحظة تبقى.

**الميزانيات.** `0a3a0fe` يسمّيها engineering proposal في التعليقات والسكربتات و`tool/phase7_summary.py` وسير العمل. `p7_23_acceptance` و`p7_24_acceptance` يبقيان `recorded`. سكربت الإقلاع ما زال يخرج 1 فوق 5000 على جهاز أو 20000 على محاكٍ، والنص يقول إن هذا ليس Pass أو Fail للبروتوكول. إطارات الجهاز والمحاكي ما زالت `fail()`. ساعة الودجت أقل من 8 ثوانٍ داخل المجموعة العادية، وسبب التوقع ينص أنها اقتراح هندسي. مسار المضيف للإطارات يطبع `report-only` ويرجع. عتبة علي لم تُكتب.

**الذاكرة.** `722f1ac` و`f8f7812`. `tool/android_performance_emulator_test.sh` يبني profile مع `PHASE7_SAMPLE_MEMINFO=true` و`USE_FAKE_API=true` و`FAKE_DATASET=large` وبلا `HISTORY_WINDOW_TRIM`. يلتقط `adb shell dumpsys meminfo` قبل `PHASE7 p7_24_scroll_begin=1` وبعد `p7_24_scroll_end=1`. `tool/phase7_meminfo.py` يقرأ `TOTAL PSS` و`TOTAL RSS`. غياب RSS يصير `unavailable`. النوع `report-only`. فشل `dumpsys` لا يغيّر رمز الخروج، والخروج هو خروج `flutter drive`. اختبار التكامل يطبع `p7_24_dart_heap_before_bytes` و`p7_24_dart_heap_after_bytes` و`p7_24_memory=report-only` و`p7_24_acceptance=recorded`. غياب عنوان VM service يطبع `unavailable` والاختبار يمر. `phase7_summary.py` يضع الأسطر في `phase7-long-history-api-*.md` بعمود `recorded`. الرفع `if: always()` للسجل وهذا الملف. هذه الجولة لم تشغّل المحاكي. `check.sh` على المضيف خرج 0 ولا يقيس الذاكرة.

**merge-tree.** لم يُنشأ دمج. لا ملف مشترك مع فرق #51.

| الطرف | الشجرة | الخروج |
|---|---|---|
| `main` `a5ca26809578dd013430dcaae78c517043e95491` | `6ce8c452b4a3d60b1afe462673c3127497009521` | 0 |
| #51 `8aec37ee29107bb33541499f9e3be595f422919d` | `c2a01d71145c469b6fccd7c50532da3f2a576fe6` | 0 |
| #48 `afdeb837b3ede7c9fd1d6808422a2388cf5a60c8` | `e68f69d95b5a6dcc3a2369c673dd55d7f22ec03d` | 0 |

| المعرف | الحالة بعد إعادة الاختبار | الدليل |
|---|---|---|
| P7-23 | Partial | الاقتراح الهندسي مُسمّى والعمود `recorded`. السكربت المنفصل ما زال يخرج 1 فوق الرقم. النموذج فارغ. |
| P7-24 | Partial | الإطارات `recorded`. PSS وRSS وheap تقرير في أثر السير. المضيف لا يفشل بسبب الذاكرة. النموذج فارغ. |
| P7-25 | Partial | العلم مطفأ يبقي 760 سطرًا أقدم عبر المتحكّم. المجموعة الدقيقة على مشي `FakeApiClient` لا على الشاشة. نصف الجهاز مفتوح. |
| P7-26 | Device-only | النموذج فارغ. عينات الذاكرة في أثر المحاكي ليست نموذج الهاتف. |

البندان 17 و18 يبقيان Partial. البند 19 يبقى Device-only. الملخص: Covered ‏3، Partial ‏15، Device-only ‏1.

### مراجعة #49 — الإشعارات والسمة والمقاس

الطلب [#49](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/49) مسودة. الرأس `621f01b172f4dbbccc028bbe3a356d09d5339bf8` وليس أحدث من ذلك. الأساس `main` `a5ca26809578dd013430dcaae78c517043e95491`. الفرع `cursor/phase7-ui-tests-e77f`. 7 ملفات تحت `test/`، +1348/−2. فرق `lib/` فارغ. لم يُدمج. هذه المراجعة لم تدفع إلى فرعه. لا توقيع.

**الحكم:** yes with notes. عند هذا الرأس #49 لم يُعد ترقيم عيوب التباين. ما يسميه DEF-020 وDEF-021 وDEF-022 صار في السجل DEF-023 وDEF-024 وDEF-025 بالترتيب نفسه. التالي الحر DEF-026. الملحق أدناه يعيد فحص الادعاءات على الرأس الأحدث `546a623`.

CI التشغيل `39709794563` أخضر على هذا الرأس.

`tool/check.sh` على `/tmp/wt-49`، خروج 0:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 4.1s)` |
| `flutter test --exclude-tags screenshots` | **401 نجح، 4 تُخطى، 0 فشل** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.3s)` |
| `flutter test` في `packages/api_layer` | **150/0** |
| `--tags permissions-negative` التطبيق | **27/0** |
| `--tags permissions-negative` الحزمة | **23/0** |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

التخطي الأربعة: `DEF-019 known failure` وثلاثة تخطيات تباين ما زالت تحمل أرقام السجل القديمة.

**ما يغطيه.** P7-16 وP7-17 وP7-18 وP7-22 تبقى Partial. لا صف يصير Covered. الجهاز ما زال مفتوحًا.

- **P7-16.** حوار API 33 يرسل مرة عبر `DeviceTokenRegistrar` الحقيقي بعد الموافقة. لافتة المقدمة ونص القفل `إشعار جديد` بلا اسم أو مبلغ أو هاتف أو رمز، والنقرة تفتح الاستلام وتنقص الشارة مرة. النقرة الثانية لا تنقصها. الصينية تُلتقط على قناة `app/system_tray` بعد تسجيل المكوّن الحقيقي، لا عبر ملصق بديل.
- **P7-17.** استطلاع واحد والحالة `paused` ينشر سطر القفل ويبقي الشارة على عدد الخادم. اختبار القتل يثبّت الجملة `Not supported` وأن `FcmPushTransport` بلا رمز. العملية لا تُقتل.
- **P7-18.** `pumpFakeApp(sdkInt:)` لـ 29 بلا حوار ومع إرسال واحد عند الدخول، ولـ 33 و34 حوار ثم إرسال بعد الموافقة. هذا ليس جهاز API 29 أو 33 أو 34.
- **P7-22.** تدوير 320×568 و430×932 للدخول والرئيسية والاستلامات ودفتر `c_55` والإشعارات. `expectQuiet` يلتقط استثناء الفيض. نصف الجهاز مفتوح.

**الودجت والسمة.** `pumpFakeApp` يضخ `CompanyApp` لا `buildAppRoot`. المسجّل في اختبارات P7-16 هو `DeviceTokenRegistrar` والفتاحة `OpenerNotificationSeam`. الاستبدال فوق الحزام: `FakeApiClient` داخل `pumpFakeApp`، و`FakePushTransport` في اختبارات الإرسال، وخدمة إذن مزيّفة، و`sdkInt`، ومخازن ذاكرة، وجدولة خلفية لا تفعل شيئًا. اختبار لافتة إضافي في `phase7_notifications_ui_test.dart` يستبدل `foregroundNotificationsProvider`. السمة من `buildAppTheme` وزر التبديل، إلا اختبار `ThemeMode.system` الذي يستبدل `themeModeProvider`.

**التباين.** `unreadableText` يقيس كل `Text` بحد واحد **3:1**. لا يفرّق نصًا عاديًا (4.5:1) عن نص كبير أو مكوّن واجهة (3:1)، ولا يفحص غير النص. الاختبارات المتخطاة ترجع قبل القياس. المسبار المحلي على هذا الرأس، ثم حُذف، طبع النسب المرسومة:

| الزوج | النسبة | المعرّف في السجل |
|---|---|---|
| `#eab600` على `#e5edf6` (`ع` و`VIB`) | 1.59:1 | DEF-023 |
| `#172723` على `#102a26` (`مدير النظام`) | 1.02:1 | DEF-024 |
| `#247763` على `#172333` | 2.94:1 | DEF-025 |
| `#247763` على `#1a2c24` | 2.72:1 | DEF-025 |
| `#087a50` على `#172333` | 2.95:1 | DEF-025 |

الخمسة تحت 3:1 و4.5:1. العلامة `ع` حجم 40 ووزن 800، فحد النص الكبير 3:1، و1.59 تفشله. أزواج أخرى بين 3 و4.5 (مثل `#6d7c77` على الأبيض 4.38:1 و`#247763` على `#0d1522` ‏3.39:1) تمر من حد الطلب ولا تأخذ معرّفًا جديدًا.

**ذهبي ودلالات.** لا `matchesGoldenFile`. `pumpAndSettle` يطلب `sendSemanticsUpdate` ولا يوجد توقع `Semantics`.

**الإنتاج.** لا ملف تحت `lib/` أو `packages/api_layer/lib`. التغيير في الاختبارات ووسيط `sdkInt` في `test/support/pump_app.dart`.

**merge-tree.** خروج 0. لم يُنشأ دمج. لا ملف مشترك مع #50.

| الطرف | الشجرة |
|---|---|
| `main` `a5ca26809578dd013430dcaae78c517043e95491` | `b0d8371886e082d2e36379073d852d473ea31a7e` |
| #48 `ac4ca04e114300ca895de100e1609cc970e0efe3` | `a0db2867ca2f221c960294ba748228e448e63998` |
| #51 `e34504c5ee28bca367575ffe9ba2f0edde2817e0` | `992c306f4a0f100e6bab99ae97bde6ceb748ae22` |
| #52 `f8f7812d203bd09fe0c5c124748d043694f3f5f9` | `e7569c3912cad9748fc9201fe2f6ebbd729f75ea` |

| المعرف | الحالة بعد #49 |
|---|---|
| P7-16 | Partial |
| P7-17 | Partial |
| P7-18 | Partial |
| P7-22 | Partial |

البند 10 Partial. البند 14 يبقى Covered. البند 16 Partial. الملخص لم يتغير.

### ملحق مراجعة #49 — ادعاءات `621f01b`

أُعيد فحص ادعاءات المؤلف على `621f01b172f4dbbccc028bbe3a356d09d5339bf8` من الشجرة، لا من الوصف. أثناء الملحق تحرّك الفرع إلى `546a62342eb78140d550abdfd138de5e0821c77a` («Renumber the contrast skips to DEF-023, DEF-024, and DEF-025»). الفرق عن `621f01b` ملف اختبار واحد، +20/−13، بلا `lib/`. لم يُدفع إلى فرع #49. لا دمج. لا توقيع. `tool/check.sh` لم يُعد تشغيله على الرأس الجديد.

**العد.** أسماء P7-16 وP7-17 وP7-18 وP7-22 لم تتغير بين الرأسين.

| الادعاء | الموجود في الشجرة |
|---|---|
| P7-16 ×2 | اختبارا `testWidgets`: الحوار على API 33، ثم اللافتة ونص القفل والنقرة |
| P7-17 ×2 | `testWidgets` للاستطلاع والحالة `paused`، و`test` (ليس ودجت) لجملة القتل |
| P7-18 ×3 | `testWidgets` لـ `sdkInt` 29 و33 و34 عبر وسيط `pumpFakeApp` |
| P7-22 ×2 | `testWidgets` لتدوير 320×568 و430×932 |

المسجّل في اختبارَي P7-16 وفي اختبارات P7-18 الثلاثة هو `DeviceTokenRegistrar`. الفتاحة في لافتة P7-16 هي `OpenerNotificationSeam`. قتل العملية موثّق `Not supported`: الثابت والجملة في التعليق، و`FcmPushTransport.currentToken()` يرجع فارغًا، والعملية لا تُقتل. اختبارات الأسماء ودجت ما عدا اختبار القتل. بنود الجهاز تبقى مفتوحة، والحالات Partial كما في الجدول أعلاه.

**ما لا يطابق «FakeApiClient وFakePushTransport فقط».** `pumpFakeApp` يضخ `CompanyApp` لا `buildAppRoot`، ويستبدل مخازن الذاكرة وجدولة لا تفعل شيئًا ومنفذ الاتصال وخدمة الإذن و`sdkInt`. P7-16 وP7-18 يمرران `FakeNotificationPermissionService`. الصينية تُلتقط على قناة الأسلوب بعد `AndroidFlutterLocalNotificationsPlugin.registerWith()`. اختبار القتل يبني `FcmPushTransport` ولا يستخدم النقل المزيّف.

**النسب، محسوبة من جديد.** بايتات sRGB من `lib/ui/theme.dart`، وصيغة WCAG 2.x (عتبة القناة 0.03928). عتبة الاختبار 0.04045 تعطي الأرقام نفسها لهذه الأزواج. التقريب إلى منزلتين:

| الزوج | النسبة |
|---|---|
| `#EAB600` على `#E5EDF6` | 1.588613 → **1.59:1** |
| `#172723` على `#102A26` | 1.022427 → **1.02:1** |
| `#247763` على `#172333` | 2.939585 → **2.94:1** |
| `#247763` على `#1A2C24` | 2.723645 → **2.72:1** |
| `#087A50` على `#172333` | 2.951710 → **2.95:1** |

1.59 و1.02 يطابقان الادعاء. «حوالي 2.9» يطابق 2.94 و2.95 ولا يطابق 2.72. الخمسة تحت 3:1 و4.5:1. `ع` حجم 40 ووزن 800، و`VIB` حجم 18 ووزن 800؛ 1.59 يفشل حد النص الكبير وحد النص العادي معًا.

**التخطي ليس Pass.** عند `621f01b` الاختبارات الثلاثة تنادي `markTestSkipped` ثم `return` قبل القياس، والأسماء ما زالت DEF-020 وDEF-021 وDEF-022. عند `546a623` الأسماء صارت DEF-023 وDEF-024 وDEF-025 والعلم ما زال يتخطاها قبل القياس. تشغيل `flutter test test/phase7_theme_ui_test.dart --name DEF-02` على `546a623`: `+0 ~3`، والرسائل `DEF-023 known failure` و`DEF-024 known failure` و`DEF-025 known failure`، وخروج 0. العدّاد صفر نجاح وثلاثة تخطي. ليست Pass وليست فشل مجموعة. السجل يبقي DEF-023 وDEF-024 وDEF-025 **Open**. التالي الحر DEF-026.

**DEF-019 على الدمج المحلي.** نص الاختبار في `phase7_notifications_ui_test.dart` واحد بين `621f01b` و`546a623`، والعلم `_skipDef019 => true` في الرأسين. أُوقف العلم في شجرة محلية ثم أُعيد. لم يُلتزم ولم يُدفع.

- `621f01b` وحده: خروج 1. الدخول يرسل `phase7-device-token` مرة، وأول فتح لـ `/notifications` يرسل الرمز نفسه مرة ثانية. الفشل عند التوقع الثاني.
- دمج محلي بلا التزام لـ `546a623` و`b7900a2c555aa3cccb3b562ed5f33b6f787fd527`: الدمج التلقائي بلا تعارض، ثم `+1` وخروج 0. الفتح الأول لا يعيد الرمز. الدمج أُلغي بعد التشغيل.
- `api_error code=REQUEST_FAILED` طُبع في التشغيلين ولم يغيّر الحكم.
- الاختبار المعطّل يستخدم `pumpFakeApp` لا `buildAppRoot`. DEF-019 يبقى **Open على `main`**.

**merge-tree لـ `546a623`.** خروج 0. لم يُنشأ دمج. ضد `main` `a5ca268` الشجرة `2c41c7f840be70ca852f3cd29999d1bdb7fa51b4`. ضد #50 `b7900a2` الشجرة `9c64ccabaeff4ef727b22c776de89b32cf3ca509`.

### مراجعة #50 — تكرار تسجيل الجهاز (DEF-019)

الطلب [#50](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/50) مسودة. الرأس `b7900a2c555aa3cccb3b562ed5f33b6f787fd527`. الأساس `main` `a5ca268`. الفرع `cursor/def-019-registrar-dedup`. 6 ملفات، +396/−10. لم يُدمج. هذه المراجعة لم تدفع إلى فرعه ولم تغيّر كوده. لا توقيع.

**الحكم:** yes with notes. DEF-019 يبقى **Open على `main`**. المسبار على الفرع نجح.

CI التشغيل `39706304193` أخضر.

`tool/check.sh` على `/tmp/wt-50`، خروج 0:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 3.8s)` |
| `flutter test --exclude-tags screenshots` | **376/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.5s)` |
| `flutter test` في `packages/api_layer` | **150/0** |
| `--tags permissions-negative` التطبيق | **27/0** |
| `--tags permissions-negative` الحزمة | **23/0** |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

**المسار.** `registerIfReady` يتذكر `(token, userId)` في الذاكرة وفي `DeviceTokenStore`. الزوج نفسه لا يُرسل. رمز جديد أو مستخدم جديد أو فشل سابق أو `forget` يُرسل. `onTokenRefresh` يستدعي التسجيل والجلسة مفتوحة. `toString` على التسجيل المحفوظ لا يطبع الرمز.

اختبارات الطلب تبني `DeviceTokenRegistrar` و`HttpDeviceRegistrationClient` و`FakePushTransport` و`ApiLayer.create` مباشرة. لا `buildAppRoot` ولا فتح `/notifications`.

المسبار المحلي، ثم حُذف، ضخ `buildAppRoot` بإذن ممنوح وAPI 33. نوع المسجّل `DeviceTokenRegistrar`. الاستبدال: `FakePushTransport` و`FakeApiClient`، مع مخزن ذاكرة وجدولة لا تفعل شيئًا ومنفذ اتصال ثابت كما في اختبارات الجذر القائمة. الدخول أرسل مرة (`mobilePushRegisterPosts == 1`). أول فتح لـ `/notifications` بقي 1. `setToken` إلى رمز آخر جعل العدد 2.

**401 و419.** الفرق لا يمس `auth_interceptor.dart` ولا `error_mapper.dart` ولا `cookie_csrf_auth_strategy.dart`. مسار الجهاز المقترح يأتي بعد `_ensureSession` للطلب المصادق. مجموعة الـ 150 و27 و23 على هذا الرأس خضراء، وفيها انتهاء الجلسة عند 401 المصادق و419 غير CSRF، وتجديد CSRF مرة واحدة.

**الإنتاج.** `device_token_registrar.dart` و`device_token_store.dart` و`push_providers.dart` و`push_transport.dart` و`fake_api_client.dart` (عدّاد نجاح التسجيل فقط). هذا إصلاح الطلب، لا تغيير من هذه المراجعة.

**merge-tree.** خروج 0 ضد `main`، و#48 `ac4ca04`، و#49 `621f01b`، و#51 `e34504c`، و#52 `f8f7812`، و#53 `08e6b13`، و#54 `ae54838`، و#55 `fc140f9`. الشجرات: `559775c0` و`9734a5c5` و`a2c2944d` و`71ad271e` و`24ebb634` و`a8469fdc` و`367f17eb` و`0380aa74`. `fake_api_client.dart` مشترك مع #52 و#53 والدمج بلا تعارض. لا ملف مشترك مع #49. لم يُنشأ دمج.

DEF-019 لا يُغلق على `main` قبل الدمج. لا عيب جديد. التالي الحر يبقى DEF-026.

---

### مراجعة #56 — الجلسة والمرونة

الطلب [#56](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/56) مسودة. الرأس `9c0fa4ff81763f5496babc97082a81dd2f166479`. الأساس `main` `a5ca26809578dd013430dcaae78c517043e95491`. الفرع `cursor/phase7-api-session-resilience-tests`. التزام واحد: «Add phase 7 API session and resilience tests». 14 ملفًا، +2479/−7. لم يُدمج. هذه المراجعة لم تدفع إلى فرعه ولم تغيّر كوده. لا توقيع. لا عيب جديد. التالي الحر DEF-026. رأس #50 المستخدم في الدمج هو `b7900a2c555aa3cccb3b562ed5f33b6f787fd527`.

**الحكم:** yes with notes. البنود 1 و2 و3 و11 و12 و13 تبقى Partial. البند 19 يبقى Device-only. P7-03 بلا تغطية. وضع الطيران يدوي. DEF-020 وDEF-022 يبقيان مفتوحين.

CI التشغيل [39711134480](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39711134480) أخضر على هذا الرأس: Analyze, test, and debug APK، وNegative permission tests، وRelease build rejects fake API. العنوان «Add phase 7 API session and resilience tests». الالتزام في التشغيل هو `9c0fa4f`.

`tool/check.sh` على `/tmp/wt-56`، خروج 0. الأرقام تطابق وصف الطلب:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 6.4s)` |
| `flutter test --exclude-tags screenshots` | **376/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.8s)` |
| `flutter test` في `packages/api_layer` | **197 ناجح، و1 تخطي (`~1`)** |
| `--tags permissions-negative` التطبيق | **27/0** (7 ملفات) |
| `--tags permissions-negative` الحزمة | **30/0** (7 ملفات) |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

**الأسماء والربط.** مجموعات P7-01 وP7-02 وP7-04 وP7-19 وP7-20 وP7-21 تحمل المعرف في اسم الاختبار، ووصف الطلب يربط كل مجموعة بالبند. العدد: P7-01 واحد، وP7-02 ثمانية (7 وحدة + ودجت)، وP7-04 سبعة، وP7-19 اثنان، وP7-20 ثمانية في سياسة الإعادة واثنان في المستودع وودجت واحد، وP7-21 اثنان في المستودع وودجت واحد. ملف `api_contract_test.dart` واحد وعشرون اختبارًا أسماؤها `P7 contract ...` بلا رقم مصفوفة. الوصف يضعها في جدول العقد لا في صف `P7-xx`. لا اسم `P7-03`.

**ما يُزيَّف.** في الحزام و`ApiLayer.create`: المحوّل أو `FakeApiClient` هو حدود الخادم. `SessionManager` و`AuthInterceptor` و`CookieCsrfAuthStrategy` والمستودعات والنماذج هي نسخ الإنتاج. مصنع العميل ينشئ `GetRetryInterceptor()` بلا وسيط تأخير، فالانتظار الافتراضي يبقى `Future.delayed`. ودجت الدخول والسداد يمران على `pumpFakeApp`: مخازن ذاكرة وجدولة فارغة ومنفذ اتصال وخدمة إذن و`sdkInt` وبوابة دفع، فوق `FakeApiClient`. P7-19 يستبدل `connectivityPortProvider` ويضخ `_CustomersShell` لا `buildAppRoot`، و`retry` يرجع `null`. هذا لا يغلق الصفوف.

**P7-01.** التخطي صريح: `markTestSkipped` ثم `return` قبل `ApiLayer.create` إن خلا أحد `STAGING_API_BASE` أو `STAGING_ADMIN_USERNAME` أو `STAGING_ADMIN_PASSWORD`. السجل طبع «P7-01 is opt-in…» ثم بقي العدّاد `~1` حتى `+197 ~1`. جملة المشغّل `All tests passed!` تعني صفر فشل. الدخان ليس داخل الـ 197. الحالة **not run** وليست Pass. كلمة المرور في الوثيقة عنصر نائب `<password>`. `demo-only` كلمة الخادم التجريبي القائمة. `dio: ^5.4.0` تحت `dev_dependencies` فقط. لا أثر على حارس الإصدار: الرفض و**4/0** كما في الجدول.

**P7-02.** المسار هو الجلسة والمعترض الحقيقيان. 401 المصادق: طلبان متزامنان، والسبب `session_expired` مرة، والكعك فارغ، ولا `GET /api/auth/csrf`. 419 غير CSRF (`PAGE_EXPIRED`) يرمي `SessionExpiredException` ولا يجلب CSRF. 419 برمز CSRF على `changePassword`: كتابتان و`GET` واحد لتجديد الرمز، والجلسة تبقى مصادقة. خمس فشل CSRF ما زالت كتابتين وجلبًا واحدًا، والاستثناء `CsrfInvalidException`، بلا حلقة خروج. دخول 401: `INVALID_CREDENTIALS` ورمز 401، وجلسة قائمة لا تُمسح. ودجت النموذج يبقي كلمة خاطئة على الشاشة بجملة `بيانات الدخول غير صحيحة` ثم يصل إلى `HomeShell`.

**P7-04 والمسار.** التطبيق ينادي `GET /api/me`. لا `auth/me` في `lib/` ولا في `packages/api_layer/lib`. نص المصفوفة السابق كان `GET /api/auth/me`؛ صُحّح في فجوة P7-01 وفجوة P7-04 وفهرس P7-04. **سؤال مفتوح لمالك الخادم:** أكّد أن `GET /api/me` هو العقد. #56 لا يضيف `/api/auth/me`. مصفوفة staging وDEF-002 باقيان.

**P7-19.** خطأ اتصال على القراءة والكتابة، ثم `ConnectivityResult` عبر المنفذ إلى none. القائمة والمسودة تبقيان، والكتابة POST واحد. وضع الطيران على الجهاز يبقى يدويًا. الحقن لا يغلق البند 11 ولا P7-26.

**P7-20 وP7-21 وDEF-020 وDEF-022.** معرّف النموذج من `SubmissionLock` عبر `GuardedMutation`. النقرة الثانية أثناء الانشغال لا تضيف طلبًا لأن `_run` يعود إذا كان `_lock.busy` والزر يُعطَّل. اختبار المستودع ينادي `accounts.addTransaction` مرتين بنفس `MutationMeta`، والصف الواحد من خريطة `FakeApiClient._mutate`: المعرّف المعلّق يُنتظر ولا يُسجَّل ثانية، والمعرّف المكتمل يعيد النجاح المخزَّن. الفشل لا يُحفظ، فإعادة المحاولة نفسها تنجح لاحقًا و`mutationRequestIds` يصير `[id, id]` وصف `tx_partial` واحد. المبلغ `inputValue` ‏10 لا 400، فلا سقف DEF-020. اختبار 409 يرمي `ConflictException` و`VERSION_CONFLICT` ولا يفتح حوار السداد، فـ DEF-022 (الحوار يلتقط الخطأ ويعيد `failureText`) يبقى مفتوحًا.

**الإنتاج في الطلب، لا من هذه المراجعة.** `get_retry_interceptor.dart`: وسيط تأخير اختياري، والافتراضي `Future.delayed`. `pubspec.yaml`: `dio` اعتماد تطوير. `pubspec.lock`: `direct dev`. `docs/staging.md`: يوثّق تخطي P7-01 و`GET /api/me` مقابل نص المصفوفة القديم.

**merge-tree.** لم يُنشأ دمج. لا ملف مشترك مع #48 أو #49 أو #50 أو #51.

| الطرف | الخروج | الشجرة |
|---|---|---|
| `main` `a5ca26809578dd013430dcaae78c517043e95491` | 0 | `03a22e95ac4b39b4b78de1c8b9392dc82e8470dd` |
| #48 `9aef5fec1cc72f1b2c2277bee859d65515da3755` | 0 | `18875d40874e155c1539d8437312f6b0476f90c1` |
| #49 `546a62342eb78140d550abdfd138de5e0821c77a` | 0 | `72138ce32be8d962386bc4f3ed4c72cd3475cd2f` |
| #50 `b7900a2c555aa3cccb3b562ed5f33b6f787fd527` | 0 | `266b170619c44638dbf840dfa206a8d6f5d528c2` |
| #51 `e34504c5ee28bca367575ffe9ba2f0edde2817e0` | 0 | `fef710ffd41e04ca89e56a05dbff4315e87af063` |
| #52 `f8f7812d203bd09fe0c5c124748d043694f3f5f9` | 1 | تعارض في `pubspec.yaml` |

ضد #52 الملفان المشتركان `pubspec.yaml` و`pubspec.lock`. القفل اندمج تلقائيًا. التعارض في الاعتمادات: مراحل `c567d1ac316c90c955403be2c98aa9d8bcc01b95` و`58e9b6a7dac06539bdeec23f2a667f4d3158cb6e` (#52) و`6314bbe19c229339e5b1a6d505004427c2e3e7c2` (#56). لم يُحل.

| المعرف | الحالة بعد #56 |
|---|---|
| P7-01 | Partial (not run) |
| P7-02 | Partial |
| P7-03 | Device، بلا تغطية |
| P7-04 | Partial. السؤال المفتوح: `GET /api/me` |
| P7-19 | Partial. الطيران يدوي |
| P7-20 | Partial (DEF-020، DEF-022) |
| P7-21 | Partial (DEF-020، DEF-022) |

الملخص لم يتغير: Covered ‏3، وPartial ‏15، وDevice-only ‏1.

### ملحق #56 — وسيط التأخير في `GetRetryInterceptor`

الادعاء: تغيير إنتاج واحد، والافتراضي بلا وسيط يبقي السلوك السابق. فُحص الفرق سطرًا سطرًا بين `a5ca268` و`9c0fa4f`. الحكم على هذا الملحق: yes. الأعداد والحالات لم تتغير. لم يُدفع إلى فرع #56. المسبار المحلي حُذف.

**الفرق التنفيذي.** الملف الوحيد تحت `lib/` و`packages/api_layer/lib` هو `get_retry_interceptor.dart`. بعد تطبيع سطر الانتظار، جسم `onError` و`_isRetryable` و`_backoff` مطابق. الأسطر الجديدة:

- وسيط اختياري `Future<void> Function(Duration delay)? delay`.
- الحقل `_delay`، وقيمته `delay ?? _systemDelay`.
- `_systemDelay` هو `Future<void>.delayed(delay)`.
- `await Future<void>.delayed(delay)` صار `await _delay(delay)`.

الثوابت كما كانت: `maxRetries` ‏2، و`baseDelay` ‏400 مللي ثانية، و`random ?? Random()`، والحالات `{502, 503, 504}`، والاهتزاز `base * 3^n ± 20%`. فحص الطريقة ما زال `GET` و`HEAD` فقط. `POST` و`PUT` و`PATCH` و`DELETE` لا تُعاد. رجوع 401 و419 ما زال قبل حساب التأخير. سطر الإلغاء ما زال بعد الانتظار: `if (req.cancelToken?.isCancelled ?? false) return handler.next(err);`.

**من يمرّر الوسيط.** البناء الوحيد في الإنتاج هو `GetRetryInterceptor()` في `api_client_factory.dart:91`. بصمة هذا الملف `c418820091bd1aad8dc1c0d7c2db037d809bd6de` على الرأسين. `ApiLayer.create` يمر من `ApiStack.build`. لا وسيط `delay:` في `lib/` ولا في `packages/api_layer/lib` ولا في `tool/`. الموضع الوحيد لـ `delay:` هو `retry_policy_test.dart`. الإصدار يترجم المصنع نفسه، فلا يُمرَّر الوسيط هناك.

**الاختبار الجديد يستخدم الصنف الحقيقي.** `retry_policy_test.dart` يستورد `package:flutter_api_layer/core/network/get_retry_interceptor.dart` ويبني `GetRetryInterceptor`. لا نسخة ثانية من `onError`. الاستبدال ثلاثة أشياء: محوّل `_Script`، و`Random` ثابت (`nextDouble` ‏0.5 فيصفّر الاهتزاز)، و`delay: clock.delay`. الساعة تسجّل 400 ثم 1200 مللي ثانية ولا تنام.

**اختبارات المعترض القائمة، بلا تعديل.** `get_retry_auth_header_test.dart` بصمته `fa2fad3a877bb8664487b94f26aec58d04efc18b` على الرأسين. البناء `GetRetryInterceptor(baseDelay: Duration.zero)` بلا وسيط تأخير، فيسلك `_systemDelay` على الرأس الجديد و`Future.delayed` على القديم. التشغيل على `/tmp/wt-main` و`/tmp/wt-56`: **+5** وخروج 0 في الجهتين. إعادة واحدة بعد 502 و503، والترويسة الحالية تُعاد.

**مسبار المسار الافتراضي، ثم حُذف.** نفس الملف على الرأسين، وبلا وسيط `delay`. `Random` ثابت حتى يكون 400 و1200 بلا اهتزاز. النتيجة **+4** إضافية وخروج 0 على الرأسين:

| الحالة | الرأسان |
|---|---|
| خطأ اتصال على GET | 3 نداءات، والزمن من 1500 إلى أقل من 6000 مللي ثانية |
| HEAD بعد 502 | نداءان |
| POST وPUT وPATCH وDELETE بعد 502 | نداء واحد، وأقل من 300 مللي ثانية |
| GET ‏401 و419 | نداء واحد، وأقل من 300 مللي ثانية |
| إلغاء أثناء انتظار 250 مللي ثانية | المستقبل `DioExceptionType.cancel`، وبعد 400 مللي ثانية إضافية النداء ما زال واحدًا |

**عدّ الاختبارات الجديدة.** 53 اختبارًا مسجّلًا، لا 52. التفصيل: عقد 21، وP7-02 جلسة 7، وP7-01 دخان 1 (المتخطى)، وسياسة إعادة 8، ومفتاح كتابة 4، وP7-04 أدوار 7 (خمسة في الحلقة زائد اثنان)، وودجت دخول 1، وP7-19 اثنان، وP7-20/P7-21 ودجت 2. في `check.sh` نجح 52 وتخطى 1. الـ 52 هي الناجحة فقط.

---

### مراجعة #53 و#54 و#55 — DEF-020 وDEF-021 وDEF-022

ثلاثة طلبات مسودة من `main` `a5ca268`. لم يُدمج أي منها. هذه الجولة لم تدفع إلى فروعها. لا توقيع. التالي الحر DEF-026. الأعداد لم تتغير: Covered ‏3، وPartial ‏15، وDevice-only ‏1.

الحزام `pumpFakeApp` يستبدل أيضًا بوابة الدفع ومخازن الإشعار والاتصال و`sdkInt`. الحوار والمتحكّم والمزوّدات التي يختبرها الطلب لا تُستبدل. بديل الخادم في الاختبار هو `FakeApiClient`.

اختبارات `known-bug` على #51 `e34504c` ما زالت تتوقع السلوك القديم (`-80 د.ل`، وغياب الصف، وبقاء الرأس 320). `merge-tree` معها نظيف لأن الملفات لا تتقاطع، والجمع المنطقي يفشل حتى يُحدَّث #51. هذه الفروع لا تعدّل #51.

#### #53 — DEF-020

الطلب [#53](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/53). الرأس `08e6b132c3d9bd450d463970da49ad3118fe8cba`. CI [39710423501](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39710423501) أخضر على هذا الالتزام.

**الحكم:** yes with notes. DEF-020 يبقى Open وBlocking على `main`.

`tool/check.sh` على `/tmp/wt-53`، خروج 0:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 5.8s)` |
| `flutter test --exclude-tags screenshots` | **372/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.4s)` |
| `flutter test` في `packages/api_layer` | **152/0** |
| السالب | **27/0** (7 ملفات) و**23/0** (6 ملفات) |
| dry-run | **6/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار | **4/0** |

**`lib/`:** `ledger_screen.dart` و`strings.dart` و`fake_api_client.dart`. المقارنة `units > remaining` بعد `parseUnits`، للسداد المباشر فقط. لا طرح في الحوار. الرسالة `المبلغ أكبر من المتبقي المسجّل.`.

اختبار الطلب: 400 على `c_55` يبقي الحوار، وبلا مسار `/transactions` جديد، والرأس `320 د.ل`، والمخزَّن 320 والإصدار 4. مسبار محلي ثم حُذف: 321 يُمنع بلا POST، و320 يُرسل ويصير الرصيد 0 والإصدار 5، و`320.01` جملة العدد الصحيح بلا رسالة السقف وبلا POST. بعد سداد خارجي 200 والمزوّد ما زال 320، إدخال 150 يُرسل ولا يُمنع بالسقف، والرأس يبقى 320، والمخزَّن 120 والإصدار 5. الحارس يقرأ آخر جلب في `accountCardProvider` ولا يجلب قبل الحفظ.

الخادم التجريبي يرفض الزائد بـ 400 `VALIDATION_ERROR` قبل تغيير الإصدار والرصيد. **مؤقت، وليس عقدًا.** السؤال المفتوح لمالك الخادم: هل هذا الرفض عقد الخادم، وبأي حالة ورمز؟ القسمة بمعامل 2 ومبلغ 400 تُرسل في المسبار، والرأس يبقى 320، لأن المعامل ليس مبلغًا. هل يُرفض ناتج القسمة أو الضرب إذا تجاوز المتبقي؟ غير محسوم، لأن حساب الناتج ممنوع على العميل.

`test/write_safety_test.dart` صار يدخل 100 بعد أن صار 180 فوق المتبقي 140.

#### #54 — DEF-021

الطلب [#54](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/54). الرأس `dc6c5c893f758b834cb23da33ee7e984d8ea58c4`. CI [39711511958](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39711511958) أخضر على هذا الالتزام.

**الحكم:** yes with notes. أُعيد تصنيف DEF-021 عيب بديل اختبار بلا أثر إنتاج. يبقى Open على `main` حتى الدمج. فحص staging للخادم الحقيقي باقٍ.

`tool/check.sh` على `/tmp/wt-54`، خروج 0: التحليل 5.4s و2.3s، التطبيق **372/0**، الحزمة **152/0**، السالب **27/0** و**23/0**، dry-run **6/0**، الحارس **4/0**، ورفض Fake.

**`lib/`:** `fake_api_client.dart` فقط. لا ملف تطبيق. `_AssignmentFormState._submit` و`_UnlinkedFormState._submit` كانا يناديان `ref.invalidate(collectionsProvider)` بعد النجاح. `collectionsProvider` ينادي `collections.overview()`. اختبار الودجت يفتح `submit-as_1` و`save-unlinked`، وتظهر البطاقتان `sb_posted_1` و`ur_posted_1` قبل مغادرة الشاشة، ثم بعد العودة. تكرار `requestId` يعيد الصف نفسه عبر `_mutate`. تعيين `as_9` للموظف 404. القرار على الإصدار المخزَّن ينجح. المقاييس الحرفية لا تُجمع من الصف الجديد.

#### #55 — DEF-022

الطلب [#55](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/55). الرأس `fc140f910fd08d6fa215a70892bd44a86b55eb2c`. CI [39710591725](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39710591725) أخضر على هذا الالتزام.

**الحكم:** yes with notes. الرأس يتحدث على الشاشة نفسها قبل التنقل. DEF-022 يبقى Open وBlocking على `main`. P7-10 يبقى Partial.

`tool/check.sh` على `/tmp/wt-55`، خروج 0: التحليل 5.5s و2.3s، التطبيق **372/0**، الحزمة **150/0**، السالب **27/0** و**23/0**، dry-run **6/0**، الحارس **4/0**، ورفض Fake.

**`lib/`:** `ledger_screen.dart` فقط. `_submit` يعيد رمي `VERSION_CONFLICT`. غير ذلك يُعاد `failureText` ويبقى الحوار. `onVersionConflict` يُبطل الكارت والدفتر والقائمة والرئيسية مرة واحدة من `_presentFailure`. لا إبطال ثانٍ في `_submit`. 409 لا ينهي الجلسة. الاختبار يتوقع الجملة `تم تعديل البيانات. أُعيد الجلب من الخادم.` وغياب جملة الخادم، والرأس `319 د.ل` قبل `Navigator.pop`، ثم بعد العودة. المخزَّن 319 والإصدار 5. لا `220 د.ل`.

#### merge-tree

خروج 0 في كل طرف. لم يُنشأ دمج. #53 و#54 يشتركان في `fake_api_client.dart` والدمج تلقائي. #53 و#55 يشتركان في `ledger_screen.dart` والدمج تلقائي. #54 و#55 بلا ملف مشترك. #52 يشترك مع #53 في الملفين ومع #54 في الخادم التجريبي ومع #55 في شاشة الدفتر، والدمج تلقائي. #50 يشترك مع #53 و#54 في `fake_api_client.dart`. لا ملف مشترك مع #48 أو #49 أو #51 أو #56.

| الطلب | `main` | #48 | #49 | #50 |
|---|---|---|---|---|
| #53 | `6602b858a0f3ba24447e5e3382648d1ba6c5996e` | `d1648bcac8670c902f0b94c9835ef5198d514e0a` | `75f4a6394efd36a69d14f2b0bce9826ee075950b` | `a8469fdc7a21f3868e73fbcfc12e3142dffd8be8` |
| #54 | `866b980027a04976f6bae42ee0d0e662a5d6c4cd` | `d36d3126549e2ec801d1d9411460fe2377cb880b` | `43b77b6524a17062c8a86ee8538485c4b5894df7` | `c75e8aefedc3641510e29b9c1ac2d9df34cfee50` |
| #55 | `f3d82e3968c1fd69851ec534f7f511ea890035e4` | `f4b457787941cbde21225a82f8e8b94aab337ec0` | `0005eb0231c93bd336e2c93e9ad7a7d5b2085e13` | `0380aa74391c89fadf28b7c2039f7d243fc1d80b` |

| الطلب | #51 | #52 | #56 | ضد بعض |
|---|---|---|---|---|
| #53 | `88588143bf5416f60f6f7820012ca17ddbabf496` | `2961ff47c555aeb9620b74d6c1a79aa413837822` | `77172ec880048278bb8dd4883345991b641f8018` | #54 `1f83a740af0edcd2062c41f3b3a32ec2d593346f`، #55 `025007e7e3072fd1a37608a385e4c585a59eb9e5` |
| #54 | `f4443edc57933c242c6816ef96b4b1f73dfe22a1` | `6300a464e2030dbe2ba3d0fb8997377054809dcc` | `225835f916ceda227c5882d1d41997bdb27619c5` | #55 `844402f43fb50d2c20a215c6abb2e817ca23e731` |
| #55 | `afc03aa76e2d8e9a73c75d99a54eb949a435e998` | `1a859242a232e900f4b220d542354fac49a9838f` | `2979e92a6102d4f372528a4d97604f556d63d338` | الشجرتان أعلاه |

---

### مراجعة #49 عند `546a623` و#57 — DEF-023 وDEF-024 وDEF-025

رأس [#49](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/49) ما زال `546a62342eb78140d550abdfd138de5e0821c77a`. وصف الطلب وأسباب `markTestSkipped` يسميان DEF-023 وDEF-024 وDEF-025. على هذا الرأس وحده الاختبارات الثلاثة تتخطى قبل القياس، فليست Pass. الملحق السابق يبقى ساريًا. `tool/check.sh` لم يُعد تشغيله على #49.

[#57](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/57) مسودة عند `714c6eaf7318eaadab8a8d92c02184f81e99b7e5`. الفرع `cursor/def-020-022-contrast-e77f`. CI [39712790633](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39712790633) أخضر على هذا الالتزام. لم يُدفع إلى فرع #57 ولم يُدمج. لا توقيع.

**الحكم:** yes with notes. DEF-023 وDEF-024 وDEF-025 تبقى Open وغير مانعة على `main`. البند 14 يبقى Covered. الأعداد لم تتغير.

`tool/check.sh` على `/tmp/wt-57`، خروج 0:

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 4.0s)` |
| `flutter test --exclude-tags screenshots` | **374/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 3.0s)` |
| `flutter test` في `packages/api_layer` | **150/0** |
| السالب | **27/0** و**23/0** |
| dry-run | **6/0** |
| حارس الإصدار | **4/0** |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |

الأساس كان التطبيق 371. الزيادة ثلاثة اختبارات تباين.

**الملفات.** `lib/ui/theme.dart` و`lib/features/home/home_shell.dart` و`lib/features/treasury/treasury_screen.dart` و`test/contrast_tokens_test.dart`. الفرق ليس رموز `theme.dart` وحدها. `IdentityBlock` يأخذ `roleColor`: الشريط يمرّر `shine`، ورأس الهاتف يبقى `onSurface`. كلمة الدرج صارت `bright`. صف الخزينة الوارد يقرأ `cashPositiveText`. لا مزوّد ولا منطق أعمال. تنسيق حدود في `theme.dart` داخل الفرق نفسه.

**النسب من البايتات، WCAG 2.x.** جدول الطلب يطابق التقريب إلى منزلتين.

| الزوج | النسبة |
|---|---|
| `#EAB600` على `#E5EDF6` | 1.588613 |
| `#7C6100` على `#E5EDF6` | 4.983618 |
| `#EAB600` على `#0D1522` | 9.751529 |
| `#172723` على `#102A26` | 1.022427 |
| `#FFFDE0` على `#102A26` | 14.754121 |
| `#FFFDE0` على `#101B2A` | 16.810616 |
| `#FFDB35` على `#102A26` | 11.175754 |
| `#FFDB35` على `#101B2A` | 12.733481 |
| `#247763` على `#172333` | 2.939585 |
| `#36B496` على `#172333` | 6.134279 |
| `#247763` على `#1A2C24` | 2.723645 |
| `#36B496` على `#1A2C24` | 5.683660 |
| `#041510` على `#247763` | 3.476987 |
| `#041510` على `#36B496` | 7.255721 |
| `#FFFFFF` على `#087A50` | 5.370877 |
| `#087A50` على `#E5EDF6` | 4.546331 |
| `#087A50` على `#172333` | 2.951710 |
| `#0CB677` على `#172333` | 6.019105 |
| `#0CB677` على `#1A2C24` | 5.576946 |
| `#175F50` على `#E5EDF6` | 6.373277 |
| `#175F50` على `#FFFFFF` | 7.529168 |

`VIB` بحجم 18 ووزن 800 نص عادي. العلامة بحجم 40 نص كبير. دور الشريط بحجم 13 نص عادي. كلمة الدرج بحجم 20 ووزن 800 نص كبير. الأزواج المرسومة أعلاه فوق حدها.

**الخضرة.** التعبئة تبقى `#087A50` (درجة 157.895). الحبر الداكن `#0CB677` درجته 157.765. الفرق 0.130 درجة. السالب يبقى `#B43131`. زر التعبئة يستخدم `onPrimary` `#041510` لا الأبيض. الأبيض على `#36B496` هو 2.584374، وهذا الزوج لا يُرسم على الزر.

**زوج كامن.** `#7C6100` على `#102A26` هو 2.582450. كلمة الدرج انتقلت إلى `bright` حتى لا يُرسم. القارئ الوحيد لـ `base` هو علامة الدخول على `#E5EDF6`.

**الاختبارات.** DEF-023 وDEF-024 وDEF-025 في `contrast_tokens_test.dart` ترسم الودجت الحقيقي: الدخول، والسكة ورأس الهاتف والدرج، ثم زر الرئيسية وبطاقة النقد وصف `ce_1` وزر المشتريات. `_expectTokenPairs` يقيس الثوابت داخل `MaterialApp` بلا تلك الشاشات، والقسم الذي يليه يرسم مواقع العيب.

**دمج محلي #49+#57.** `merge --no-commit` نظيف ثم أُلغي. بعد إيقاف `_skipDef023` و`_skipDef024` و`_skipDef025` نجح `phase7_theme_ui_test.dart` **+6** وخروج 0، ومنها الاختبارات الثلاثة ومشي الشاشات على حد الملف 3:1. تلك الاختبارات تتوقع غياب الأزواج القديمة. مسبار محلي بحد 4.5 للنص العادي و3 للنص الكبير، ثم حُذف: الوضع الداكن بلا نقص. الوضع الفاتح يظهر `#6D7C77` فقط، وهو `onSurfaceVariant` ولم يتغير: 3.703585 على `#E5EDF6` و4.375288 على الأبيض و4.053914 على `#EDF9F4` و3.810320 على `#E6F2ED`. فوق 3:1 وتحت 4.5. ليس تراجعًا من #57 ولم يُفتح له معرّف. التالي الحر DEF-026.

**`merge-tree --write-tree`.** خروج 0 ضد `main` و#48 و#49 و#50 و#51 و#52 و#53 و#54 و#55 و#56. لا أسماء ملفات مشتركة. لم يُنشأ دمج.

| الطرف | الشجرة |
|---|---|
| `main` | `5c3d2e16dcc1176e4f5e4cdb52ce1849412d9663` |
| #48 | `936d04d8e8a3fc12318546cdfaab64326566d4b1` |
| #49 | `3e4bba98c4bbd03fcfb58c12181a1de4f42772a1` |
| #50 | `8611e1260697dd70415f4064d527d944dd160628` |
| #51 | `210e37f4061e3a38185fba6a0eaf6354e16536f8` |
| #52 | `4d70e57fac49210a64eb5e1f830324b3c473b6dd` |
| #53 | `117be37b84851b74d65f00fb17c6b54b234f6faa` |
| #54 | `71d48ca3c3458b130c777b350dd0ae265b50bc4d` |
| #55 | `21a34de6055b607f8007efe58210f72c6de0814e` |
| #56 | `48e44ab4cf3c443fa6628dbcdca335060497490e` |

## إعادة اختبار #52 — الرأس `f347a8a` على `main` `c40e03d`

الطلب [#52](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/52) ما زال مسودة. الرأس `f347a8ac6128ed47a76133ee17f3485cf2bd6eec`. الأب الأول `f8f7812d203bd09fe0c5c124748d043694f3f5f9`، وهو سلف للرأس. الأب الثاني `main` `c40e03d3b184dd79e392f8dc384022090862b48f`. الرسالة `Merge remote-tracking branch 'origin/main'`. دمج بوالدين، لا إعادة قاعدة ولا إعادة كتابة لـ `f8f7812`. لم يُدفع إلى فرع #52. لا تغيير لكود الإنتاج من هذه الجولة. لا توقيع. الحكم: **مقبول للدمج YES**.

**محتوى `main` `c40e03d`.** خمسة squash بوالد واحد بعد `a5ca268`، بالترتيب: `653cedf` (#50) و`2861f4d` (#53) و`0fd9077` (#54) و`8d80100` (#55) و`c40e03d` (#56). رؤوس المراجعة ليست أسلافًا لأن الدمج squash، وأجسام الرقع تطابق ما رُوجع. `origin/main` هو `c40e03d`.

**حل التعارض.** `git merge-tree --write-tree f8f7812 c40e03d` خرج 1. التعارض الوحيد `pubspec.yaml`. اندمج تلقائيًا: `ledger_screen.dart` و`fake_api_client.dart` و`pubspec.lock`. الملفات التي تختلف عن الوالدين معًا في `f347a8a` هي هذه الأربعة فقط. الملف المحلول يضم `dio: ^5.4.0` من #56 و`vm_service: 15.4.0` من #52. القفل: `dio` ‏5.11.1 اعتماد `direct dev`، و`vm_service` ‏15.4.0 اعتماد `direct dev`. `flutter pub get` في التطبيق وفي `packages/api_layer` لم يغيّر الشجرة. `packages/api_layer/pubspec.yaml` و`pubspec.lock` مطابقان لـ `c40e03d`.

**ما يضيفه #52 فوق `main`.** `git diff --stat c40e03d f347a8a` هو 34 ملفًا، +3129/−84، ويطابق `a5ca268..f8f7812`. ملفات الإنتاج 15: شاشات الحسابات والدفتر والإشعارات، و`history_window.dart` و`perf_budget.dart` و`perf_surface.dart`، ومزوّدا الإشعارات والأقسام، و`api_layer.dart` ومصنع العميل وبنّاءا الخادم التجريبي و`fake_api_client.dart` و`fake_large_catalog.dart`، و`pubspec.yaml`. جسم رقعة الدفتر وجسم رقعة الخادم التجريبي من جهة #52 ومن جهة `main` متساويان بعد تجاهل ترويسة الـ hunk. `HISTORY_WINDOW_TRIM` هو `bool.fromEnvironment` والقيمة الافتراضية false. الميزانيات مقترحات هندسية وعمود القبول يبقى `recorded`. RSS وPSS وDart heap تقرير فقط. لا ملف إنتاج جديد خارج المراجعة السابقة.

**`tool/check.sh`.** على `c40e03d` خرج 0: تحليل التطبيق 4.6s، والتطبيق **384/0**، وتحليل الحزمة 2.6s، والحزمة **201** ناجح وتخطي واحد (P7-01 not run)، والسالب **27/0** و**30/0**، والتجربة الجافة **6/0**، وحارس الإصدار **4/0**، وrelease يرفض `USE_FAKE_API=true`. على `f347a8a` خرج 0: تحليل التطبيق 6.3s، والتطبيق **393/0** (+9)، وتحليل الحزمة 3.1s، والحزمة **206** ناجح وتخطي واحد (+5)، وباقي الخطوات بالأعداد نفسها. الفرق يساوي ما أضافه #52 فوق `a5ca268`. CI على الرأس: التشغيل `39775424693`، والثلاثة ناجحة.

**التفاعل.** DEF-022 وDEF-021 وDEF-020 ظهرت أسماؤها في السجلين وأكملت العداد حتى النهاية. اختبارات `retry_policy_test.dart` من +78 إلى +85 مع التخطي الواحد نجحت على الرأسين. DEF-019 لم يُطبع اسمه في سجل البوابة؛ التشغيل المباشر على الرأسين **+5** وخروج 0. التحميل الكسول لم يكسر حارس السداد الزائد ولا إعادة الجلب بعد 409.

**`merge-tree --write-tree`.** خروج 0. لم يُنشأ دمج.

| الطرف | الشجرة | تحرير من الجهتين |
|---|---|---|
| `main` `c40e03d` | `adf44ae7133dd211b38a4e3077ef41e1ea5348e3` | لا |
| #57 `714c6ea` | `0053c12c98999c707de86a8e2978ff99caf5cb37` | لا |
| #51 `e34504c` | `3ba703ffb2752e0d1f7b42d846f8cebe8405afea` | لا |
| #51 الرأس الحالي `721edef` | `bd1bee11f0aac7d0a3a43ddd12d4ab81e62ae095` | لا |
| #49 `546a623` | `b6e2375085ebc899e554e25df09dfed464967894` | `test/support/pump_app.dart` |
| #48 `6ed2d15` | `5e007753e383a7ef55c5910fb4fd04ad5940e5b3` | لا |

عند `e34504c` يبقى اختبار `DEF-020 a partial payment above the remaining balance is stored` ويتوقع السلوك القديم. الدمج النصي نظيف، ولم يُشغَّل الجمع على ذلك الرأس. رأس #51 `721edef` أسقط تلك النسخ، ومراجعته في القسم التالي. الأعداد في المصفوفة لم تتغير: Covered ‏3 وPartial ‏15 وDevice-only ‏1. DEF-023 وDEF-024 وDEF-025 تبقى Open. التالي الحر DEF-026.

## إعادة اختبار #51 — الرأس `721edef`

الطلب [#51](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/51) ما زال مسودة. الرأس `721edef74d44de273ff59211a49170ca0dd2eb6c`. `e34504c5ee28bca367575ffe9ba2f0edde2817e0` سلف. الدمج `931800f5d2429cbebe14fe1f911288ea036b0345` بوالدين: الأول `e34504c` والثاني `main` `c40e03d`. `git merge-tree --write-tree` لذلك الدمج خرج 0. الالتزام التالي `721edef` والد واحد فوق الدمج ويحذف نسخ الاختبارات. لا إعادة قاعدة ولا إعادة كتابة لـ `e34504c`. لم يُدفع إلى فرع #51. لا توقيع. الحكم: **مقبول للدمج YES**. حكم #52 `f347a8a` يبقى **YES**.

**فوق `main`.** `git diff c40e03d 721edef -- lib packages/api_layer/lib` فارغ. لا تغيير إنتاج في #51 فوق `main`. الفرق هو ملفات اختبار المرحلة 7 التي كانت على `e34504c`.

**ما تغيّر بعد الدمج.** `git diff 931800f 721edef` ملفان: `test/phase7_payments_test.dart` و`test/phase7_linked_cards_test.dart`، +14/−155. الحذف ثلاثة اختبارات `known-bug` كانت تتوقع العيب:

| المحذوف | ما كان يتوقعه | التغطية الآن |
|---|---|---|
| `DEF-020 a partial payment above the remaining balance is stored` | حوار 400 على `c_55` يخزّن رأس `-80 د.ل` | `test/def020_overpayment_test.dart` `DEF-020 the payment dialog refuses an amount above the server balance`: الحوار نفسه، الرسالة، بلا POST، الرأس `320 د.ل`، المخزَّن 320 والإصدار 4، و`-80` غائب بعد العودة. الحزمة: `DEF-020 a direct partial payment above the stored balance is refused` يرفض بـ `VALIDATION_ERROR` ويبقي الإصدار 4، ثم 320 يصير الرصيد 0 والإصدار 5 |
| `DEF-022 the payment dialog shows the server conflict sentence and does not refetch` | جملة الخادم، والرأس يبقى `320 د.ل` بعد العودة، والمخزَّن 319 | `test/def022_payment_conflict_test.dart` `DEF-022 a payment conflict refetches the card and the ledger`: الجملة الموحّدة، الرأس `319 د.ل` قبل إغلاق الحوار وبعد العودة، المخزَّن 319 والإصدار 5، و`320` و`220` غائبان |
| `DEF-021 a real submit for a linked card and an unlinked card is not on the next overview` | إرسال 40 و25، والنظرة تبقى `sb_1`/`sb_2` و`ur_1`/`ur_2` | `test/def021_collection_submit_test.dart` `DEF-021 the next collections overview shows the submitted rows`: الحواران نفسهما، `sb_posted_1` و`ur_posted_1`، المبلغان 40 و25، والاسم، وبعد العودة. الحزمة: `DEF-021 assignment submit and unlinked submit are on the next overview` يثبت الإصدار 1 وتكرار `requestId` |

سلاسل `mutationPaths` الخام (`/api/collections/assignments/as_1/submissions` و`/api/collections/unlinked-receipts`) ونص الجسم `"amountUnits"` لم تُنسخ حرفيًا. السيناريو والحوار والمبالغ والمعرّفات والإصدارات مغطاة. لا فقدان لمسار 400 على الحوار، ولا للرأس، ولا لصفوف النظرة، ولا لتحديث الرأس بعد 409، ولا لأرقام الإصدار.

**ما بقي كما كان على `e34504c`.** اختبارات `pending-decision` وDEF-012 بصمتها واحدة بين `e34504c` و`721edef`: `phase7_sections_test.dart` (ومنها `P7-07 empty settings tiles show the DEF-012 placeholders and do not close the row` بوسم `known-bug`)، و`phase7_totals_test.dart`، و`phase7_role_denials_permission_negative_test.dart`، و`phase7_status_order_permission_negative_test.dart`، و`shell_group_test.dart` (`DEF-012 admin settings replace the old unavailable sentence`، وهو أيضًا مطابق لـ `main`). داخل الملفين المعدّلين بقي: `P7-10 a partial payment then a full payment on the same card`، و`P7-10 libyan deposits have no full-payment button`، و`a stale expectedVersion is rejected and the balance stays 320`، و`P7-14 linking ur_1 approves it, stores customerId, and does not move money`، و`a system-managed card shows its stored balance and hides writes`، و`P7-14 cash buttons follow the stored cash status` بوسم `pending-decision`.

**`tool/check.sh`.** خرج 0: تحليل التطبيق 3.9s، والتطبيق **420/0**، وتحليل الحزمة 2.6s، والحزمة **204** ناجح وتخطي واحد (P7-01 not run)، والسالب **32/0** و**33/0**، والتجربة الجافة **6/0**، والحارس **4/0**، وrelease يرفض Fake. الفرق عن `main` 384/201/27/30 هو اختبارات #51 بعد حذف الثلاثة: +36 و+3 و+5 و+3. أسماء العيب القديمة غائبة من السجل. DEF-020 وDEF-021 وDEF-022 وP7-10 وP7-14 وDEF-012 ظهرت وأكمل العداد حتى 420. CI [39775704570](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39775704570) ناجح على هذا الرأس.

**`merge-tree --write-tree`.** خروج 0. لم يُنشأ دمج.

| الطرف | الشجرة |
|---|---|
| `main` `c40e03d` | `5451ff4abf393d2a11ed323abf3967de7fbc004a` |
| #52 `f347a8a` | `bd1bee11f0aac7d0a3a43ddd12d4ab81e62ae095` |
| #57 `714c6ea` | `6be254d23590d727bfc06991f3fa7e25dd4a6956` |
| #49 `546a623` | `b439d0c39db6710e5180328ea6b2764445f2fb48` |
| #48 `5307b84` | `12a232feece4a17964db8b07c673218c44d0174b` |

لا تحرير من الجهتين مع هؤلاء. الأعداد لم تتغير: Covered ‏3 وPartial ‏15 وDevice-only ‏1. DEF-012 يبقى Fail. DEF-002 يبقى Pending PM. التالي الحر حينها DEF-026.

## تأكيد `main` `2a45cfb` وإعادة اختبار #49 — الرأس `653a07c`

`origin/main` عند `2a45cfb16962e16170d10c818bc0ce4cbcc46eb7`. بعد `c40e03d` ثلاثة squash بوالد واحد، ليست دمجات بوالدين. رؤوس المراجعة ليست أسلافًا، وأجسام الرقع متساوية بعد تجاهل ترويسة الـ hunk:

| squash | الرسالة | يطابق |
|---|---|---|
| `9111a1f7781caebdcbd8669cf2e8d1dcda6534a1` | Add Phase 7 cold start, long-history, and APK size runs (#52) | فرق `f347a8a` فوق `c40e03d` (34 ملفًا، +3129/−84) |
| `213e04a9de230874d6e23561149c43b572f256ff` | Raise DEF-023–025 text contrast to WCAG AA (#57) | فرق `714c6ea` (4 ملفات، +416/−17). البصمات ما زالت على `2a45cfb` |
| `2a45cfb16962e16170d10c818bc0ce4cbcc46eb7` | Add phase 7 tests against the fake server (#51) | فرق `721edef` فوق `c40e03d` (11 ملف اختبار، +1310، بلا `lib/`) |

**`tool/check.sh` على `2a45cfb`.** خرج 0. تحليل التطبيق 4.6s والتطبيق **432/0**. تحليل الحزمة 2.5s والحزمة **209** ناجح وتخطي واحد (P7-01 not run، ليست Pass). السالب **32/0** و**33/0**. التجربة الجافة **6/0**. الحارس **4/0**. release يرفض `USE_FAKE_API=true`. أسماء DEF-023 وDEF-024 وDEF-025 في `contrast_tokens_test.dart` ظهرت وأكمل العداد حتى 432. `#7C6100` هو `base` في `buildAppTheme` للوضع الفاتح. إعادة حساب WCAG 2.x من البايتات تطابق المراجعة: `#7C6100`/`#E5EDF6` 4.983618، و`#EAB600`/`#0D1522` 9.751529، و`#FFFDE0`/`#102A26` 14.754121، و`#36B496`/`#172333` 6.134279، و`#0CB677`/`#172333` 6.019105. الحكم: DEF-023 وDEF-024 وDEF-025 **Verified closed** على `main`.

**DEF-026.** حبر `onSurfaceVariant` الفاتح `#6D7C77` مع `bodySmall` حجم 11 ووزن 500 (نص عادي، فيُقاس على 4.5:1): 3.703585 على `#E5EDF6`، و4.375288 على الأبيض، و4.053914 على `#EDF9F4`، و3.810320 على `#E6F2ED`. فوق 3:1 وتحت 4.5:1. شدة منخفضة. غير مانع. المالك مطور الواجهة. ليس تراجعًا من #57. التالي الحر DEF-027.

الطلب [#49](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/49) ما زال مسودة. الرأس `653a07c2fbac3b8aa6cd7fdd8dc4548244c9c4fc`. `546a62342eb78140d550abdfd138de5e0821c77a` سلف. الدمج `f410e546ae9c3d1d0f68d6f6d006fb8b04823b5c` بوالدين: الأول `546a623` والثاني `main` `2a45cfb`. الرسالة «Merge origin/main into the phase 7 UI tests.» `git merge-tree --write-tree` لذلك الزوج خرج 0. الالتزام التالي `653a07c` والد واحد فوق الدمج. لا إعادة قاعدة. لم يُدفع إلى فرع #49. لا توقيع. الحكم: **مقبول للدمج YES**.

**فوق `main`.** `git diff 2a45cfb 653a07c -- lib packages` فارغ. لا تغيير إنتاج جديد. الفرق سبعة ملفات اختبار: `phase7_layout_ui_test.dart` و`phase7_push_matrix_test.dart` و`phase7_rtl_ui_test.dart` و`test/support/phase7_ui.dart` مطابقة بايتًا لـ `546a623`. `phase7_notifications_ui_test.dart` و`phase7_theme_ui_test.dart` تغيّرا بإطفاء `_skipDef019` و`_skipDef023` و`_skipDef024` و`_skipDef025` فقط (`f410e546..653a07c` ملفان، +4/−4). `pump_app.dart` هو معامل `sdkInt` الذي رُوجع على `546a623`، وقد دُمج تلقائيًا مع نسخة `main` (يختلف عن الوالدين، و`merge-tree` خرج 0).

**`tool/check.sh` على `653a07c`.** خرج 0. تحليل التطبيق 4.1s والتطبيق **466/0** بلا تخطي. تحليل الحزمة 2.6s والحزمة **209** ناجح وتخطي واحد (P7-01). السالب **32/0** و**33/0**. التجربة الجافة **6/0**. الحارس **4/0**. release يرفض Fake. الفرق عن `main` 432 هو اختبارات #49 الأربع والثلاثون، ومنها الأربعة التي كانت تُتخطى. `DEF-023 login brand stays readable on the light scaffold` و`DEF-025 dark primary text and cash amounts stay readable` و`a granted login does not register again on the first notifications visit` ظهرت في سجل البوابة. اسم `DEF-024 the sidebar role stays readable in light mode` سقط بين علامات المبلّغ؛ تشغيل الملف بالمبلّغ الموسّع أعطى **+6** وخروج 0 وظهر الاسم عند +3. CI [39786578137](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39786578137) ناجح على هذا الرأس، والفحوص الثلاثة SUCCESS.

**`merge-tree --write-tree` من `653a07c`.** خروج 0. لم يُنشأ دمج.

| الطرف | الشجرة |
|---|---|
| `main` `2a45cfb` | `cc727c57bacd06491cf33e23ebc64cdb19368982` (شجرة #49 نفسها) |
| #48 `f295d38` | `792b18a7233354c75ed5695c215a2d63fd46341d` |

لا سطور `CONFLICT`. الأعداد لم تتغير: Covered ‏3 وPartial ‏15 وDevice-only ‏1. البند 10 يبقى Partial. البند 14 يبقى Covered. البند 15 يبقى Covered. البند 16 يبقى Partial. DEF-012 يبقى Fail. DEF-002 يبقى Pending PM. التالي الحر DEF-027.

## مراجعة #58 — الرأس `6e7a76c` ودمج محلي مع #49

الطلب [#58](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/58) مسودة. الرأس `6e7a76cd4d03c3b35be62d4fcb38478f8cd10ad8`. الوالد `main` `2a45cfb16962e16170d10c818bc0ce4cbcc46eb7` وهو سلف. لم يُدمج ولم يُدفع. لا توقيع. الحكم: **مقبول للدمج YES**. [#49](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/49) عند `653a07c2fbac3b8aa6cd7fdd8dc4548244c9c4fc` يبقى **YES**. دمج #49 ثم #58 محليًا بلا تعارض وبلا كسر للاختبارات.

**الملفات التسعة** (`git diff --stat 2a45cfb 6e7a76c`: +36/−23). التغيير السلوكي الوحيد هو `defaultValue: true` في `lib/performance/history_window.dart`. الباقي تعليقات أو اختبارات أو وثيقة:

| الملف | التغيير |
|---|---|
| `lib/performance/history_window.dart` | `HISTORY_WINDOW_TRIM` الافتراض `true`. الإطفاء `--dart-define=HISTORY_WINDOW_TRIM=false` أو `HistoryWindow.trimEnabled = false` |
| `lib/features/accounts/account_list_screen.dart` | تعليق |
| `lib/features/accounts/ledger_screen.dart` | تعليق |
| `lib/features/notifications/notifications_screen.dart` | تعليق |
| `lib/state/notification_providers.dart` | تعليق |
| `test/p7_history_window_test.dart` | الافتراض `isTrue`، والحالتان تبقيان |
| `test/p7_long_history_test.dart` | اختبار الإبقاء الكامل يضبط العلم `false` صراحة |
| `docs/testing/PHASE7_PERFORMANCE.md` | الوثيقة |
| `tool/android_performance_emulator_test.sh` | تعليق. السكربت لا يمرر العلم |

**العلم في البنائين.** `ci.yml` و`android-performance.yml` و`tool/check_release_rejects_fake_api.sh` و`tool/measure_release_cold_start.sh` و`tool/android_notification_emulator_test.sh` و`tool/android_performance_emulator_test.sh` لا يمررون `HISTORY_WINDOW_TRIM`. إصدار release وCI يأخذان الافتراض، وهو تشغيل القص. تشغيل الملفّين بالمبلّغ الموسّع **+7** وخروج 0: الافتراض مشغّل ويمكن إطفاؤه، وإضافات الحساب 100 عند الإطفاء وآخر 80 عند التشغيل، وP7-25 المطفأ يبقي كل صفوف الدفتر، والمشغّل يبقي 80 ويمشي لآخر صفحة، والإشعارات تُسقَف عند 120.

**ما بقي صحيحًا مع القص.** لا `fold` ولا `reduce` لقوائم الصفوف تحت `lib/`. رأس الدفتر `balanceUnits` للكارت. ملخص الحسابات وعدادات التصفية من `AccountsSummaryDto`. الرئيسية `HomeDto`. نظرة الاستلامات `CollectionsOverviewDto`. بحث الحسابات والبحث الموحّد (`accounts.suggestions`) استعلام خادم، ومسح الإضافات يعيد بطاقة كانت في الفجوة (`lc_00050`). الدفتر والإشعارات بلا بحث صفوف. فتح إشعار خارج النافذة من الصينية ومن الإقلاع البارد يجلب الحساب بالمعرّف ويفتح `/customers/lc_00000`، وتعليم القراءة ينقص `unreadCount` من 1500 إلى 1499. حارس DEF-020 على الرصيد 0 يمنع المبلغ 1 بلا POST. رأس DEF-022 يبقى من الكارت المعاد جلبه.

**DEF-027.** غير مانع. شدة متوسطة. المالك DevOps. مع الافتراض يبقي الدفتر الصفحة الأولى ثم أبعد 80 ملحقة (`ltx_00000` حاضر، `ltx_00720` حاضر، `ltx_00040` و`ltx_00100` غائبان، `ledger-retained-80`، والزر يختفي بعد 19 ضغطة). إبطال المزوّد لا يعيد النافذة. مغادرة الشاشة تعيد `ledger-retained-0` والزر، فبيانات الخادم باقية. قائمة الحسابات بعد ثلاث ضغطات `childCount` ‏120 وفيها الفجوة نفسها. الإشعارات أحدث 120 و`nextBefore` يُمسح، و`refresh` لا يعيد المؤشر. لا `RefreshIndicator` على الشاشات الثلاث. التفاصيل في `defects.md` على #12. التالي الحر DEF-028.

**`tool/check.sh` على `6e7a76c`.** خرج 0. تحليل التطبيق 4.0s والتطبيق **432/0**. تحليل الحزمة 2.6s والحزمة **209** ناجح وتخطي واحد (P7-01 not run). السالب **32/0** و**33/0**. التجربة الجافة **6/0**. الحارس **4/0**. release يرفض `USE_FAKE_API=true`. CI [39786843720](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/actions/runs/39786843720) ناجح، والفحوص الثلاثة SUCCESS.

**`merge-tree --write-tree`.** خروج 0 في الاتجاهين. لا سطور `CONFLICT`.

| الطرف | الشجرة |
|---|---|
| `main` `2a45cfb` | `8b5c2fc0ecf62570234983b3983af86c5b896609` (شجرة #58 نفسها) |
| #49 `653a07c` | `b10cad271a1fea4bc26a202d0e788199e92247e0` |

**دمج محلي #49 ثم #58.** من `653a07c` ثم `git merge --no-ff --no-commit 6e7a76c`. الدمج التلقائي نجح، تسعة ملفات، بلا غير مدمج. لم يُلتزم ولم يُدفع. `tool/check.sh` على الشجرة المدموجة خرج 0. تحليل التطبيق 4.0s والتطبيق **466/0**. تحليل الحزمة 3.0s والحزمة **209** ناجح وتخطي واحد (P7-01). السالب **32/0** و**33/0**. التجربة الجافة **6/0**. الحارس **4/0**. release يرفض Fake. اختبارات #49 التي كانت على قص مطفأ ما زالت تمر مع الافتراض المشغّل، لأن قوائمها أقصر من 80 و120. أسماء `HISTORY_WINDOW_TRIM off` و`DEF-023` و`DEF-024` ظهرت في السجل وأكمل العداد حتى 466.

الأعداد لم تتغير: Covered ‏3 وPartial ‏15 وDevice-only ‏1. البند 17 يبقى Partial. البند 18 يبقى Partial. DEF-012 يبقى Fail. DEF-002 يبقى Pending PM. DEF-026 يبقى مفتوحًا. التالي الحر DEF-028.

## د. خط الأساس `tool/check.sh`

الالتزام: `a5ca26809578dd013430dcaae78c517043e95491`. Flutter 3.47.7 / Dart 3.13.5. السكربت `tool/check.sh` على شجرة هذا الالتزام.

التشغيل على شجرة العمل لهذا الالتزام. رمز الخروج **0**.

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | `No issues found! (ran in 4.7s)` |
| `flutter test --exclude-tags screenshots` | **371/0** |
| `flutter analyze` في `packages/api_layer` | `No issues found! (ran in 2.5s)` |
| `flutter test` في `packages/api_layer` | **150/0** |
| `--tags permissions-negative` التطبيق | **27/0** |
| `--tags permissions-negative` الحزمة | **23/0** |
| `preflight_test.sh` | `preflight_test ok` |
| `scan_release_apk.py --self-test` | `scan_release_apk self-test ok` |
| `USE_FAKE_API=true` في release | `Release compilation rejected USE_FAKE_API=true.` |
| حارس الإصدار بعد `USE_FAKE_API=false` | **4/0** |

وسم `screenshots` خارج الـ 371. السالب خارج 371 و150. CI السابق على الالتزام نفسه: التشغيل `39699625496`، ونجحت فحوصه الثلاثة، وبلا محاكٍ.
