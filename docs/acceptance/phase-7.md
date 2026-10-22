# المرحلة 7 — تنفيذ الاختبار

**الدور:** قائد الاختبار. هذه خطة تنفيذ ومصفوفة تتبع. ليست توقيع قبول.

**الأساس:** `main` عند `a5ca26809578dd013430dcaae78c517043e95491`. الفرع يضيف هذه الوثيقة فقط. لا تغيير لكود الإنتاج. لم يُمس فرع #12.

**معرّفات القبول السابقة** (`P0`–`P6`) موثّقة على [#12](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/12) في `docs/acceptance/phase-0.md` … `phase-6.md`. سجل العيوب هناك أيضًا: [`defects.md`](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/blob/cursor/acceptance-docs-13b0/docs/acceptance/defects.md). عند كتابة الخطة كان التالي الحر DEF-020. بعد مراجعة #51 التالي الحر **DEF-023**.

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

لقطة الأساس على `a5ca268` كانت Partial ‏15 وDevice-only ‏2 (البندان 17 و19). مراجعة #52 تنقل البند 17 إلى Partial. مراجعة #51 تنقل البند 4 إلى Covered. البند 19 يبقى Device-only. لا توقيع.

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
| 17 الأداء | DevOps | Partial | release مسجّل على #52 | P7-23، P7-24 |
| 18 سجل أو تاريخ طويل | DevOps | Partial | widget على #52 | P7-25 |
| 19 هاتف حقيقي | DevOps | Device-only | سير محاكٍ منفصل على #52 | P7-26 |

### 1 — اختبارات API

- **المالك:** مهندس API
- **الموجود:** مجلد `packages/api_layer/test/` كله هو مجموعة البند. أمثلة: `fake_flow_test.dart` `fake login -> me -> accounts -> mutation with requestId -> logout`؛ `qa_defects_round1_test.dart` `partial payment stores the new balance and rejects a stale version`؛ `permission_service_test.dart` `employee: write needs BOTH *.write and sectionAccess=manage; read needs *.read and != none`؛ `staging_http_test.dart` (محوّل داخل العملية، لا مضيف)؛ `get_retry_auth_header_test.dart`؛ `release_fake_api_guard_test.dart` `release mode rejects a fake client at runtime`؛ `cookie_csrf_strategy_test.dart`؛ `notification_repository_test.dart`. معرّفات القبول: P0-04، P1-16، وعقود P2 وP3 على الخادم التجريبي.
- **الفجوة:** **P7-01** دخان staging حي: `POST /api/auth/login` ثم `GET /api/auth/me` ثم قراءة قسم وكتابة واحدة على `STAGING_API_BASE`. المستوى staging.
- **منع الاستبدال:** لا `FakeApiClient` ولا `HttpClientAdapter` يدوي في P7-01. `staging_http_test.dart` لا يُغلق هذا الصف.
- **المستوى:** unit اليوم، staging للدخان.
- **الحالة:** Partial

### 2 — الدخول

- **المالك:** مهندس API
- **الموجود:** `test/login_flow_test.dart`: `employee sees only server-granted sections and the server unread count`، `admin with no permission list sees the sections the flag opens`، `rejected sign-in stays on the login screen and shows the server message`، `empty sign-in does not call the session`. `test/authentication/auth_gate_test.dart`: `unknown session stays on the splash route`، `signed-out session is sent to login`، `authenticated session leaves login and splash`، `a required password change blocks every other route`. `test/fake_server_defects_test.dart` `DEF-008 mustchange.demo is kept on the change-password screen`. `test/session_logout_presentation_test.dart` `logout asks first, cancel stays signed in, confirm uses the existing logout`. الحزمة: `packages/api_layer/test/fake_qa_defects_test.dart` `DEF-008 mustchange.demo returns mustChangePassword until it is changed`؛ `permissions/session_permission_negative_test.dart` `login 401 stays invalid credentials and any later 401 or bare 419 does not`. القبول: P1-01، P1-02، P1-03، P1-04، P1-12، P1-13، P1-14، P1-17، P5-13، P5-14.
- **الفجوة:** **P7-02** دخول staging للأدوار عبر نموذج الدخول و`CookieCsrfAuthStrategy`، وكلمة خاطئة تبقى `INVALID_CREDENTIALS`. **P7-03** إغلاق العملية ثم فتحها فيستعيد `SecureDeviceTokenStore` / مخزن الجلسة الجلسة بلا حقن `SessionAuthenticated`. المستوى: staging ثم device.
- **منع الاستبدال:** لا تمرير `sessionStateProvider` جاهز في P7-02 وP7-03. لا `MemoryDeviceTokenStore` حين الادعاء إعادة التشغيل.
- **المستوى:** widget على Fake. الفجوة staging وdevice.
- **الحالة:** Partial

### 3 — الصلاحيات

- **المالك:** مهندس API
- **الموجود:** وسم `permissions-negative`. التطبيق: `test/employee_permission_negative_test.dart`، `test/employee_totals_permission_negative_test.dart` `limited admin provider state is forbidden until DEF-002`، `test/permissions/employee_gating_permission_negative_test.dart` `an employee does not see totals or decide, and the fake server rejects both`، `test/permissions/session_permission_negative_test.dart`، `test/permissions/treasury_section_permission_negative_test.dart`، `test/permissions/push_transport_permission_negative_test.dart`، `test/permissions/system_tray_permission_negative_test.dart`. الحزمة: `packages/api_layer/test/employee_permission_negative_test.dart` `a missing session is 401 and limited admin still has decide`، `employee_totals_permission_negative_test.dart`، `permissions/session_permission_negative_test.dart`، `permissions/session_wipe_permission_negative_test.dart` `employee cannot decide, reject, or reach management routes on the fake`، `permissions/treasury_section_permission_negative_test.dart`، `permissions/notifications_permission_negative_test.dart`. أيضًا `permission_service_test.dart` و`test/permissions_ui_test.dart` `explicit fullAccess false opens no sections and no actions`. القبول: P1-05 إلى P1-11، P1-15، P5-10، P5-11، P5-20، P5-21، P5-30، P5-32، P5-40، P5-42، P3-02، P3-03.
- **الفجوة:** **P7-04** مصفوفة staging: الموظف 403 على الاعتماد والخزينة والإعدادات، والمدير 200 على قراءة قسم، ومن `GET /api/auth/me` لا من `PermissionService()` مبني في الاختبار. DEF-002 يبقى Pending PM: نجاح اعتماد `limited.admin` على Fake لا يُغلق البند.
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
- **الفجوة:** **P7-10** المسار السعيد موجود والصف Partial بسبب DEF-020 وDEF-022. **P7-11** المطابقة على staging مقابل الويب.
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
- **الفجوة:** **P7-14** Partial بسبب DEF-021. **P7-15** الزوج نفسه على staging.
- **منع الاستبدال:** لا `onSubmit` فارغ. حالة الربط تُقرأ من الرد (`assignment` / غياب الربط) لا من علم اختبار.
- **المستوى:** widget. P7-15 staging.
- **الحالة:** Partial

### 10 — الإشعارات

- **المالك:** مطور الواجهة
- **الموجود:** `test/notifications_controller_test.dart` `push and poll dedupe, and a push does not increment the count` و`mark-read updates readAt and the server count, without a second decrement`. `test/notifications_presentation_test.dart`: `rows and the bell use the server notification fields`، `a foreground event shows a banner and the tap uses origin banner`، `notification permission asks, then grants, denies, or opens settings`. `test/notifications_wiring_test.dart`: `a list tap marks the row read once`، `below Android 33 registers without asking`، `Android 33 asks before the device post`، `allow posts the device token once`. `test/system_tray_bg_poll_test.dart`: `scheduling uses at least 15 minutes, the network, and keep`، `tray dedup is shared by push, poll, and the worker`. `test/system_tray_navigation_test.dart` `a cold tray payload for the signed-in user opens collections`. `test/permissions/system_tray_permission_negative_test.dart` `the lock-screen public version has no name and no amount`. `test/notifications/notification_channels_test.dart` `collections channel id, Arabic name, and badge flag stay stable`. `integration_test/android_notifications_test.dart` `notification permission matches NOTIF_CASE` غير داخل `check.sh` وهذا التشغيل بلا محاكٍ. القبول: P6-01 إلى P6-40. حكم المرحلة 6 على #12: مقبول بشروط، بلا توقيع.
- **الفجوة:** **P7-16** جهاز: صينية المقدمة، حوار الإذن على API 33، نص القفل `إشعار جديد`، والنقر يفتح الكيان وينقص العدد مرة. **P7-17** الخلفية، ثم العملية المقتولة. إن لم يصل شيء بعد الإيقاف الإجباري فالنتيجة Not supported (لا FCM) لا Fail وهمي. **P7-18** API 29 بلا حوار تشغيل، وAPI 34 كـ 33. المستوى device.
- **منع الاستبدال:** `granting permission registers with signedIn true` يستبدل المسجّل (`RecordingDeviceTokenRegistrar`) ولا يُغلق الإرسال. درس DEF-018: الموافقة تُقاس على `buildAppRoot` والمسجّل الحقيقي. لا `notificationOpenSeamProvider` مسجّل حين يُحكم على النقر. نقل `FakePushTransport` مسموح في ودجت Fake فقط.
- **المستوى:** unit + widget. الفجوة device.
- **الحالة:** Partial

### 11 — انقطاع الإنترنت

- **المالك:** مهندس API
- **الموجود:** حقن انقطاع، لا وضع طيران. `test/review_round_test.dart` `offline disables writes and the status line follows connectivity`. `test/review_round2_test.dart`: `an open form save is disabled while offline`، `missing platform connectivity follows the last API result`. `test/ledger_presentation_test.dart` `offline disables ledger writes until the link returns`. `test/account_list_ui_test.dart` `offline keeps permitted writes visible and disabled`. `test/purchases_presentation_test.dart` `offline keeps purchase actions visible and disabled`. `test/collections_presentation_test.dart` `empty, loading, payroll error, and offline stay consistent`. `test/shell_group_test.dart` `offline disables notification writes and account edits`. `test/treasury_reports_polish_test.dart` `treasury tone, empty ledger, offline, and hidden writes`. القبول: P6-21، L6-06.
- **الفجوة:** **P7-19** وضع الطيران على الجهاز أثناء سداد وأثناء جلب قائمة. بعد القطع لا صف جديد. المستوى device.
- **منع الاستبدال:** `connectivityProvider` أو `ConnectivityResult.none` المحقون لا يُغلق P7-19. الراديو الحقيقي هو الشرط.
- **المستوى:** widget للعقد. الفجوة device.
- **الحالة:** Partial

### 12 — إعادة المحاولة

- **المالك:** مهندس API
- **الموجود:** `packages/api_layer/test/get_retry_auth_header_test.dart` يعيد GET بعد 502/503 بلا ترويسة قديمة. `docs/staging.md`: GET/HEAD قد تُعاد لأخطاء الاتصال و502/503/504 مرتين كحد أقصى؛ الكتابة لا يعيدها النقل. `test/section_errors_test.dart` أزرار إعادة الجلب. `test/shell_group_test.dart` `a failed startup offers retry on the splash` و`notifications show an error with retry and an empty state`. `test/submission_lock_test.dart` `a retry of the same inputs reuses the request id`. `packages/api_layer/test/staging_http_test.dart` `401 clears the session once and is not retried`.
- **الفجوة:** **P7-20** بعد عودة الراديو في P7-19: إعادة السداد من الواجهة تحمل `requestId` المحاولة نفسها، والنقل لا يرسل POST ثانيًا من تلقاء نفسه. جلب القائمة قد يُعاد كـ GET. المستوى device مع staging.
- **منع الاستبدال:** لا مستودع يعيد النجاح محليًا. لا عدّاد اختبار بدل `GetRetryInterceptor` و`PendingMutation`.
- **المستوى:** unit + widget. الفجوة device.
- **الحالة:** Partial

### 13 — بلا حركة مكررة

- **المالك:** مهندس API
- **الموجود:** `packages/api_layer/test/fake_qa_defects_test.dart` `DEF-011 a repeated requestId returns the original success once`. `packages/api_layer/test/masraweya_day_test.dart` `DEF-013 a repeated requestId returns the first day and is not applied again`. `packages/api_layer/test/purchase_day_finalized_test.dart` `DEF-014 a stored requestId does not bypass the finalized-day check`. `test/write_safety_test.dart` `a collection form ignores a second tap while the send is in flight`. `test/submission_lock_test.dart`. `test/guarded_mutation_test.dart` `a version conflict keeps the request id when nothing changed`. `test/masraweya_save_test.dart` `a failed retry keeps the request id until the inputs or version change`. القبول: P2-05، P3-04. `requestId` على السلك ما زال بانتظار مالك الخادم (سؤال على #12، ليس عيبًا).
- **الفجوة:** **P7-21** نقرتان على تأكيد السداد أو الاعتماد ضد staging: محاولة واحدة ظاهرة في الدفتر. إن غاب `requestId` من الجسم يُسجَّل سؤال خادم لا Pass صامت. المستوى staging.
- **منع الاستبدال:** لا قفل إرسال مستبدل ولا مولّد معرّف ثابت داخل الاختبار. المعرّف يأتي من قفل النموذج الحقيقي.
- **المستوى:** unit + widget على Fake. الفجوة staging.
- **الحالة:** Partial

### 14 — الوضع الداكن والفاتح

- **المالك:** مطور الواجهة
- **الموجود:** `test/screens_ui_test.dart` `allowed screens render RTL in dark mode`. `test/shell_group_test.dart` `login, home, settings, account, and notifications hold at phone sizes (light|dark)`. `test/collections_presentation_test.dart` `light and dark keep status colours, RTL, and amount direction`. `test/purchases_presentation_test.dart` `purchases renders RTL in light and dark`. `test/ledger_presentation_test.dart` `ledger layout stays whole across widths, scales, and themes`. `test/treasury_reports_polish_test.dart` `both screens lay out on phones in light and dark`. `test/notifications_presentation_test.dart` `the notifications list fits a small and a large phone in both themes`. `test/forbidden_presentation_test.dart` `forbidden pane fits a small phone in light and dark`. لقطات `screenshots` مستبعدة من `flutter test --exclude-tags screenshots`.
- **الفجوة:** لا اختبار آلي جديد. التأكيد على الجهاز خطوة 23 في البروتوكول.
- **منع الاستبدال:** لا `ThemeData` مفروض فوق `themeModeProvider` حين يُختبر مبدّل السمة. تثبيت `_DarkTheme` مقبول لمعاينة الشاشة لا لزر التبديل.
- **المستوى:** widget
- **الحالة:** Covered

### 15 — RTL

- **المالك:** مطور الواجهة
- **الموجود:** `test/screens_ui_test.dart` `login is RTL and does not offer an external account`. `test/shell_group_test.dart` `disclosure chevrons mirror in RTL`. `test/account_list_ui_test.dart` `amounts sit on the RTL start edge in light and dark`. `test/purchases_opening_correction_test.dart` `opening balance renders RTL in light mode`. `test/edit_account_card_test.dart` `the edit screen stays RTL on a small phone in both themes`. `test/transaction_correction_test.dart` `the correction form is RTL in both themes on small and large phones`. `test/unlinked_receipt_actions_test.dart` `unlinked actions stay RTL in both themes on a small phone`. `test/ledger_presentation_test.dart` `a missing sequence is a dash and dates stay LTR`.
- **الفجوة:** لا اختبار آلي جديد. اتجاه التاريخ LTR مقصود. التأكيد البصري في الخطوة 23.
- **منع الاستبدال:** لا `Directionality(textDirection: TextDirection.rtl)` يلف الشاشة من خارج التطبيق. الاتجاه من `MaterialApp` الحقيقي.
- **المستوى:** widget
- **الحالة:** Covered

### 16 — مقاسات الشاشة

- **المالك:** مطور الواجهة
- **الموجود:** عرض 320 و360 و393 و430 في `test/shell_group_test.dart` `login, home, settings, account, and notifications hold at phone sizes` ومع `text scale` 1 و1.3 و2. `admin bottom bar stays on one row at 320 and 360`. `test/collections_presentation_test.dart` `receipt cards do not overflow across phone widths and text scales`. `test/treasury_reports_polish_test.dart` `the cash form stays reachable at 320 and text scale 2`. `test/employee_totals_screen_test.dart` `a 320 phone fits the cards in both themes`. `test/purchases_opening_correction_test.dart` مقاس 320 و430. `test/screens_ui_test.dart` `a wide window uses the side list instead of a bottom bar`.
- **الفجوة:** **P7-22** تدوير عمودي/أفقي على 320 و430 لدخول والرئيسية والاستلامات والدفتر والإشعارات، بلا فيض. ثم الجهاز الصغير والكبير في البروتوكول. المستوى widget ثم device.
- **منع الاستبدال:** `tester.view` يثبت المقاس في الودجت. لا يُغلق جهازًا حقيقيًا. لا `overflow: clip` لإخفاء الخطأ.
- **المستوى:** widget. الفجوة تدوير + device.
- **الحالة:** Partial

### 17 — الأداء

- **المالك:** DevOps
- **الموجود على الأساس:** لا اختبار `Timeline` ولا ميزانية إقلاع ولا قياس تمرير. `integration_test/android_notifications_test.dart` يفحص قناة الإشعار لا الزمن.
- **بعد #52:** `tool/measure_release_cold_start.sh` يبني release بـ `USE_FAKE_API=false` ويطبع وسيط `am start -W`. `integration_test/p7_long_history_test.dart` يطبع أزمنة الإطارات. الحكم والأدلة في مراجعة #52. العتبة ما زالت قرار علي، والرقم في نموذج الهاتف فارغ.
- **الفجوة:** **P7-23** إقلاع بارد لإصدار release على جهاز ضعيف حتى الرئيسية التفاعلية، مع رقم الثواني في النموذج. **P7-24** تمرير أطول دفتر حتى آخر صفحة مع عدد الصفحات. المستوى device. العتبة الرقمية يكتبها علي في النموذج قبل أول تشغيل؛ بلا عتبة تُسجَّل الأرقام ولا يُخترع Pass.
- **منع الاستبدال:** لا وضع debug ولا `FakeApiClient` في قياس الإصدار. لا قائمة من سطرين تُسمى سجلًا طويلًا.
- **المستوى:** device للنموذج. القياس على #52 release للعملية، وprofile للتاريخ الطويل.
- **الحالة:** Partial

### 18 — سجل أو تاريخ طويل

- **المالك:** DevOps
- **الموجود على الأساس:** صفحات قصيرة. `test/qa_round_test.dart` `load older shows the error and a retry`. `test/treasury_reports_polish_test.dart`: `treasury shows server cards, movements, and older pages`، `treasury load older shows the error and retries`. `test/account_list_actions_test.dart` `phone show-all loads the remaining pages for the active filter`. `test/account_list_logic_test.dart` `a late load-more page is not mixed into the new filter`.
- **بعد #52:** `test/p7_long_history_test.dart` يمشي 20 صفحة عبر زر `load-older` الحقيقي و`FakeDataset.large`. `packages/api_layer/test/fake_large_dataset_test.dart` يجمع 800 سطرًا على 20 صفحة من `FakeApiClient`. نصف الجهاز ما زال مفتوحًا. التفاصيل في مراجعة #52.
- **الفجوة:** **P7-25** دفتر من عدة صفحات عبر `load more` الحقيقي حتى الصفحة الأخيرة، على `FakeApiClient` بعدد صفحات معلوم، ثم على جهاز P7-24. المستوى widget ثم device.
- **منع الاستبدال:** لا حقن صفحتين ثم ادّعاء تاريخ طويل. مصدر الصفوف المستودع أو الخادم.
- **المستوى:** widget للصفحات. القياس device.
- **الحالة:** Partial

### 19 — هاتف حقيقي

- **المالك:** DevOps (تجهيز التشغيل). التنفيذ على قائد الاختبار والمالكين حسب البروتوكول.
- **الموجود على الأساس:** لا مصفوفة جهاز في CI التشغيل `39699625496`. `tool/android_notification_emulator_test.sh` يبني debug بـ `USE_FAKE_API=true` وهو خارج هذه البوابة. `integration_test/android_notifications_test.dart` لا يطلب الإذن بنفسه.
- **بعد #52:** `.github/workflows/android-performance.yml` سير منفصل لمستويات API ‏29 و33 و34. `docs/testing/PHASE7_PERFORMANCE.md` يطابق أعمدة النموذج وينص على أن سجل المحاكي ليس نموذج البروتوكول. النموذج نفسه فارغ.
- **الفجوة:** **P7-26** تنفيذ القسم ب على API 29 و33 و34، وشاشة صغيرة وكبيرة، وجهاز ضعيف، وإرفاق النموذج. المستوى device.
- **منع الاستبدال:** بناء release المشار إليه في القسم ب. لقطة محاكٍ بلا راديو لا تغلق وضع الطيران ولا الصينية.
- **المستوى:** device
- **الحالة:** Device-only

### أكبر الفجوات حسب المالك

| المالك | ما يُكتب أولًا |
|---|---|
| مهندس API | P7-01 الدخان الحي. P7-02 الدخول الحقيقي. P7-04 مصفوفة الصلاحيات من `me`. P7-19 الطيران على الراديو. P7-20 وP7-21 إعادة المحاولة بلا حركة ثانية، و`requestId` ظاهر في الجسم أو سؤال خادم |
| Senior Flutter | بعد #51: P7-05 وP7-06 وP7-12 مغلقة على الودجت ولم تُدمج. يبقى P7-07 مع DEF-012، وP7-08، وP7-10 مع DEF-020 وDEF-022، وP7-14 مع DEF-021، وصفوف staging P7-09 وP7-11 وP7-13 وP7-15 |
| مطور الواجهة | P7-16 الصينية والإذن والقفل والنقر على المسجّل والفتاحة الحقيقيين. P7-17 الخلفية، والقتل Not supported بلا FCM. P7-18 مصفوفة 29/33/34. P7-22 التدوير |
| DevOps | بعد #52 يبقى: رقم P7-23 وP7-24 على الجهاز الضعيف في النموذج، وعتبة علي، ونصف الجهاز من P7-25، ونموذج P7-26 على الهواتف A–D. سير المحاكي لا يملأ النموذج |

### فهرس `P7`

| المعرف | البند | المستوى |
|---|---|---|
| P7-01 | دخان staging: دخول، `me`، قراءة، كتابة | staging |
| P7-02 | دخول أدوار staging من النموذج | staging |
| P7-03 | استعادة الجلسة بعد قتل العملية | device |
| P7-04 | مصفوفة صلاحيات من `GET /api/auth/me` | staging |
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

قيم `pass/fail`: `Pass`، `Fail`، `Blocked`، `Not supported`. DEF-020 وDEF-021 وDEF-022 مسجّلة في `defects.md` على #12. التالي الحر DEF-023.

---

## ج. مراجعة طلبات الفريق في المرحلة 7

قبل اعتبار الطلب جاهزًا للمراجعة:

1. **منع الاستبدال.** الاختبار الجديد يمر على المزوّد الجذر أو `buildAppRoot` أو المسجّل أو المتحكّم. الاستبدال المسموح: `FakeApiClient` أو محوّل HTTP أو `FakePushTransport` حين الحالة Fake. يُرفض طلب يغلق P7-16 بـ `RecordingDeviceTokenRegistrar`، أو P7-06 بتجاوز `homeDashboardProvider`، أو P7-19 بـ `ConnectivityResult` محقون.
2. **وسم `permissions-negative`.** كل حالة 403/401 لدور بلا صلاحية في ملف تحت `test/permissions/` أو `packages/api_layer/test/permissions/` أو الملفات الموسومة الحالية، و`tool/run_permissions_negative_tests.sh` أخضر. صفر اختبارات موسومة يفشل السكربت.
3. **`tool/check.sh` أخضر** على رأس الطلب: تحليل، اختبارات بلا وسم `screenshots`، حزمة API، السالب، `preflight_test.sh`، `scan_release_apk.py --self-test`، ورفض ترجمة `USE_FAKE_API=true` في release.
4. **لا Fake في release.** لا `--dart-define=USE_FAKE_API=true` في بناء release ولا في وثيقة التثبيت. debug بـ Fake يبقى حلقة مطور ويُسمّى كذلك.
5. **العيوب.** عيب جديد من DEF-020 فصاعدًا في [`docs/acceptance/defects.md`](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/blob/cursor/acceptance-docs-13b0/docs/acceptance/defects.md) على [#12](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/12). عند كتابة الخطة كان التالي الحر DEF-020. بعد مراجعة #51 التالي الحر **DEF-023**. لا يُغلق DEF-002 ولا DEF-012 من طلب مرحلة 7 إلا بقرار علي أو ببيانات الإعدادات. DEF-019 يبقى مفتوحًا وغير مانع حتى يُصلح تكرار تسجيل الجهاز.
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

---

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
