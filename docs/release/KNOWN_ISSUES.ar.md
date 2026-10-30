# قائمة المشاكل المعروفة لنسخة المرحلة 9

> مصدرها مسودة QA (`/workspace/phase9/known-issues.ar.md` على جهاز البناء)، مع تحديث بند الإصدار بعد فرع `cursor/phase9-release-prep`. حُدِّثت بعد دمج المرحلة 8 (#73 ثم #81 ثم #68 ثم #83) على `main` عند `f1dee47`. القائمة النهائية تُثبَّت على commit البناء `<BUILD_COMMIT>` الذي يحدده Grok Bot بعد دمج فرع المرحلة 9 (#84).

- **المستودع:** `ddaa81108-wq/vib-abdo-company-mobile`
- **أساس القائمة:** `origin/main` عند `f1dee47416dd440214e8713a9a3341ebba9de8cf`، وهو دمج #83 في 2026-10-30 الساعة 16:35 (توقيت طرابلس، UTC+2). جرد QA الأول كان على `faa54fb` (دمج #65)؛ البنود التي غيّرها دمج المرحلة 8 محدَّثة هنا.
- **commit البناء النهائي:** `<BUILD_COMMIT>` (يُملأ بعد دمج #84).
- **تاريخ الجرد:** 2026-10-30 الساعة 01:11، والتحديث بعد دمج المرحلة 8 في 2026-10-30 الساعة 17:30 (توقيت طرابلس، UTC+2).
- **حالة الـ PRs:** من `gh pr view` بعد دمج المرحلة 8.
- **الطريقة:** قراءة فقط. كل حكم «مفتوح» تحقق منه QA في كود `main` نفسه، ولم يكتفِ بسجل العيوب. ما لم يُتحقق منه موسوم «غير مؤكد».
- **مسودة:** لا توقيع. تؤكد مراجعةُ Ali هذه المسودةَ قبل أن تُرفق بالنسخة.

## 1. حالة الـ PRs المطلوبة

| PR | العنوان | الحالة | الرأس | ملاحظة |
|---|---|---|---|---|
| #68 | Parse the purchases page contract (P-04 / DEF-034) | **مدموج** (squash `ab5276e`، 2026-10-30 15:39) | `d6ea588` | أغلق G-02 |
| #70 | P-14 / DEF-030: section summary headlines and report display | **مفتوح، غير مدموج** (مسودة) | `26bba1b` | يغلق G-11 وعرض G-12 |
| #73 | Map catalog error codes to typed exceptions (P-09 / G-07) | **مدموج** (squash `1c33f4d`، 2026-10-30 15:06) | `83206e5` | أغلق G-07 وضمّ تضييق CSRF (G-08) |
| #74 | Show purchases register totals (P-04 UI) | **مفتوح، غير مدموج** (مسودة) | `863622b` | قاعدته ما زالت فرع #68 (`cursor/p04-purchases-contract-shape`) بعد دمج #68 بـ squash، وليست `main`. آخر حكم QA: مرفوض |
| #81 | docs: gaps G-16..G-18 and Ali's staging rule | **مدموج** (squash `9d5beb1`، 2026-10-30 15:25) | `688becb` | أضاف G-16 حتى G-18 إلى `gap-analysis.ar.md` |
| #83 | Ledger follow-ups after DEF-031 | **مدموج** (squash `f1dee47`، 2026-10-30 16:35) | `a713f1e` | متابعات DEF-031 (إلغاء التحذير يحفظ `requestId`، ولا كتابة بلا نسخة الكارت) |

الأوقات بتوقيت طرابلس (UTC+2). PRs أخرى مفتوحة تمس الإصدار: #71 (P-18، توثيق الإغلاقات)، و#13 (توقيع release، قرار تحديثه أو إغلاقه عند Ali)، و#84 (المرحلة 9، مسودة).

## 2. الجدول

مفاتيح المالك من `docs/api/integration-plan.ar.md:15-21`:
- **API:** مهندس تكامل API
- **UI:** مطور Flutter واجهات
- **SR:** مهندس Flutter أول
- **OPS:** DevOps
- **QA:** مهندس الاختبار

| الرقم | الوصف | الأثر على المستخدم | الحالة | المالك | المرجع |
|---|---|---|---|---|---|
| DEF-037 / G-03 | تقديم التحصيل بلا exactly-once. الخادم لا يقرأ `requestId` على مسار التقديم. والـ `requestId` الذي يرسله التطبيق لا يحمي من التكرار. | إذا ضاع الرد ثم اعتمد المدير التقديم الأول وأعاد المحصّل الإرسال، قد يُخصم الدين مرتين ويُطالَب المحصّل بنقد لم يستلمه. **الاعتماد المالي النهائي موقوف** حتى يُصلَح الخادم. | **مؤجل** (بانتظار إصلاح الخادم) | مهندس الموقع + API + QA | `docs/api/defect-decisions.ar.md:26` و`:96-139`؛ `docs/api/gap-analysis.ar.md:22`؛ `docs/api/integration-plan.ar.md:8` و`:38` و`:183`؛ اختبار موسوم skip في `packages/api_layer/test/contract/site_contract_test.dart:596`. **ملاحظة:** لا قسم لـ DEF-037 في `docs/acceptance/defects.md` على `main`؛ الرقم «مقترح» (`defects.md:21`). التخفيف المؤقت P-11 بلا PR في القائمة: **غير مؤكد** أنه نُفّذ |
| DEF-035 (الجزء المصري، P-20) | ربط إيصال تحصيل مستقل بحساب أمانات مصرية قد يرحّل الرقم نفسه بالجنيه دون تحويل. التطبيق أوقف هذا الربط مؤقتًا (#69). | لا يستطيع المستخدم ربط إيصال مستقل بحساب مصري، ويرى نص الإيقاف بدلًا من ذلك. يبقى القرار عند الشركة: عملة الإيصال، وهل يُسمح بالتحويل، والسعر والتقريب. | **مؤجل** (بانتظار قرار الشركة، ثم الخادم) | UI + API، والقرار للشركة | `docs/api/defect-decisions.ar.md:84-92`؛ `integration-plan.ar.md:186-195`؛ الإيقاف في `lib/features/collections/egyptian_link_pause.dart:7-10` و`collections_screen.dart:888` و`:922` (#69 مدموج)؛ skip في `site_contract_test.dart:248`. إغلاق جزء LYD موثق في #71، وهو غير مدموج |
| DEF-020 | سداد جزئي أكبر من الرصيد. السجل يقول «Verified closed» بعد #53، الذي منع المبلغ الأكبر من الرصيد. #65 أزال هذا المنع، واستبدل به تحذيرًا دون منع (DEF-031)، ونص الرفض «المبلغ أكبر من المتبقي المسجّل.» لم يعد في `lib/`. | لا أثر جديد على المستخدم: السلوك الحالي هو سلوك DEF-031. المشكلة في السجل فقط، لأنه يصف سلوكًا أُزيل. | **بانتظار قرار** (إعادة التصنيف إلى «Superseded by DEF-031» بعد تأكيد Ali المباشر لقرار DEF-031) | QA (في #71) | `docs/acceptance/defects.md:635-659`؛ #53 و#65 و#79؛ `lib/features/accounts/ledger_screen.dart:569-598` |
| DEF-031 / G-13 | التحذير قبل سداد أكبر من الرصيد، ثم عرض رصيد الخادم. نُفّذ على `main` (#79 لطبقة API و#65 للواجهة). لكن السجل والوثائق لم تُحدَّث: | لا منع على المستخدم. يرى تحذيرًا ثم رصيد الخادم. بقية الأثر في الوثائق وفي #83: | **بانتظار قرار** (تأكيد Ali المباشر للقرار المحدَّث) | UI (#65، #83) | `docs/acceptance/defects.md:1002-1006`؛ `docs/api/defect-decisions.ar.md:57-58`؛ `integration-plan.ar.md:164`؛ `test/contract/site_contract_screen_test.dart:64-72`؛ `ledger_screen.dart:569-598`؛ #83 |
| ↳ | السجل ما زال يكتب «Open (candidate)» ويصف المنع القديم. | — | — | — | `defects.md:1002-1006` |
| ↳ | `defect-decisions.ar.md` و`integration-plan.ar.md` ما زالا يذكران جملة «سيصبح الرصيد −100». القرار المحدَّث، الذي نقله Grok Bot وينتظر تأكيد Ali المباشر، يذكر الرصيد الحالي والمبلغ المدخل فقط. | — | — | — | `defect-decisions.ar.md:57-58`؛ `integration-plan.ar.md:164` |
| ↳ | اختبار العقد ما زال skip بسبب قديم: يقول «still refuses». | — | — | — | `site_contract_screen_test.dart:64-72` |
| ↳ | #83 مدموج (`f1dee47`): إلغاء حوار التحذير لم يعد يمسح `requestId`، والكتابة مخفية ما لم تكن نسخة الكارت معروفة. اختباراته جزء من `tool/check.sh` على `main`؛ لم يُختبر على staging. | — | — | — | #83 |
| G-06 | كتابات المشتريات بنسخة خاطئة. `setDayCorrection` يرسل `expectedDayVersion`، والعقد والموقع يطلبان `expectedVersion` (مطلوب). وتعديل البند وحذفه يرسلان `expectedDayVersion` وحده، والعقد يطلب `expectedVersion` للصف. | فتح تصحيح يوم مرحّل أو إغلاقه، وتعديل بند أو حذفه، يُتوقع أن يرفضها الخادم الحقيقي. **غير مؤكد على staging**: لم تُرسل كتابة إليه. | **مفتوح** | API (P-05، بلا PR في القائمة) | `main` `f1dee47` (بعد #68): `packages/api_layer/lib/data/repositories/purchases_repository.dart:48` و`:140-153` (السطر 149 `meta.toBody(versionField: _v)`)؛ `docs/api/openapi.json:23692` (الجسم `required: ["open","expectedVersion"]`)؛ `gap-analysis.ar.md:25`؛ skip في `site_contract_test.dart:575` |
| #74 — نصوص المشتريات | نحو 12 نصًا في شاشة المشتريات تختلف حرفيًا عن الموقع. التفاصيل في القسم 3. موجودة على `main` وعلى رأس #74 `863622b` كليهما. | ما يقرؤه المستخدم يخالف ما يراه على الموقع. الأرقام غير متأثرة. | **بانتظار قرار** (قرار Ali: هل يلزم التطابق الحرفي) | UI (#74) | القسم 3 أدناه؛ `docs/api/evidence/08-purchases.png`؛ ملف الموقع `PurchasesSection-BvxICuQj.js` (sha256 `1fb6883f…e61191`، ونسخة منه على جهاز QA `/workspace/site74/Purchases.js` بالبصمة نفسها) |
| G-12 | حقول دفتر المالية والتقارير. طبقة API تقرأ `sectionKey` منذ #77، والعرض في الواجهة لم يُدمج. | دفتر المالية والتقارير في الإعدادات لا يعرضان حقول الموقع `sectionKey`/`sourceStatus`/`occurredAt`. | **مفتوح** (#70 غير مدموج) | UI (#70) | `gap-analysis.ar.md:32`؛ `packages/api_layer/lib/data/models/report_models.dart:371-378`؛ #77 مدموج؛ وصف #70 يقول إن العرض يحتاج تغييرًا في api_layer |
| G-11 / DEF-030 (العرض) | شريط الملخص يعرض `netBalance` عنوانًا رئيسيًا لكل الأقسام. الموقع يعرض `totalDebt` للعملاء والشركات. | عند وجود أرصدة سالبة، يختلف الرقم الكبير في الشريط عن الرقم الذي يعرضه الموقع. هذا يخالف شرط «لا فرق». | **مفتوح** (#70 غير مدموج) | UI (#70) | `lib/features/accounts/account_list_screen.dart:606`؛ `defect-decisions.ar.md:45-51`؛ skip في `test/contract/site_contract_screen_test.dart:53-61` |
| G-04 | نسخة الخزينة تُقرأ من `version`، والخادم يعيدها باسم `cashVersion`. | يُتوقع أن يرفض الخادم الحقيقي قيد نقدية الخزينة، لأنه يُرسل بلا `expectedVersion`. | **مفتوح** | API (P-06، بلا PR) | `packages/api_layer/lib/data/models/treasury_models.dart:52`؛ `gap-analysis.ar.md:23`؛ skip في `site_contract_test.dart:168` |
| G-05 | التثبيت يرسل `pinned`، والعقد يطلب `isPinned` + `expectedVersion`. | يُتوقع أن يفشل تثبيت الحساب على الخادم الحقيقي. | **مفتوح** | API (P-07، بلا PR) | `packages/api_layer/lib/data/repositories/accounts_repository.dart:138`؛ `gap-analysis.ar.md:24`؛ skip في `site_contract_test.dart:550` |
| G-09 | التطبيق ينادي مسارات غير موجودة على الخادم، وتعيد 404 على staging: `/api/notifications/unread-count` و`/api/mobile-push/devices` و`/api/admin/employee-totals` و`/api/home` و`/api/statements/pdf`. | قد تبقى شارة الإشعارات غير دقيقة. ولا يعمل تسجيل الجهاز للدفع، ولا إجماليات الموظفين المخصصة، ولا تصدير PDF. | **مفتوح** | API (P-12، بلا PR) | `notifications_repository.dart:85`؛ `lib/notifications/device_registration_client.dart:21` و`:29`؛ `employee_totals_repository.dart:55`؛ `home_repository.dart:21`؛ `reports_repository.dart:77`؛ `gap-analysis.ar.md:29`؛ skip في `site_contract_test.dart:658` |
| G-10 | `checkDuplicate`/`allowDuplicate` لا يُرسلان أبدًا. | لا يظهر تحذير «معاملة مماثلة اليوم» الذي يعرضه الموقع. | **مفتوح** | API + UI (P-13) | `gap-analysis.ar.md:30`؛ skip في `site_contract_test.dart:588` |
| G-14 | `Paged.hasMore` يتجاهل `nextBefore`. | منخفض. التطبيق لا يقرأ `hasMore` حاليًا. | **مفتوح** | API (P-17) | `packages/api_layer/lib/data/models/common.dart:108`؛ `gap-analysis.ar.md:34`؛ skip في `site_contract_test.dart:627` |
| DEF-028 | الـ Fake يضيف فرق السداد إلى `totalDebt` حتى عندما يعبر الرصيد الصفر. | لا أثر على الخادم الحقيقي. قد تعطي أرقام نسخة debug/Fake ملخصًا غير منطقي. | **مفتوح** | API (P-16، بلا PR) | `packages/api_layer/lib/data/fake/fake_api_client.dart:1689-1690`؛ `defects.md:966-980`؛ `defect-decisions.ar.md:30-35` |
| DEF-029 / DEF-033 | أُغلقا بالقرار (المقياس 0، وعملة فودافون EGP)، لكن الإغلاق الرسمي في #71 غير مدموج، ووسم 🔶 باقٍ في الكود. | لا أثر على المستخدم. السجل يعرضهما مفتوحين. | **بانتظار قرار** (دمج #71) | QA (#71) | `defects.md:21` و`:982-994` و`:1016-1020`؛ `api_config.dart:84`؛ `purchase_models.dart:14`؛ `defect-decisions.ar.md:37-43` و`:69-74` |
| DEF-002 | الإداري المحدود يملك `collections.decide`. | يستطيع الإداري المحدود اعتماد الاستلامات. | **بانتظار قرار** (Pending PM decision) | علي | `defects.md:16` و`:937` و`:953` |
| DEF-012 | بلاطات الإعدادات الإدارية الثلاث نص بديل. | يرى المدير «لا يوجد» بدل البيانات. | **مفتوح** (Fail، #27 غير مدموج) | UI (#27) | `defects.md:20` و`:936` و`:954` |
| P-19 | قبول staging الكامل ومطابقة الأرقام مع الموقع لم يُشغَّلا. عمود Flutter في جدول MATCHING فارغ. | لا دليل بعد على أن كل رقم يطابق الموقع، وهذا شرط قبول المرحلة 8 دون أي فرق. | **مؤجل** (بعد بقية البنود وبوابة DEF-037 وموافقة Ali) | QA (مع الفريق) | `integration-plan.ar.md:46` و`:176-184`؛ `docs/api/evidence/MATCHING.ar.md:5`؛ `docs/acceptance/phase-8-reconciliation.md:7` |
| إصدار-01 (بند إصدار) | **حُلّ في فرع المرحلة 9 (#84، غير مدموج بعد):** `applicationId` و`namespace` صارا `com.vip2100.vib`، والتوقيع يُقرأ من `ANDROID_KEY_PROPERTIES` أو `android/key.properties` أو متغيرات `ANDROID_KEYSTORE_*`. PR #13 يحمل تصميمًا سابقًا لهذا البند؛ قرار تحديثه أو إغلاقه عند Ali. | لا أثر على المستخدم بعد الدمج. **تغيير المعرّف يعني أن النسخة الجديدة لا تُرقّي نسخة `com.example` القديمة**: يجب إلغاء تثبيت القديمة، وتُفقد بياناتها المحلية والجلسة. | **مفتوح حتى الدمج** | OPS | `android/app/build.gradle.kts`؛ `docs/release/BUILD.ar.md`؛ #13 |
| إصدار-02 | نسخة Release الحالية **تجريبية على staging** (`API_BASE=https://staging.vip2100.com` عبر `--dart-define` فقط). ليست نسخة إنتاج. | تتصل بخادم staging. لا تُوزَّع على المستخدمين ولا تُرفع إلى Play كنسخة إنتاج. | **مقصود** (قرار Ali) | OPS | `docs/release/BUILD.ar.md` |
| إصدار-03 | بناء Release في CI يوقَّع بمفتاح debug، لأن مفتاح الإصدار على جهاز البناء المشترك فقط ولا يدخل GitHub. يظهر تحذير واضح في السجل. | لا أثر. أي APK أو AAB من CI غير صالح للتوزيع. | **مقصود** | OPS | `android/app/build.gradle.kts` |
| إصدار-04 | مفتاح الإصدار موجود على جهاز البناء المشترك فقط؛ النسخة الاحتياطية لدى Ali ينقلها Grok Bot. فقدان المفتاح يمنع أي تحديث مستقبلي لنفس التطبيق (إلا عبر Play App Signing). | لا أثر مباشر. خطر تشغيلي. | **مفتوح** (تأكيد استلام النسخة الاحتياطية، وقرار Play App Signing ومالك Play Console) | OPS + Ali | — |
| إصدار-05 | الفحوص التي تعتمد على `google-services.json` تحتاج تطبيق Firebase جديدًا بالمعرّف `com.vip2100.vib`؛ أي ملف قديم لـ `com.example` يُرفض. | الإشعارات الدفعية غير مفعّلة أصلًا (G-09)، فلا أثر الآن. | **مفتوح** (نطاق Firebase عند Ali) | OPS + API | `docs/NOTIFICATIONS.md` |
| G-16..G-18 | فجوات متوسطة: `employeeName` في المرتبات (G-16)، و`sectionKey` في الإشعارات (G-17)، و`current`/`daily`/`summary` في التقارير (G-18). | لا يظهر اسم الموظف في المرتبات، ولا يوجَّه الإشعار بحسب القسم، ولا تُعرض أقسام التقارير هذه. | **مفتوح** (موثقة على `main` بدمج #81) | UI + API | `docs/api/gap-analysis.ar.md:34-36` |

### مغلقة بالدمج على `main`، واختبار العقد ما زال موسومًا skip

هذه الفجوات أُغلقت بالدمج على `main`، لكن اختبارات العقد لها ما زالت موسومة skip. تحتاج متابعة #72 التي ذكرها QA.

| الرقم | الدمج | دليل الكود على `main` | skip باقٍ |
|---|---|---|---|
| G-01 | #66 | `collections_repository.dart:24` (لا `expectedVersion`) | `site_contract_test.dart:230` و`:267` |
| G-15 | #75 و#82 | `permission_service.dart` | `site_contract_test.dart:436`. **غير مؤكد** إن كان الإبقاء عليه مقصودًا |
| G-02 / DEF-034 | #68 (`ab5276e`) | `packages/api_layer/lib/data/models/purchase_models.dart` يقرأ `day` و`entries` و`registerTotals` و`nextBefore` | لا: اختبار تحليل عينة المشتريات يعمل. عرض الإجماليات في الواجهة ما زال في #74 (غير مدموج) |
| G-07 | #73 (`1c33f4d`) | `packages/api_layer/lib/core/network/error_mapper.dart`؛ `MfaRequiredException` و`InvalidCurrentPasswordException` في `api_exception.dart:140` | `site_contract_test.dart:530` (حالة MFA فقط؛ العينة بلا رد `MFA_REQUIRED`) |
| G-08 (تضييق CSRF) | #67 (الطابور) و#73 (`1c33f4d`، الإعادة لـ 403 `CSRF_REJECTED` فقط، ولا إعادة مع 419) | `api_exception.dart:120-128` (`isCsrfRejection`) | `site_contract_test.dart:608` (سبب skip قديم يذكر غياب الطابور) |

## 3. نصوص المشتريات المختلفة عن الموقع (#74)

**مصدر الموقع:**
- لقطة الموقع `docs/api/evidence/08-purchases.png` على `main`.
- ملف الموقع `PurchasesSection-BvxICuQj.js`. المقتطف المنشور منه موجود في #74 فقط (`docs/api/evidence/purchases-section-js-excerpt.md:9`)، وليس على `main`.

**مصدر التطبيق:** جرد QA على `main` `faa54fb`. بعد دمج المرحلة 8 (`f1dee47`) ما زالت هذه النصوص في `lib/ui/strings.dart` (تحقق نصي)، لكن #68 و#83 غيّرا `strings.dart` و`purchases_screen.dart`، فأرقام الأسطر أدناه من `faa54fb` وتحتاج إعادة تحقق من QA. النصوص نفسها باقية على رأس #74 `863622b`.

| # | التطبيق | الموقع | مرجع التطبيق | مرجع الموقع |
|---|---|---|---|---|
| 1 | «اليوم 18» | «يوم 18» | `purchases_screen.dart:231` (`todayTab` = «اليوم»، `strings.dart:177`) | اللقطة 08؛ JS `s("يوم #"),e.dayNumber` |
| 2 | «التصحيح مغلق» | «اليوم الحالي» لليوم المفتوح، و«مُرحّل» لليوم المرحّل | `strings.dart:131`؛ `purchases_screen.dart:737-739` | اللقطة 08؛ JS `e.correctionOpen?s("مفتوح للتعديل"):s("مُرحّل"):s("اليوم الحالي")` |
| 3 | «تصحيح مفتوح» | «مفتوح للتعديل» | `strings.dart:150`؛ `presentation.dart:238` | JS (السطر نفسه) |
| 4 | «فتح تصحيح اليوم» / «إغلاق تصحيح اليوم» | «تعديل اليوم» / «إنهاء تعديل اليوم» | `strings.dart:125-126`؛ `purchases_screen.dart:275` و`:286` | JS `s("إنهاء تعديل اليوم"):s("تعديل اليوم")` |
| 5 | «قسمة» / «ضرب» | «÷» / «×» | `strings.dart:163-164`؛ `purchases_screen.dart:458` و`:462` | اللقطة 08؛ JS `children:"÷"` و`children:"×"` |
| 6 | تأكيد الحذف: «تأكيد حذف هذا السطر» | «حذف المعاملة رقم {0}؟» | `strings.dart:338`؛ `purchases_screen.dart:848` | JS `confirm(s("حذف المعاملة رقم {0}؟",[t.sequence]))` |
| 7 | ثلاثة حوارات تأكيد لا وجود لها في الموقع: فتح التصحيح، وإغلاق التصحيح، وحفظ الرصيد الافتتاحي | الموقع فيه `confirm` واحد للحذف وواحد للترحيل فقط | `strings.dart:123-124` و`:127-130`؛ `purchases_screen.dart:276` و`:287` و`:689` | JS: لا يوجد إلا `confirm(` اثنان |
| 7أ | نص تأكيد الترحيل «تأكيد ترحيل اليوم؟» | «ترحيل اليوم سيحوّل معاملاته إلى قراءة فقط. هل تريد المتابعة؟» | `strings.dart:117`؛ `purchases_screen.dart:267` | JS |
| 8 | عنوان الشاشة «المشتريات» | «قسم المشتريات» | `strings.dart:266`؛ `purchases_screen.dart:38` | اللقطة 08؛ JS `s("قسم المشتريات")` |
| 9 | البند المخصص: الحقل «اسم النوع»، ورسالة «أدخل اسم النوع.» | الحقل «نوع آخر» ونصه المؤقت «آخر»، والرسالة «أكمل النوع والقيمة وسعر الصرف.» | `strings.dart:317-318`؛ `purchases_screen.dart:448` و`:496` | اللقطة 08 (`آخر`)؛ JS `"aria-label":s("نوع آخر")` و`placeholder:s("آخر")` |
| 10 | «الرصيد الافتتاحي» / «حفظ الرصيد الافتتاحي» على `main` | «ضبط البداية» / «حفظ البداية» | `strings.dart:118` و`:120` | أصلحه #74 جزئيًا. `openingConfirm` ما زال يذكر «الرصيد الافتتاحي» بحسب رسالة المطور. **غير مؤكد** على `863622b` |

العدد على `main` 10 بنود مرقّمة، بعضها زوجان: 4 و5 و7، فيصل المجموع إلى نحو 12 نصًا. الأرقام المعروضة لا تدخل في هذا القسم.

## 4. ما لم يُتحقق منه في هذه الجولة

- جرد QA الأول لم يشغّل الاختبارات على `faa54fb`. بعد دمج المرحلة 8، `tool/check.sh` نجح على فرع #84 بعد دمج `main` `f1dee47` (التطبيق +550 ~8، وapi_layer +503 ~16).
- لم تُرسل أي كتابة إلى staging. لذلك أثر G-04 وG-05 وG-06 على الخادم الحقيقي «متوقع من العقد» وغير مُجرَّب.
- سلوك #83 مختبر باختبارات الـ widget على Fake API فقط، لا على staging.
- G-16 حتى G-18 موثقة على `main` (#81) وما زالت مفتوحة.
- التخفيف المؤقت P-11 لـ DEF-037: لم يُعثر على PR له.
