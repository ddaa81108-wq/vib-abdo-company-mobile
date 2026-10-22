# سجل العيوب — جولة القبول على Fake API

التاريخ: 2026-10-20. الالتزام المفحوص: `fea12dd` ثم فرع القبول الذي يضيف الوثائق والاختبارات فقط.

لم يُغيَّر كود الإنتاج لإصلاح هذه العيوب. التصنيف:

- **Blocking:** يمنع قبول المرحلة على التسليم الحالي.
- **Non-blocking:** فجوة أو خطأ لا يكفي وحده لإسقاط معيار بوابة، أو أثره محدود، ويبقى مفتوحًا.

الشدة: حرجة / عالية / متوسطة / منخفضة.

## ملخص

| التصنيف | المعرّفات |
|---|---|
| Pending PM decision | DEF-002. على `main` `a5ca268` السلوك لم يتغير. الإداري المحدود ما زال `collections.decide`، ومسار الإجماليات المخصص يرفضه بـ 403. الاختبار `limited admin provider state is forbidden until DEF-002` |
| Blocking مفتوح على `main` | DEF-020 وDEF-022 على `a5ca268`. إصلاحهما على #53 و#55 ولم يُدمج. سداد مباشر 400 من رصيد 320 كان يُخزَّن −80، ورأس الدفتر كان يبقى 320 بعد 409 بينما المخزَّن 319. لا يبقى عيب مانع من DEF-013 أو DEF-014. هما verified on main 451ec58. لا مانع مفتوح للمرحلة 6 |
| عيب بديل اختبار، بلا أثر إنتاج | DEF-021. الشاشة كانت تُبطل `collectionsProvider` وتعيد قراءة النظرة. الصف يغيب لأن `FakeApiClient` لا يخزّن الإرسال. مفتوح على `main` حتى #54. سلوك الخادم الحقيقي ما زال فحص staging |
| Blocking على فرع وليس على `main` | لا يبقى. DEF-018 صار Verified closed على `main` `a5ca268` |
| Non-blocking مفتوح | DEF-012. ما زال Fail على `main` `a5ca268` لأن #27 لم يُدمج. البلاطات الثلاث نص بديل، والاختبار `DEF-012 admin settings replace the old unavailable sentence` يتوقع `employeesEmpty` و`auditEmpty` و`operationsEmpty`. خارج المرحلة 6. DEF-019 مفتوح على `main` `a5ca268`: فتح الإشعارات بعد دخول بإذن ممنوح يرسل رمز الجهاز مرة ثانية. غير مانع. DEF-023 وDEF-024 وDEF-025 تباين على `main`: العلامة الذهبية 1.59:1، ودور الشريط 1.02:1، ونص داكن 2.94:1 و2.72:1 ومبلغ الخزينة 2.95:1. غير مانعة |
| Verified closed على `main` `a5ca268` | DEF-017 وDEF-018. كانا مغلقين على الفرع فقط حتى دمج #46 و#47 |
| verified on main 8a52160 | DEF-010. «عرض الكل» يتبع قسم النشرة. ما زال مغلقًا على `a5ca268` (`DEF-010 view all opens the section it belongs to when readable`) |
| verified on main 451ec58 | DEF-001، DEF-003، DEF-004، DEF-005، DEF-006، DEF-013، DEF-014، DEF-015، DEF-016 |
| أُغلق بعد إعادة اختبار | DEF-007 وDEF-008 وDEF-009 وDEF-011 بقيت مغلقة ضمن المجموعة على `451ec58` |

---

### DEF-001 — `tool/check.sh` يفشل عند تحليل التطبيق

**الحالة:** Fixed in #15 — verified

| الحقل | القيمة |
|---|---|
| المرحلة | 1 |
| الشدة | عالية |
| التصنيف الأصلي | Blocking |
| الحالة بعد إعادة الاختبار | Fixed in #15 — verified |
| الملفات | `test/qa_round_test.dart:4` (أُزيل في PR #4 على `main`)؛ `packages/api_layer/lib/core/network/precise_json.dart:25`؛ `packages/api_layer/lib/core/realtime/polling_realtime_service.dart:8`؛ `packages/api_layer/lib/core/realtime/realtime_service.dart:4` و`:5`؛ `packages/api_layer/lib/data/models/home_models.dart:10` |

**خطوات الإعادة**

1. على `main` عند `fea12dd` ثبّت Flutter 3.47.7 / Dart 3.13.5.
2. من جذر المستودع شغّل `bash tool/check.sh`.

**المتوقع:** `flutter analyze` و`flutter test` للتطبيق ثم للحزمة يخرجان 0.

**الفعلي على `fea12dd`:** في تشغيل `tool/check.sh` خرج التحليل بـ 7 مشكلات (6 × `unintended_html_in_doc_comment` من المستوى info في تعليقات الحزمة، و1 × `unused_import` في `test/qa_round_test.dart:4`) ورمز 1. `set -e` يوقف السكربت قبل أي اختبار. إعادة `flutter analyze` لاحقًا من جذر التطبيق أظهرت التحذير وحده وما زالت تخرج 1. التفاصيل في `baseline-check-results.md`.

**إعادة الاختبار على PR #15 (2026-10-20):** الفرع `cursor/fix-def-001-doc-comments-cc17` عند `56156a8`، المبني على `main` بعد دمج PR #4 الذي أزال `unused_import`. Flutter 3.47.7 / Dart 3.13.5. `bash tool/check.sh` خرج **0**.

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | No issues found (9.4s) |
| `flutter test` للتطبيق | 72 ناجح، 0 فاشل |
| `flutter analyze` في `packages/api_layer` | No issues found (4.2s) |
| `flutter test` في `packages/api_layer` | 52 ناجح، 0 فاشل |

فرق PR #15 مقابل `main`: 4 ملفات، +5/−5، وكلها تعليقات توثيق تضع الأقواس الزاوية داخل علامات اقتباس مفردة للكود. لا تغيير في كود قابل للتنفيذ ولا تعطيل لأي قاعدة تحليل. `test/qa_round_test.dart` ليس في الفرق. الحكم: **Fixed in #15 — verified**. الطلب #15 صار مدمجًا في `main`.

**إعادة الاختبار على `main` (2026-10-21، `dff1456`):** `bash tool/check.sh` خرج **0**. تحليل التطبيق بلا مشكلات (5.6s) ثم 247 اختبارًا. تحليل `packages/api_layer` بلا مشكلات (0.8s) ثم 74 اختبارًا. الحكم يبقى **Fixed in #15 — verified**.

---

### DEF-002 — الإداري المحدود يرى الاعتماد والخادم التجريبي يرفضه

**الحالة:** Pending PM decision

| الحقل | القيمة |
|---|---|
| المرحلة | 3 |
| الشدة | عالية |
| التصنيف الأصلي | Blocking |
| الحالة بعد إعادة الاختبار | Pending PM decision. الاتساق تحقق على #24، وأُعيد على #34 و#35 في 2026-10-21، ولم يُغلق العيب |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart`؛ `lib/features/collections/collections_screen.dart` |

**خطوات الإعادة**

1. ادخل على Fake API باسم يبدأ بـ `limited.admin` وأي كلمة مرور غير `wrong`.
2. راقب `PermissionService`: `canDo(collections.decide)` يصبح `true` لأن الملف يرسل `collections.decide`.
3. استدعِ `POST` اعتماد استلام، مثل `collections.decide('sb_1', approve, expectedVersion: 1)`.

**المتوقع:** من تملك واجهته صلاحية `collections.decide` يقبل الخادم التجريبي الاعتماد، أو تُخفى الأزرار إذا كان الخادم يرفض الدور.

**الفعلي على `fea12dd`:** الواجهة تسمح. الخادم التجريبي يضبط `_admin = username.startsWith('admin')`. الاسم `limited.admin…` لا يطابق، فيُرجع `ForbiddenException` برمز `FORBIDDEN` ورسالة `هذا الإجراء للإدارة فقط` (403). أُكد بمسبار مؤقت على Fake API ثم حُذف المسبار.

**ملاحظة إعادة الاختبار على PR #17 (2026-10-20، `350e051`):** المسار لم يعد يرفض بـ 403، والحالة كانت تبقى `pending`.

**إعادة الاختبار على PR #24 (2026-10-21، `4260c16`، مبني على `main` وليس على #17):** الاتساق تحقق، والعيب يبقى **Pending PM decision**.

| الدور | الزر | الخادم |
|---|---|---|
| إداري محدود | `approve-sb_1` ظاهر، وبعد الضغط تختفي ويصبح الاستلام `approved` | `canDo(collections.decide)` true، والاعتماد يعيد الإصدار 2 |
| موظف | `approve-sb_1` و`cash-sb_2` و`close-batch` غائبة (`screens_ui_test`) | 403 |
| ضيف | فتح `/collections` يعيد الرئيسية بلا زر اعتماد | `canRead(collections)` false و`canDo(decide)` false، والاعتماد 403 |

القسم 4 من تحليل المشروع لا يسمّي «إداري محدود». أعمدته مدير كامل وموظف استلام فقط، ومفتاحه يقول: «عمود الشرط في الكود هو المرجع لأي دور مخصص.» وصف الاعتماد في 4.2: «اعتماد أو رفض استلام | 🔶 `collections.decide` + `pending` | ✅ | ❌»، و🔶 تعني «يعتمد على كود مقترح لم يؤكده الخادم.» ذكر الدور نفسه في القسم 3.4: «أما إداري محدود فهو سيناريو تصممه الصلاحيات المقترحة ولم يُعتمد بعد.» والسؤال المفتوح 3 يسأل هل تُضاف أكواد مثل `collections.decide` أم تبقى للمدير فقط. لذلك الإبقاء على الزر مع قبول الخادم متسق مع ملف الصلاحية، وقرار اعتماد هذا الدور لعَلي.

**إعادة الاختبار على `main` (2026-10-21، `dff1456`):** اختبار `DEF-002 limited admin has collections.decide and the server accepts it` ناجح ضمن 74. الإداري المحدود ما زال `canDo(collections.decide)` والاعتماد يخزّن `approved` والإصدار 2. الموظف ما زال بلا الصلاحية والاعتماد 403. السلوك لم يتغير. الحالة تبقى **Pending PM decision**. لم يُغلق.

**على `main` (`451ec58`):** الاختبار نفسه ناجح ضمن 87. الحالة تبقى **Pending PM decision**.

**على #34 (`5f530c3`) و#35 (`4a93595`)، 2026-10-21:** الإداري المحدود ما زال `canDo(collections.decide)`. على #35 اعتماد `sb_1` يعيد 200، و`approve-sb_1` و`reject-sb_1` ظاهران، ولوحة الإجماليات تضم `u_12` و`u_20`. مسار الإجماليات الجديد في #34 يرفضه بـ 403، وهذا باب آخر غير `collections.decide`. الحالة تبقى **Pending PM decision**. لم يُغلق. verified on #34 `5f530c377b89197982b1ae840e87f0b1ff6f567b` and #35 `4a93595d7d0783ef70637b4db82eeea70f8db554`, not on main.

**على #34 (`6038f0c`) و#37 (`63121ed`):** حالة الرفض في المزوّد صارت النص الموحّد، والشاشة في #37 تعرضه، والإداري المحدود ما زال يُرفض على مسار الإجماليات بينما `collections.decide` قائم. الحالة تبقى **Pending PM decision**. لم يُغلق. verified on #34 `6038f0c9be91090275751eee333432e8f4376d8c` and #37 `63121ed71517dcc0080d738efc1f2eb701779628`, not on main.

**على `main` (`8a52160`):** الاختبار `DEF-002 limited admin has collections.decide and the server accepts it` ناجح ضمن 139 اختبارًا للحزمة. اعتماد `sb_1` ما زال 200 عند الإداري المحدود، و`approve-sb_1` و`reject-sb_1` ظاهران، ولوحة الاستلامات تضم `u_12` و`u_20`. مسار `/settings/employee-totals` و`GET` المخصص يرفضانه بـ 403 والنص «القسم غير مصرح لهذا الحساب». هذا باب آخر غير `collections.decide`. الحالة تبقى **Pending PM decision**. لم يُغلق.

---

### DEF-003 — السداد الكامل لا يصفّر الرصيد على Fake API

**الحالة:** Verified على #24

| الحقل | القيمة |
|---|---|
| المرحلة | 2 |
| الشدة | عالية |
| التصنيف الأصلي | Blocking |
| الحالة بعد إعادة الاختبار | Verified على #24 |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (`_applyFullPayment`) |

**خطوات الإعادة**

1. ادخل كمدير على Fake API.
2. أرسل سدادًا كاملًا للكارت `c_55` عبر `AccountsRepository.addTransaction` مع `AccountTransactionRequest.fullPayment`.
3. أعد `GET` للكارت.

**المتوقع:** الخادم يصفّر الرصيد، والقراءة التالية تُظهر `balanceUnits = 0`.

**الفعلي على `fea12dd`:** الرد `MutationAck` ثابت `id=tx_new` و`version=5`. الرصيد بعد القراءة يبقى `320`.

**إعادة الاختبار على PR #24 (`4260c16`):** السداد الكامل بإصدار 4 يخزّن الرصيد 0 والإصدار 5.

**على فرع الدمج #26 (`589d645`):** القائمة 10 كروت. بعد سداد `c_55` الرصيد 0 والإصدار 5، و`c_56` يبقى 150، والملخص **10315**. إعادة نفس `requestId` تعيد النتيجة الأولى ويبقى الملخص 10315. `GET /api/home` يقرأ الملخص المخزَّن فيصير العملاء **10315** مثل القائمة، والأمانات المصرية تبقى 23750 في الجهتين. الحكم: **Verified**. `bash tool/check.sh` على #26 خرج 0: التطبيق 93/0 والحزمة 70/0.

**إعادة الاختبار على `main` (`dff1456`):** الاختبار نفسه ناجح: الرصيد 0 والإصدار 5 والملخص **10315**. مسبار `GET /api/home` بعد السداد نفسه: بطاقة العملاء **10315** والأمانات المصرية **23750**. الحكم يبقى **Verified**. نشرة الديون على `dff1456` كانت تبقى 320.

**على `main` (`451ec58`):** verified on main 451ec58. `DEF-003 full payment stores balance 0` ناجح. نشرة الرئيسية صارت تتبع الرصيد المخزَّن (DEF-016).

---

### DEF-004 — رأس الدفتر لا يُحدَّث بعد السداد الكامل، والقائمة لا تُحدَّث بعد الإلغاء

**الحالة:** Verified على #24

| الحقل | القيمة |
|---|---|
| المرحلة | 2 |
| الشدة | عالية |
| التصنيف الأصلي | Blocking |
| الحالة بعد إعادة الاختبار | Verified على #24 |
| الملفات | `lib/features/accounts/ledger_screen.dart` (`_full` و`_cancel`) |

**خطوات الإعادة**

1. افتح دفتر كارت (`LedgerScreen`). الرصيد في الرأس يأتي من `accountCardProvider`.
2. نفّذ سدادًا كاملًا من `_full`.
3. قارن مع مسار الحركة `_movement` الذي يُبطل `accountCardProvider`.
4. ألغِ حركة عبر `_cancel` ثم ارجع إلى القائمة.

**المتوقع:** بعد نجاح الخادم تُعاد قراءة الكارت والقائمة، فيظهر الرصيد الذي أعاده الخادم.

**الفعلي على `fea12dd`:** `_full` لا يُبطل `accountCardProvider`. `_cancel` يُبطل الدفتر فقط.

**إعادة الاختبار على PR #24 (`4260c16`):** بعد «سداد كلي» يختفي `320 د.ل` ويظهر `0 د.ل` في الرأس ثم في قائمة العملاء. بعد إلغاء `tx_2` يظهر `500 د.ل` في الرأس والقائمة ويختفي 320، لأن الخادم ينسخ `balanceAfterUnits` لآخر سطر `posted` (`tx_1` = 500) ويعلّم الحركة `reversed`. `_full` و`_cancel` يبطلان الدفتر والكارت والقائمة. الحكم: **Verified**. هذا التغيير في واجهة التطبيق وليس في #17.

**إعادة الاختبار على `main` (`dff1456`):** `DEF-004 cancel copies the stored balance of the latest posted line` و`DEF-004 cancel refreshes the header and the card list` ناجحان ضمن `tool/check.sh`. الحكم يبقى **Verified**.

---

### DEF-005 — اعتمادان بنفس `expectedVersion` ينجحان ولا تتغير الحالة

**الحالة:** Verified على #24

| الحقل | القيمة |
|---|---|
| المرحلة | 3 |
| الشدة | عالية |
| التصنيف الأصلي | Blocking |
| الحالة بعد إعادة الاختبار | Verified على #24 |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (`_applyDecision`)؛ `lib/features/collections/collections_screen.dart`؛ `lib/ui/widgets/mutation_form.dart` |

**خطوات الإعادة**

1. ادخل كمدير (`admin…`) على Fake API.
2. أرسل قرارين على `sb_1` كلاهما بـ `expectedVersion: 1` (اعتماد ثم رفض).
3. أعد قراءة نظرة الاستلامات.

**المتوقع:** القرار الثاني بإصدار قديم يُرفض برسالة تعارض واضحة، ولا يُطبَّق مرتين.

**الفعلي على `fea12dd`:** الطلبان ينجحان (`id=ok`, `version=1`). حالة `sb_1` تبقى `pending` والإصدار يبقى `1`.

**إعادة الاختبار على PR #24 (`4260c16`):** الاعتماد الأول لـ `sb_1` يجعل الحالة `approved` والإصدار 2. الطلب الثاني بالإصدار 1 يعيد 409 وتبقى الحالة. الحكم: **Verified** لاعتماد الاستلام المربوط.

**متابعة `6fe357e`:** النقد المربوط `sb_2` بإصدار 99 يعيد 409 ويبقى `pending` والإصدار 3؛ بالإصدار 3 يصبح `received` والإصدار 4. النقد غير المربوط `ur_1` بالإصدار 1 يصبح `received` والإصدار 2، ثم الإصدار 1 يعيد 409. قرار غير المربوط بإصدار 9 يُرفض وتبقى `pending` / 1، والاعتماد بالإصدار 1 يخزّن `approved` / 2، والرفض بالإصدار 1 يعيد 409. السداد الجزئي 100 من 320 يخزّن **220** والإصدار 5.

**متابعة إقفال اليوم على `fe0c56d` و`589d645`:** `POST /api/collections/days/close` بإصدار 99 يعيد 409 ويبقى `batchId` `b_1` والإصدار 1. الإصدار 1 ينجح: الرد إصدار 2 و`batchId` يصير `b_2`. إعادة الإصدار 1 تعيد 409 ويبقى `b_2` / 2. إقفال يوم المشتريات ما زال يرسل `expectedDayVersion`: الإصدار 1 يعيد 409 والمسودة تبقى 3، والإصدار 3 يخزّن `finalized` / 4.

**إعادة الاختبار على `main` (`dff1456`):** `DEF-005 a second decision with the same version is a conflict` و`close day compares the stored batch version through the repository` و`purchase day finalize stores the day version and rejects a stale one` ناجحة. الحكم على تعارض الاعتماد يبقى **Verified**. كتابة بند على اليوم المعتمد مسار آخر (DEF-014).

---

### DEF-006 — Fake API لا يطبّق صلاحيات القراءة والكتابة على الأقسام

**الحالة:** Verified على #17

| الحقل | القيمة |
|---|---|
| المرحلة | 2 (والاختبارات السلبية في مصفوفة الصلاحيات) |
| الشدة | عالية |
| التصنيف الأصلي | Blocking |
| الحالة بعد إعادة الاختبار | Verified على #17 |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (فحص القراءة والكتابة عبر `PermissionService`) |

**خطوات الإعادة**

1. ادخل كموظف استلام (`employee@example.invalid`). الواجهة تخفي الكتابة على العملاء وتخفي الخزينة.
2. أرسل سدادًا كاملًا على `c_55`.
3. اطلب `GET /api/treasury`.
4. ادخل بدور `guest` (صلاحية الواجهة فارغة) واطلب `GET /api/customers`.

**المتوقع:** الخادم يرفض الكتابة على قسم بلا `manage`، ويرفض قراءة قسم `sectionAccess = none` أو دورًا غير معروف.

**الفعلي على `fea12dd`:** سداد الموظف ينجح (`tx_new` / الإصدار 5) والرصيد يبقى 320. ملخص الخزينة يُعاد بنجاح. قائمة العملاء للضيف تُعيد عنصرًا واحدًا. الاستثناء الوحيد الملحوظ في هذا المسار هو `zero-review` الذي يستدعي `_requireAdmin()`. الإخفاء في الواجهة يعمل (انظر الحالات الناجحة في المرحلتين 1 و3) لكن القاعدة المعمارية تقول إن الإخفاء ليس تطبيقًا للصلاحية.

**إعادة الاختبار على PR #17 (2026-10-20):** الفرع `cursor/fake-api-qa-defects-566d` عند `350e051`. Flutter 3.47.7 / Dart 3.13.5. `bash tool/check.sh` خرج **0** (تحليل التطبيق والحزمة بلا مشكلات، اختبارات التطبيق **74/0**، اختبارات الحزمة **56/0**). التغطية في `packages/api_layer/test/fake_qa_defects_test.dart`.

| الاستدعاء | النتيجة على #17 |
|---|---|
| موظف: `POST` حركة على `c_55` | 403 `FORBIDDEN` |
| موظف: `GET /api/treasury` و`GET` ديون الشركات | 403 |
| موظف: `GET /api/customers` | 200 و`totalItems` = 10 |
| ضيف: `GET /api/customers` و`GET /api/treasury` | 403 |
| مدير: كتابة كارت `c_masraweya_remainder` | 403 |
| مدير: `GET /api/treasury` | 200 |

الحكم على `350e051`: **Verified** للاستدعاءات المطلوبة. في ذلك الالتزام كان `GET /api/home` بلا فحص قسم، فيستلم الضيف ملخص العملاء. الرصيد بعد حركة المدير ما زال 320 (DEF-003).

**متابعة على `c4edd59` (2026-10-20):** `GET /api/home` صار يحذف الملخص والعداد وصف الدين القديم إذا كان القسم غير مقروء. `bash tool/check.sh` خرج **0** (تحليل التطبيق 3.3s بلا مشكلات، **74/0**؛ تحليل الحزمة 0.6s بلا مشكلات، **57/0**). إعادة إنتاج محلية للأدوار الخمسة، وحُذف المسبار بعد التشغيل:

| الدور | ملخص الرئيسية | عداد العملاء | صف `c_55` | الخزينة والأمانات المصرية والتقارير |
|---|---|---|---|---|
| مدير كامل | العملاء 10635، الاستلامات 0، المصري 23750، الخزينة 8000، التقارير بلا مبلغ | 10 | ظاهر | ظاهرة |
| إداري محدود | العملاء 10635 والاستلامات 0 | 10 | ظاهر | غائبة |
| موظف استلام | العملاء 10635 والاستلامات 0 | 10 | ظاهر | غائبة |
| ضيف | فارغ | غائب | غائب | غائبة |
| `flag.admin` | فارغ | غائب | غائب | غائبة |

هذا يطابق مصفوفة القراءة. الحمولة لا تضم الشركات (1035) ولا الأمانات الليبية (695) ولا المصراوية ولا المشتريات حتى للمدير الكامل. الطلب #17 صار مدمجًا في `main`.

**إعادة الاختبار على `main` (`dff1456`):** `DEF-006 the fake server enforces the permission matrix with 403` ناجح. مسبار إضافي: `POST /api/treasury/cash-entries` من `employee.demo` يعيد 403 `FORBIDDEN`. الحكم يبقى **Verified**.

---

### DEF-007 — لا زر لرفض الاستلام غير المربوط ولا لتأكيد نقده

**الحالة:** Verified على #26 عند `aead4c5`

| الحقل | القيمة |
|---|---|
| المرحلة | 3 |
| الشدة | متوسطة |
| التصنيف الأصلي | Non-blocking |
| الحالة بعد إعادة الاختبار | Verified على #26 عند `aead4c5` |
| الملفات | `lib/features/collections/unlinked_receipt_actions.dart`؛ `packages/api_layer/lib/data/fake/fake_fixtures.dart` (`ur_2`) |

**خطوات الإعادة**

1. ادخل كمدير وافتح `/collections`.
2. على الاستلام غير المربوط `ur_1` (حالته `pending`) افحص الأزرار.
3. قارن مع مستودع الاستلامات: `decideUnlinked` يقبل الرفض، و`markUnlinkedCashReceived` موجود.

**المتوقع:** نطاق المرحلة 3 يطلب إضافة رفض الاستلام غير المربوط وتأكيد نقده، وهما موجودان في API.

**الفعلي على `fea12dd`:** الواجهة تعرض اعتمادًا وربطًا فقط عندما `manage && status == pending`. لا مفتاح زر رفض ولا زر نقد للاستلام غير المربوط. نص «ينتظر النقد» يُرسم إذا كان `cashStatus == pending` بلا إجراء.

**إعادة الاختبار على PR #26 (`aead4c5`، ويضم PR #3):** من `/collections` بكلمة `demo-only`. المدير يرى `unlinked-reject-ur_1` مع الاعتماد والربط، بلا نقد على `ur_1`، ويرى «تم استلام النقدية» على `unlinked-cash-ur_2` بلا رفض. الموظف لا يرى أزرارًا، و`decideUnlinked` و`markUnlinkedCashReceived` يعيدان 403 والحالة تبقى. الإصدار القديم يعيد 409 `VERSION_CONFLICT`، والواجهة تعرض «تم تعديل البيانات. أُعيد الجلب من الخادم.» وتعيد الجلب. الإداري المحدود يرى الرفض (والاعتماد والربط) والخادم يقبل الرفض، ولا يرى النقد والخادم يعيد 403. ظهور الرفض عنده متسق مع DEF-002 ويبقى **Pending PM decision** ولم يُغلق. الحكم على زرّي المدير والموظف ومطابقة الخادم: **Verified**. هذا يغلق P3-11.

---

### DEF-008 — لا يمكن تمرير `mustChangePassword` على Fake API

**الحالة:** Verified على #17

| الحقل | القيمة |
|---|---|
| المرحلة | 1 |
| الشدة | متوسطة |
| التصنيف الأصلي | Non-blocking |
| الحالة بعد إعادة الاختبار | Verified على #17 |
| الملفات | `packages/api_layer/lib/data/fake/fake_fixtures.dart` (حساب `mustchange`)؛ `packages/api_layer/lib/data/fake/fake_api_client.dart` (مسح العلم بعد التغيير) |

**خطوات الإعادة**

1. ادخل بأي اسم تجريبي.
2. اقرأ `mustChangePassword` من الجلسة.
3. استدعِ تغيير كلمة المرور ثم أعد قراءة الملف.

**المتوقع:** يمكن إحضار مستخدم العلم له `true` فيُجبر على `/change-password`، وبعد النجاح يمسح الخادم العلم.

**الفعلي على `fea12dd`:** كل ملفات `FakeFixtures._me` تضع `mustChangePassword: false`. `POST /api/auth/change-password` يعيد نجاحًا فارغًا ولا يغيّر الملف. منطق الموجّه نفسه مغطى في `test/authentication/auth_gate_test.dart` بحالة جلسة مبنية في الاختبار، لذلك العيب يمنع التجربة من طرف إلى طرف على Fake API ولا يلغي وجود البوابة.

**إعادة الاختبار على PR #17 (`350e051`):** حساب `mustchange.demo` يعيد `mustChangePassword: true`. اختبار الحزمة يؤكد أن `change-password` يمسح العلم وأن إعادة الدخول تبقيه false، وأن بقية الحسابات تبقى false. اختبار الودجت `test/fake_server_defects_test.dart` يبقي الشاشة على `ChangePasswordScreen` بعد `go('/customers')`، ثم بعد كلمة المرور الحالية `demo-only` والجديدة `new-password-1` يفتح الرئيسية. الحكم: **Verified**. هذا يغلق P1-04.

---

### DEF-009 — تسمية عمر الدين في الكارت التجريبي تخالف عدد الأيام

**الحالة:** Verified على #17

| الحقل | القيمة |
|---|---|
| المرحلة | 2 |
| الشدة | منخفضة |
| التصنيف الأصلي | Non-blocking |
| الحالة بعد إعادة الاختبار | Verified على #17 |
| الملفات | `packages/api_layer/lib/data/fake/fake_fixtures.dart` (`c_55` والتسمية المشتقة من عدد الأيام) |

**خطوات الإعادة**

1. افتح قائمة العملاء على Fake API.
2. اقرأ شارة `ageStatusLabel` وسطر `debtAgeDays`.

**المتوقع:** الحقلان اللذان يرسلهما الخادم متسقان، أو تعرض الواجهة تسمية الخادم وحدها.

**الفعلي على `fea12dd`:** الكارت التجريبي يرسل `debtAgeDays: 4` و`ageStatus: warning` و`ageStatusLabel: مرّ عليه 3 أيام`. البطاقة تعرض التسمية ثم «منذ 4 أيام» عبر `sinceDays`. اللون يتبع `warning` وهذا صحيح. نشرة الرئيسية لنفس الكارت تستخدم التسمية «منذ 4 أيام» فتختلف عن قائمة الكروت.

**إعادة الاختبار على PR #17 (`350e051`):** `c_55` يرسل عمرًا واحدًا: `debtAgeDays` = 4 والتسمية «منذ 4 أيام»، والنشرة تطابق القائمة. اختبار الحزمة يثبت ذلك، واختبار الودجت لا يجد «مرّ عليه 3 أيام» ويجد «منذ 4 أيام». الحكم: **Verified**. الواجهة ما زالت ترسم التسمية وسطر `sinceDays` معًا، والنصان الآن متطابقان. خانة P4-04 (حذف بند مشتريات) لم تُنفَّذ؛ هذا الإغلاق يخص عمر `c_55` في المرحلة 2.

---

### DEF-010 — «عرض الكل» في الرئيسية يفتح العملاء دائمًا

| الحقل | القيمة |
|---|---|
| المرحلة | 1 |
| الشدة | منخفضة |
| التصنيف | Non-blocking |
| الحالة بعد إعادة الاختبار | verified on main 8a52160 |
| الملفات | `lib/ui/section_labels.dart` (`homeShowAllPath`) و`lib/features/home/home_dashboard.dart` |

**خطوات الإعادة**

1. جهّز مستخدمًا يقرأ ديون الشركات ولا يقرأ ديون العملاء، مع `oldDebts` غير فارغة.
2. اضغط «عرض الكل».

**المتوقع:** الانتقال إلى القسم الذي تخصه النشرة الظاهرة.

**الفعلي على `fea12dd`:** الزر كان يستدعي `context.go('/customers')` كلما وُجدت `oldDebts` وكان للمستخدم قراءة عملاء أو شركات. قارئ الشركات فقط يُعاد إلى الرئيسية لأن `/customers` ممنوع. ملف الموظف التجريبي يقرأ العملاء، لذلك المسار التجريبي آنذاك لا يُظهر العيب.

**إعادة الاختبار على `main` (`8a52160`):** verified on main 8a52160. `homeShowAllPath` يعيد `/${section}` عندما تكون القراءة مسموحة، و`null` عندما تُمنع، فيختفي الزر. `home_dashboard.dart` يستدعي هذه الدالة ثم `context.go`. اختبار `DEF-010 view all opens the section it belongs to when readable` في `test/shell_group_test.dart` ناجح ضمن 291. شركات وعملاء معًا: `/companies` و`/customers`.

---

### DEF-011 — تكرار `requestId` يُقبل كنجاح ثانٍ

**الحالة:** Verified على #17

| الحقل | القيمة |
|---|---|
| المرحلة | 2 |
| الشدة | متوسطة |
| التصنيف الأصلي | Non-blocking |
| الحالة بعد إعادة الاختبار | Verified على #17 |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (مخزن نتيجة `requestId`) |

**خطوات الإعادة**

1. أرسل حركتين لجسم السداد الكامل بنفس `requestId` ونفس `expectedVersion`.

**المتوقع:** الإرسال الثاني بنفس المعرّف لا ينشئ أثرًا ثانيًا (إعادة لنفس النتيجة).

**الفعلي على `fea12dd`:** الطلبان ينجحان وكلاهما `tx_new` / الإصدار 5، ويُضاف المعرّف مرتين إلى `mutationRequestIds`. لا توجد حالة مخزّنة أصلًا (DEF-003) فلا تُنشأ حركتان ظاهرتان، لكن الخادم التجريبي لا يطبّق منع التكرار. قفل الواجهة يمنع النقرة المزدوجة أثناء الإرسال (`test/write_safety_test.dart`) وهذا الجزء ناجح.

**إعادة الاختبار على PR #17 (`350e051`):** الإرسال الثاني بنفس `requestId` يعيد جسم النجاح الأول ولا يعيد تنفيذ الحركة، و`mutationRequestIds` يحتفظ بالمعرّف مرة واحدة. إعادة الإرسال لا تستهلك `failMutationsRemaining`. فشل سابق بنفس المعرّف لا يُخزَّن، فإعادة المحاولة تنجح ثم يُسجَّل المعرّف. الحكم: **Verified**. الرصيد المخزَّن لا يتغير (DEF-003 ما زال مفتوحًا)؛ الإغلاق يخص إعادة النتيجة لا تصفير الرصيد.

---

### DEF-012 — شاشات الإعدادات الإدارية نص «لا تتوفر بيانات» فقط

| الحقل | القيمة |
|---|---|
| المرحلة | 5 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `lib/features/settings/settings_screen.dart:32-34`؛ `lib/ui/strings.dart:109-110` |

**خطوات الإعادة**

1. ادخل كمدير كامل وافتح `/settings`.

**المتوقع:** عند قبول المرحلة 5 تعرض شاشات الموظفين وسجل التدقيق ومركز التشغيل بيانات الخادم، أو تُزال بقرار مكتوب.

**الفعلي:** البلاطات الثلاث تعرض `AppStrings.unavailable`: «لا تتوفر بيانات من الخادم لهذه الشاشة في تطبيق الجوال.» المرحلة 5 لم تُنفَّذ في هذه الجولة؛ العيب مسجّل لأنه ظاهر في الكود الحالي. سجل الأستاذ المالي له مسار تحميل مستقل (`financial-ledger`) وليس هذا النص.

**إعادة الاختبار على `main` (`dff1456`):** الجملة العامة ومفاتيح `LYD` / `EGP` اختفت. `P4-003 settings empty states and Arabic ledger labels` و`DEF-012 admin settings replace the old unavailable sentence` ناجحان: الإجماليات «0 د.ل» و«0 ج.م»، والبلاطات تعرض `employeesEmpty` و`auditEmpty` و`operationsEmpty`. المتوقع في P4-003 ما زال بيانات أو إخفاء البلاطة، فلم يتحقق. العيب يبقى مفتوحًا وغير مانع. لا يُغلق قبل المرحلة 5 أو قرار مكتوب بإزالة الشاشات.

**على `main` (`451ec58`):** ما زال **Fail**. #27 لم يُدمج. `P4-003 settings empty states and Arabic ledger labels` ينجح لأنه يتوقع النص البديل: البلاطات تعرض `employeesEmpty` و`auditEmpty` و`operationsEmpty`، والإجماليات «0 د.ل» و«0 ج.م» بلا مفاتيح ظاهرة. المعيار (بيانات أو إخفاء البلاطة) لم يتحقق. بانتظار قرار علي.

**إعادة الاختبار على PR #27 (2026-10-21، `5d9700f`، فوق `main`، ليس على `main` بعد):** الحكم **Fail**. لم يُعلَّم verified. `bash tool/check.sh` خرج 0 (التطبيق 250/0، الحزمة 74/0).

| الفحص | النتيجة |
|---|---|
| مدير كامل، فاتح وداكن | سجل الأستاذ من Fake: «0 د.ل» و«0 ج.م»، بلا نص `LYD` أو `EGP` (`the financial ledger tile shows the server totals`) |
| الموظفون والتدقيق والتشغيل | `EmptyPane` ونص `employeesEmpty` / `auditEmpty` / `operationsEmpty`. لا قائمة من الخادم (`employees, audit, and operations use an empty pane`). التعليق في `admin_destinations.dart` يقول إن Fake لا يرسل هذه البيانات |
| إداري محدود | بلا `settings.manage`. `/settings` والبلاطات الثلاث غائبة (`admin tiles stay hidden without settings.manage` و`limited admin has no settings entry`) |
| موظف وضيف و`flag.admin` | لا يرون الإعدادات (`an employee does not see settings or admin routes` و`guest and flag admin see no sections and no settings`) |

المعيار في `phase-4-ui.md` يطلب بيانات حقيقية أو إخفاء البلاطة، وبلا نص بديل. البلاطات الثلاث ما زالت ظاهرة للمدير الكامل وبنص بديل. العيب يبقى مفتوحًا وغير مانع.

**على `main` (`8a52160`):** ما زال **Fail**. #27 ليس على `main`. المسارات `/settings/employees` و`/settings/audit` و`/settings/operations` تعرض `AdminPlaceholderScreen` بنصوص `employeesEmpty` و`auditEmpty` و`operationsEmpty`. `P4-003 settings empty states and Arabic ledger labels` ينجح لأنه يتوقع هذا النص البديل، والمعيار (بيانات أو إخفاء البلاطة) لم يتحقق. غير مانع. بانتظار قرار علي.

---

### DEF-013 — لا نموذج لحفظ يوم المصراوية، و`PUT` لا يخزّن القيم

**الحالة:** verified on main 451ec58

| الحقل | القيمة |
|---|---|
| المرحلة | 4 |
| الشدة | عالية |
| التصنيف | Blocking |
| الملفات | `lib/features/masraweya/masraweya_screen.dart`؛ `packages/api_layer/lib/data/fake/fake_api_client.dart` (مسار `masraweya`) |

**خطوات الإعادة**

1. ادخل كمدير وافتح شاشة المصراوية.
2. ابحث عن نموذج الحفظ أو زر يرسل `saveDay`.
3. أرسل `PUT /api/masraweya/day` مع `previousValueUnits: 1` و`expectedVersion: 2` ثم أعد `GET`.

**المتوقع:** نموذج يحفظ قيم اليوم، وإعادة الفتح تعرض ما خزّنه الخادم بلا حساب محلي للمتبقي. غياب النموذج عيب نطاق لا نجاحًا (P4-07).

**الفعلي على `dff1456`:** الشاشة عمود قراءة (`screen-masraweya`) بلا حقل إدخال ولا زر حفظ. `PUT` يعيد ملف اليوم الثابت (`previousValueUnits` 10000، المشتريات 2000، إجمالي العمل 3050، المتبقي 8950، الإصدار 2). `GET` التالي يطابق ذلك ولا يحتفظ بالقيمة 1. العرض نفسه من حقول الخادم، وهذا الجزء لا يُحتسب نجاحًا للمعيار.

**إعادة الاختبار على PR #31 (`636ef4b`، فوق `main`، ليس على `main` بعد):** verified on #31 636ef4b, not yet on main. `bash tool/check.sh` خرج 0 (التطبيق 252/0، الحزمة 78/0).

المدير يحفظ من النموذج. `DEF-013 PUT stores the submitted day and GET returns it`: القيمة السابقة 1 والمشتريات 9 والإصدار يصير 3، و`GET` يعيد ذلك. `saving the day sends raw inputs and refreshes server values`: الواجهة تعرض «1 ج.م» و«9 ج.م» بعد التأكيد، والجسم فيه `requestId` و`expectedVersion` 2. إصدار قديم يعيد 409 `VERSION_CONFLICT` ولا يغيّر اليوم (`DEF-013 a stale expectedVersion is VERSION_CONFLICT`). إعادة نفس `requestId` تعيد اليوم الأول ولا تطبّق القيمة الثانية. الموظف و`limited.admin.demo` و`guest.demo` بلا قراءة ولا كتابة: `GET` و`PUT` يعيدان 403، والنموذج يختفي بلا `masraweya.write` (`the save form is visible only with write permission`). `workTotal` يبقى 3050 و`remaining` يبقى 8950 لأن لا صيغة معتمدة. هذا **سؤال مفتوح** وليس عيبًا.

**على `main` (`451ec58`):** verified on main 451ec58. الدمج `#31` عند رأس `main`. `DEF-013 PUT stores the submitted day and GET returns it` و`saving the day sends raw inputs and refreshes server values` و`a version conflict refetches and the next save uses the new version` ناجحة ضمن 260/87. سؤال الصيغة يبقى مفتوحًا.

---

### DEF-014 — Fake API يقبل كتابة بند على يوم مشتريات معتمد

**الحالة:** verified on main 451ec58

| الحقل | القيمة |
|---|---|
| المرحلة | 4 |
| الشدة | عالية |
| التصنيف | Blocking |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (مسار `purchases` بعد `_requireWrite`)؛ `lib/features/purchases/purchases_screen.dart` (`dayIsEditable`) |

**خطوات الإعادة**

1. ادخل كـ`admin.demo` على Fake API.
2. `POST /api/purchases/al_bayan/finalize` مع `expectedDayVersion: 3`. اليوم يصبح `finalized` والإصدار 4.
3. أرسل إضافة بند ثم `PATCH` ثم `DELETE` على `pe_1` بالإصدار 4.
4. أعد `GET /api/purchases/al_bayan`.

**المتوقع:** الواجهة تخفي أزرار البند، والخادم يرفض التجاوز على اليوم المعتمد (P4-01).

**الفعلي على `dff1456`:** الواجهة تخفي الإضافة والتعديل والحذف عندما لا يكون اليوم قابلًا للتحرير، وتبدّل الاعتماد إلى `open-correction-12`. الطلبات الثلاثة من API تعيد **200** `{id: pe_new, version: 4}`. الدفتر يبقى `finalized` / الإصدار 4 وبندًا واحدًا. لا 409 ولا 403.

**إعادة الاختبار على PR #30 (`fe69157`، فوق `main`، ليس على `main` بعد):** verified on #30 fe69157, not yet on main. `bash tool/check.sh` خرج 0 (التطبيق 251/0، الحزمة 79/0).

`DEF-014 finalized purchase day rejects entry create update and delete`: بعد الاعتماد الإصدار 4، الإضافة والتعديل والحذف كل منها 409 `DAY_FINALIZED`، وبصمة الدفتر لا تتغير. إعادة نفس `requestId` الذي نجح على المسودة لا تتجاوز الرفض (`DEF-014 a stored requestId does not bypass the finalized-day check`). الواجهة تخفي `add-purchase-12` و`edit-pe_1` و`delete-pe_1` وتبقي `open-correction-12` (`a finalized purchases day hides add edit and delete`). حفظ أو حذف بعد الاعتماد يعرض رسالة الخادم لا رسالة تعارض الإصدار. الموظف و`limited.admin.demo` و`guest.demo` يأخذون 403 قبل ذلك لأنهم بلا `purchases.write`. يوم `correction` يبقى قابلًا للكتابة.

**على `main` (`451ec58`):** verified on main 451ec58. الدمج `#30` هو `52d12c2`. `a finalized purchases day hides add edit and delete` ناجح ضمن المجموعة.

---

### DEF-015 — قبض الخزينة وصرفها لا يظهران في دفتر النقد

**الحالة:** verified on main 451ec58

| الحقل | القيمة |
|---|---|
| المرحلة | 4 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (مسار `treasury` للكتابة)؛ `lib/features/treasury/treasury_screen.dart` |

**خطوات الإعادة**

1. ادخل كمدير وأرسل `POST /api/treasury/cash-entries` قبضًا (`direction: in`، `amountUnits: 1250`، `expectedVersion: 7`) ثم صرفًا.
2. اقرأ `GET /api/treasury/cash-ledger` و`GET /api/treasury`.
3. كرر الكتابة كـ`employee.demo`.

**المتوقع:** الحركتان تظهران في دفتر النقد كما أعادهما الخادم، والموظف ممنوع (P4-08).

**الفعلي على `dff1456`:** الردان `{id: ce_new, version: 8}`. الدفتر يبقى `[ce_1]` والملخص يبقى الإصدار 7 و`activeCashUnits` 8000. الموظف: 403 `FORBIDDEN`، والزر مخفي في اختبارات الواجهة. نصف المنع ناجح، وظهور الحركة فاشل. غير مانع لأن أولوية المعيار متوسطة ونصف الصلاحية يعمل.

**إعادة الاختبار على PR #28 (`002db97`، فوق `main`، ليس على `main` بعد):** verified on #28 002db97, not yet on main. `bash tool/check.sh` خرج 0 (التطبيق 248/0، الحزمة 76/0).

`DEF-015 cash in and cash out are returned by the ledger`: قبض 1250 يعيد `ce_8` والإصدار 8. إعادة نفس `requestId` لا تضيف سطرًا. إصدار 7 بعد ذلك يعيد 409 `VERSION_CONFLICT`. الصرف 200 يعيد `ce_9` والإصدار 9. الدفتر `[ce_9, ce_8, ce_1]`، والنقد النشط 9050، والصافي 52050، والإصدار 9. الواجهة `DEF-015 cash in and cash out refresh the ledger and the summaries` ترسم `cash-entry-ce_8` بمبلغ 1,250 د.ل وبطاقة النقد 9,250 د.ل ثم `ce_9`. الموظف و`limited.admin.demo` و`guest.demo`: قراءة الخزينة و`POST` يعيدان 403، والأزرار مخفية عمن بلا `treasury.write`.

**على `main` (`451ec58`):** verified on main 451ec58. الدمج `#28` هو `45adda5`. `DEF-015 cash in and cash out refresh the ledger and the summaries` ناجح ضمن المجموعة.

---

### DEF-016 — نشرة الديون في الرئيسية تبقى على رصيد الملف بعد السداد

**الحالة:** verified on main 451ec58

| الحقل | القيمة |
|---|---|
| المرحلة | 2 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (`_homeForSignedInUser`)؛ `lib/features/home/home_dashboard.dart` (`_DebtRow`) |

**خطوات الإعادة**

1. ادخل كمدير. `GET /api/home` قبل السداد: ملخص العملاء 10635 وصف `c_55` رصيده 320.
2. أرسل سدادًا كاملًا لـ`c_55` بالإصدار 4.
3. أعد `GET /api/home` وقارن ملخص العملاء مع `oldDebts`.

**المتوقع:** ملخص العملاء يتبع الرصيد المخزَّن. صف النشرة للحساب نفسه لا يبقى على 320 بعد تصفير الكارت.

**الفعلي على `dff1456`:** الملخص يصبح **10315** والأمانات المصرية تبقى **23750**، وهذا يطابق P2-03. `oldDebts` يبقى `c_55` برصيد **320** لأن النشرة تُنسخ من ملف الرئيسية ولا تُحدَّث من رصيد الكارت المخزَّن. الواجهة ترسم `debt.balanceUnits`. لا يعيد فتح DEF-003 ولا يغيّر قرار المرحلة 2.

**إعادة الاختبار على PR #29 (`5b27815`، فوق `main`، ليس على `main` بعد):** verified on #29 5b27815, not yet on main. `bash tool/check.sh` خرج 0 (التطبيق 250/0، الحزمة 76/0).

`DEF-016 home debt rows copy the stored card balance`: بعد السداد الكامل رصيد الكارت 0 وصف النشرة 0، والملخص 10315، والمصري 23750. السداد الجزئي 100 يجعل الكارت والنشرة **220**. الواجهة `DEF-016 full payment no longer shows the 320 home debt row` لا تعرض «320 د.ل» بعد السداد الكلي وتعرض الصفر. `limited.admin.demo` و`employee.demo` يقرآن الصف 220 بعد سداد المدير على العميل نفسه. `guest.demo` بلا `oldDebts`. الصف يبقى ظاهرًا عند الصفر. اختفاؤه عند الصفر **سؤال مفتوح لمدير المشروع** وليس عيبًا.

**على `main` (`451ec58`):** verified on main 451ec58. الدمج `#29` هو `86362f9`. `DEF-016 home debt rows copy the stored card balance` و`DEF-016 full payment no longer shows the 320 home debt row` ناجحان. السؤال المفتوح يبقى.

---

### DEF-017 — 401 أثناء ابتلاع الدفع يخرج من `presentPush` بلا `sessionEnded`

**الحالة:** Verified closed on main `a5ca26809578dd013430dcaae78c517043e95491`. كان مغلقًا على `cc1bc83` و#46 `f6fa327` و#47 `da9183c` قبل أن يصل الكود مع دمج #46. كان Open على `82e0e8c`. غير مانع حين كان مفتوحًا. التالي الحر DEF-020.

| الحقل | القيمة |
|---|---|
| المرحلة | 6 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `lib/notifications/system_tray_presenter.dart` (`presentPush`، الـ `try` يلف `reload` فقط)؛ `lib/notifications/notification_ingress.dart` (`acceptPush` يستدعي `ingest` قبل الـ `try`)؛ `lib/state/notification_providers.dart` (`ingest` عند `NotificationSource.push` يستدعي `_resolveUnread`، و`SessionExpiredException` يُعاد رميه)؛ `lib/notifications/notification_transport_host.dart` (`unawaited(presentPush)`) |

**خطوات الإعادة**

1. على Fake ادخل `employee.demo` بكلمة مرور غير `wrong`.
2. استدعِ `FakeApiClient.expireSession()`.
3. استدعِ `systemTrayPresenterProvider.presentPush` بحمولة مبيّضة لمعرّف `77` ومستلم `u_12`، وفيها `employeeName` و`amount`.

**المتوقع:** لا صينية، ولا اسم الحساب السابق، و`TrayDelivery.sessionEnded`، و`expireSession` / `session_expired` مرة واحدة.

**الفعلي على `82e0e8c`:** لا صينية، والسبب `session_expired` مرة واحدة، ونداء ثانٍ يرجع `loggedOut` بلا مسح ثانٍ. لكن `SessionExpiredException` (`AUTH_REQUIRED`، 401) تخرج من `DioApiClient._send` عبر عدد غير المقروء داخل `acceptPush`، قبل `try` في `presentPush`. المضيف يستدعي `presentPush` بلا انتظار، فالخطأ غير ممسوك. اختبار المؤلف `a failed GET or a 404 shows no name, and a 401 shows nothing` يحقن `SessionExpiredException` من `reload` نفسه، وذلك داخل `try` ويرجع `sessionEnded`، ولا يستدعي `expireSession`. المسبار المحلي غير المدفوع `a 401 on the refresh GET posts nothing and expires the session once` أثبت الرمي على المزوّد الموصول. لا اسم ولا مبلغ يُرسم. لذلك العيب غير مانع: نصف الأمان (لا عرض، وخروج واحد) قائم، ونصف «لا يرمي» على المسار الموصول فاشل.

**إعادة الاختبار على `cc1bc83`:** `presentPush` يلف `acceptPush` داخل `try`. 401 و419 غير CSRF يرجعان `TrayDelivery.sessionEnded` من المزوّد الحقيقي `systemTrayPresenterProvider`، بلا صينية، وبلا خطأ منطقة، و`session_expired` مرة واحدة، والنداء الثاني `loggedOut`. خروج الجلسة يحدث في `AuthInterceptor` قبل رجوع الدالة، و`onError` الفارغ في المضيف لا يُستدعى على هذا المسار فلا يبتلع خروجًا. 419 الذي يحمل `CSRF` يحدّث الرمز مرة ولا يخرج. 401 على الدخول يبقى `INVALID_CREDENTIALS`. فشل جلب الصف صينية بلا اسم، و404 لا شيء. الحكم: **Verified closed** على هذا الرأس، وليس على `main`.

**إعادة الاختبار على #46 `f6fa327`:** نفس سيناريوهات المسبار (401، و419 `PAGE_EXPIRED`، و419 CSRF، و500، و404، و401 الدخول) ما زالت Pass على المزوّد الموصول. `realtime_lifecycle.dart` طابق `main`، وخطاف 419 بقي. الحكم يبقى **Verified closed** على الفرع وليس على `main`. تعليم القراءة عند `forbidden` لنفس المستخدم خيار لمدير المشروع وليس إعادة فتح لهذا العيب.

**على #47 `3f8e009`:** سيناريوهات DEF-017 ما زالت Pass. لم يُعد فتح DEF-017. التالي الحر صار DEF-019 بعد فتح DEF-018.

**على #47 `da9183c`:** المسبار نفسه **7/0**. لم يُعد فتح DEF-017. DEF-018 أُغلق في القسم التالي، وDEF-019 فُتح. التالي الحر DEF-020.

**على `main` `a5ca268`:** شجرة الدمج تطابق `da9183c`. المسبار المحلي غير المدفوع `test/qa_def017_retest_probe_test.dart` خرج **7/0** على المزوّد الموصول: 401 على جلب العدد يخرج مرة، و419 `PAGE_EXPIRED` كذلك، و419 CSRF يحدّث الرمز بلا خروج، و500 بلا اسم، و404 بلا صينية، و401 الدخول يبقى `INVALID_CREDENTIALS`، ومسار المضيف يخرج مرة ثم كلمة المرور الخاطئة لا تخرج. الحكم: **Verified closed** على `main`.

---

### DEF-018 — موافقة إذن الإشعار لا ترسل تسجيل الجهاز

**الحالة:** Verified closed on main `a5ca26809578dd013430dcaae78c517043e95491`. كان Verified closed على #47 `da9183c` قبل الدمج، وOpen وBlocking على `3f8e009`. التالي الحر DEF-020.

| الحقل | القيمة |
|---|---|
| المرحلة | 6 |
| الشدة | عالية |
| التصنيف | Blocking لـ #47، وليس على `main` |
| الملفات | `lib/app.dart` (`ProviderScope` الداخلي يبدّل `notificationPermissionProvider`)؛ `lib/notifications/push_providers.dart` (`deviceTokenRegistrarProvider` بلا `dependencies`)؛ `lib/notifications/device_token_registrar.dart` (`registerIfReady` يرجع إن لم يكن `permission.granted`)؛ `lib/features/notifications/notification_permission_registration.dart` |

**خطوات الإعادة**

1. على #47 ادخل `employee.demo`.
2. اجعل نقل الدفع `FakePushTransport` برمز غير فارغ، والإذن يبدأ `denied` ثم يصير `granted` بعد الموافقة.
3. لا تستبدل `deviceTokenRegistrarProvider`.
4. افتح `/notifications` واضغط موافقة الإذن.
5. اقرأ `permission.granted` على المسجّل الذي تراه الشاشة، وعدّ استدعاءات `DeviceRegistrationClient.register`.

**المتوقع:** طلب واحد إلى `POST /api/mobile-push/devices` يحمل ذلك الرمز.

**الفعلي:** المسجّل في الجذر وفي الشاشة هو نفسه، والنقل `fake`، و`permission.granted` يبقى false لأن الحاوية الجذر ما زالت على `StubNotificationPermissionService`. `registered` فارغة. اختبارات المؤلف تمر لأنها تستبدل المسجّل ولا تفحص الإرسال.

على المسجّل مباشرة، إذا مُنح الإذن في بنائه: النداء مرتين يرسل الرمز نفسه مرتين بلا مقارنة مع المخزن. 401 بعد ذلك يعطي `session_expired` مرة. 403 يبقي الجلسة ولا يطبع الرمز. فشل الشبكة طلب POST واحد بلا إعادة. هذه المسارات لا تصل من زر الموافقة اليوم.

**إعادة الاختبار على `da9183c`:** `buildAppRoot` في `lib/main.dart` يضع `notificationPermissionRegistrarOverride()` على نطاق الجذر، و`runApp` يستدعي هذه الدالة. المسبار على هذه الدالة، بالمسجّل الحقيقي و`FakePushTransport`، بلا `RecordingDeviceTokenRegistrar`. الموافقة على API 33 ترسل `POST /api/mobile-push/devices` مرة واحدة وفي الجسم الرمز، والرمز لا يُطبع ولا يُرسم. «لاحقًا» والرفض الدائم والرفض بعد الموافقة لا ترسل. الحكم حينها: **Verified closed** على هذا الرأس.

**على `main` `a5ca268`:** `git diff da9183c a5ca268` فارغ. `lib/main.dart` يستدعي `runApp(buildAppRoot(...))` والتبديل على نطاق الجذر. المسبار `Agree posts the token once on the real root registrar` و`Later and permanent denial post nothing and the list stays` و`permanent denial posts nothing and the list stays` و`Android 33 denial after Agree posts nothing` ناجحة. الحكم: **Verified closed** على `main`. تكرار الإرسال عند فتح الشاشة بعد دخول بإذن ممنوح هو DEF-019، وليس إعادة فتح لهذا العيب.

---

### DEF-019 — فتح الإشعارات بعد دخول بإذن ممنوح يرسل الرمز مرة ثانية

**الحالة:** Open on main `a5ca26809578dd013430dcaae78c517043e95491`. غير مانع. كان مفتوحًا على #47 `da9183c` قبل أن يصير الكود على `main`. التالي الحر DEF-020.

| الحقل | القيمة |
|---|---|
| المرحلة | 6 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `lib/features/notifications/notification_permission_registration.dart` (`NotificationPermissionSync` يتذكر الاختيار فقط، ويبدأ فارغًا)؛ `lib/notifications/notification_transport_host.dart` (`syncPushRegistration` يرسل عند الدخول)؛ `lib/features/notifications/notifications_screen.dart` (`_maybeExplain` يستدعي المزامنة عندما تكون الحالة `granted`) |

**خطوات الإعادة**

1. على #47 `da9183c` ابنِ الجذر بـ `buildAppRoot` كما يفعل `main`.
2. API 33، والإذن `granted` من البداية، و`FakePushTransport` برمز ثابت.
3. لا تستبدل `deviceTokenRegistrarProvider`.
4. ادخل `employee.demo`.
5. افتح `/notifications`.
6. أرسل `AppLifecycleState.resumed`.

**المتوقع:** `POST /api/mobile-push/devices` مرة واحدة لذلك الرمز. الاستئناف لا يضيف طلبًا.

**الفعلي:** الدخول يرسل مرة. فتح الشاشة يرسل الرمز نفسه مرة ثانية، لأن ذاكرة المزامنة لم تُملأ من مسار الدخول. الاستئناف بعد ذلك لا يرسل ثالثة. الموافقة ثم الاستئناف أو إعادة بناء الشاشة تبقى على طلب واحد، فهذا المسار ليس استئنافًا بعد الموافقة. تغيّر الرمز ثم الاستئناف لا يرسل الرمز الجديد، لأن المقارنة على الاختيار لا على الرمز. إعادة تشغيل العملية ترسل عند الدخول مرة، وهذا غير مكتوب في التعليق؛ ثم فتح الشاشة يضيف المرة الثانية نفسها.

**على `main` `a5ca268`:** المسبار `already granted login then opening notifications` ما زال يتوقع `[token, token]` بعد فتح الشاشة، والاستئناف يبقى على 2، ونجح. `relaunch with the same token posts again` و`a token change on resume does not post the new token` ناجحان. الحكم يبقى **Open** على `main`، وغير مانع. لم يُفتح DEF-020.

**على [#50](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/50) `b7900a2c555aa3cccb3b562ed5f33b6f787fd527`:** المسبار المحلي عبر `buildAppRoot` (إذن ممنوح، API 33، `FakePushTransport` و`FakeApiClient` فقط فوق حزام الجذر) نجح ثم حُذف: الدخول يرسل مرة، وأول فتح لـ `/notifications` لا يعيد الرمز، وتغيير الرمز يرسل الرمز الجديد. اختبارات الطلب نفسها تبني `DeviceTokenRegistrar` مباشرة ولا تضخ الجذر. الحالة على `main` تبقى **Open**. لم يُدمج الطلب.

**اختبار #49 المعطّل، ملحق المراجعة.** في `621f01b` و`546a623` الاختبار `a granted login does not register again on the first notifications visit` يبقى `markTestSkipped` لأن `_skipDef019` صحيح، ويستخدم `pumpFakeApp` لا `buildAppRoot`. أُوقف العلم محليًا ثم أُعيد، بلا التزام وبلا دفع. على `621f01b` وحده خرج 1: الدخول يرسل مرة وأول `/notifications` يرسل `phase7-device-token` مرة ثانية. دمج محلي غير مُلتزم لـ `546a623` مع `b7900a2` خرج 0 ونتيجة `+1`: الفتح الأول لا يعيد الرمز. السطر `api_error code=REQUEST_FAILED` طُبع في التشغيلين ولم يغيّر الحكم. الدمج أُلغي. الحالة على `main` تبقى **Open**.

---

### DEF-020 — سداد جزئي أكبر من الرصيد يُقبل ويُخزَّن سالبًا

**الحالة:** Open on main `a5ca26809578dd013430dcaae78c517043e95491`. مانع. رصده [#51](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/51) عند `8aec37ee29107bb33541499f9e3be595f422919d` وأعاده مسبار محلي على `main`. التالي الحر DEF-023.

| الحقل | القيمة |
|---|---|
| المرحلة | 7 |
| الشدة | عالية |
| التصنيف | Blocking |
| الملفات | `lib/features/accounts/ledger_screen.dart` (`_MovementFormState._submit` يرسل العدد بعد `parseUnits` بلا مقارنة بالرصيد)؛ `lib/ui/widgets/common.dart` (`parseUnits` يقبل أي عدد صحيح)؛ `packages/api_layer/lib/data/fake/fake_api_client.dart` (`_applyMovement` يخزّن `previous - entered`) |

**خطوات الإعادة** على `main` `a5ca268`

1. ادخل `admin.demo` من نموذج الدخول.
2. افتح `/customers/c_55`. الرصيد 320 والإصدار 4.
3. افتح حوار السداد، أدخل 400، واحفظ.
4. اقرأ الكارت من المستودع.

**المتوقع:** رفض قبل الإرسال، والرصيد يبقى 320. حارس على العميل مطلوب ولو أعاد الخادم خطأً. العقد في المستودع يقول إن الخادم يحسب المبلغ النهائي (`AccountTransactionRequest`: «The server computes the final amount. The app shows no preview») وإن التطبيق لا يجمع ولا يطرح (قاعدة README 1). `docs/permission-enforcement-matrix.md` يذكر `requestId` و`expectedVersion` على `POST /api/{section}/{id}/transactions` ولا يذكر سقفًا. لا جملة في الوثائق ترفض `inputValue` الأكبر من الرصيد. الحارس ما زال مطلوبًا: المقارنة مع الرصيد المعروض ليست حساب رصيد جديد.

**الفعلي على `main`:** الحوار يرسل 400. الخادم التجريبي يقبل ويعيد `tx_new` ويخزّن الرصيد **−80** والإصدار 5. الرأس يعرض `-80 د.ل`. الطبقتان تسمحان. المسبار على `main`: الوحدة `DEF-020 fake stores 400 on a 320 balance as -80` والودجت `DEF-020 the payment dialog sends 400 and the header shows -80` ناجحان (4/4 مع DEF-021 وDEF-022).

**على [#53](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/53) `08e6b132c3d9bd450d463970da49ad3118fe8cba`:** لم يُدمج. الحالة على `main` تبقى **Open** وBlocking. الحوار يقارن العدد الصحيح بـ `balanceUnits` المخزَّن في `accountCardProvider` ولا يطرح رصيدًا. 400 على `c_55` يُمنع، ولا يُرسل POST، والرأس يبقى `320 د.ل`، والمخزَّن 320 والإصدار 4. الحد: 321 يُمنع بالرسالة `المبلغ أكبر من المتبقي المسجّل.` وبلا POST. 320 يُرسل ويصير الرصيد 0 والإصدار 5. `320.01` يرفضه `parseUnits` بجملة العدد الصحيح قبل المقارنة، وبلا POST. المقارنة تقرأ آخر قيمة في المزوّد ولا تنادي GET قبل الحفظ. بعد سداد خارجي بقيمة 200 (المخزَّن 120 والإصدار 5) والشاشة ما زالت على 320، إدخال 150 لا يُظهر رسالة السقف ويُرسل POST، والرأس يبقى 320. الخادم التجريبي يرفض الزائد بـ HTTP 400 و`VALIDATION_ERROR` قبل التخزين. هذا **مؤقت وليس عقدًا مؤكدًا**. السؤال المفتوح لمالك الخادم: هل يرفض الخادم الحقيقي السداد المباشر الأكبر من المتبقي، وبأي حالة ورمز وجملة؟ سداد القسمة أو الضرب لا يُقارن لأن المعامل ليس مبلغًا، ومقارنة ناتجه تحتاج حسابًا يمنعه العقد. السؤال الثاني: هل يجب رفض ناتج القسمة أو الضرب إذا تجاوز المتبقي؟ ذلك غير محسوم في المتطلب. التالي الحر DEF-026.

---

### DEF-021 — إرسال إسناد واستلام غير مربوط لا يظهران في النظرة التالية

**الحالة:** Open on main `a5ca26809578dd013430dcaae78c517043e95491` كعيب بديل اختبار، بلا أثر إنتاج. رصده #51 وأعاده المسبار على `main`. إصلاح الخادم التجريبي على #54 لم يُدمج. فحص staging للخادم الحقيقي ما زال مطلوبًا.

| الحقل | القيمة |
|---|---|
| المرحلة | 7 |
| الشدة | عالية على بديل الاختبار |
| التصنيف | test-double، بلا أثر إنتاج |
| الملفات | `packages/api_layer/lib/data/fake/fake_api_client.dart` (`_mutateCollections` يعيد `{id: ok, version: 1}` لمسار الإرسال وللاستلام غير المربوط ولا يضيف صفًا)؛ `lib/features/collections/collections_screen.dart` (`_AssignmentFormState._submit` وزر `save-unlinked` يبطلان `collectionsProvider` بعد النجاح) |

**خطوات الإعادة**

1. ادخل `employee.demo` من نموذج الدخول.
2. افتح `/collections`.
3. أرسل 40 على `as_1` من زر `submit-as_1` وحوار `save-assignment`.
4. أرسل استلامًا غير مربوط باسم `زبون جديد` ومبلغ 25 من `unlinked-collection` و`save-unlinked`.
5. اقرأ `collections.overview()`.

**المتوقع:** الصفان الجديدان في النظرة التالية، لأن الشاشة تعيد الجلب بعد النجاح.

**الفعلي على `main`:** المساران سُجّلا: `/api/collections/assignments/as_1/submissions` و`/api/collections/unlinked-receipts`. النظرة تبقى `sb_1` و`sb_2` و`ur_1` و`ur_2`. الإبطال على العميل حقيقي، والرد الثابت هو الذي يسقط الصف. ربط `ur_1` الموجود مسبقًا يخزّن `customerId` ويبقى خارج هذا العيب.

**إعادة التصنيف بعد [#54](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/54) `dc6c5c893f758b834cb23da33ee7e984d8ea58c4`:** لا فرق في `lib/`. `_AssignmentFormState._submit` و`_UnlinkedFormState._submit` يناديان `ref.invalidate(collectionsProvider)` بعد النجاح ثم يغلقان الحوار. الشاشة تراقب `collectionsProvider`، وهو `FutureProvider` ينادي `collections.overview()`. اختبار الودجت يفتح الحوارين الحقيقيين، وبعد الحفظ تظهر `submission-sb_posted_1` و`unlinked-card-ur_posted_1` على الشاشة نفسها، ثم بعد المغادرة والعودة. هذا عيب `FakeApiClient` فقط. #54 يخزّن الصف ويعيد معرّفه وإصداره 1. تكرار `requestId` يعيد النجاح المخزَّن عبر `_mutate` ولا يضيف صفًا ثانيًا. تعيين غير مرئي 404. القرار اللاحق يستخدم الإصدار المخزَّن. `cashStatus` لا يُكتب، وأرقام النظرة تبقى القيم الحرفية. الحالة على `main` تبقى **Open** حتى يُدمج الإصلاح. سلوك الخادم الحقيقي لم يُفحص ويبقى سؤال staging.

---

### DEF-022 — بعد 409 يبقى رأس الدفتر على 320 والمخزَّن 319

**الحالة:** Open on main `a5ca26809578dd013430dcaae78c517043e95491`. مانع لمسار حوار السداد. رصده #51 وأعاده المسبار على `main`.

| الحقل | القيمة |
|---|---|
| المرحلة | 7 |
| الشدة | عالية |
| التصنيف | Blocking |
| الملفات | `lib/features/accounts/ledger_screen.dart` (`_MovementFormState._submit` يلتقط الخطأ ويعيد `failureText`، و`GuardedMutation` الحوار بلا `onVersionConflict`)؛ `lib/ui/widgets/mutation_form.dart` (`_presentFailure` لا يعمل إلا إذا رُمي `VERSION_CONFLICT`)؛ `packages/api_layer/lib/data/fake/fake_api_client.dart` (`_requireVersion`) |

**خطوات الإعادة**

1. ادخل `admin.demo` وافتح `/customers/c_55` (320، الإصدار 4).
2. افتح حوار السداد وأدخل 100.
3. قبل الحفظ أرسل سدادًا جزئيًا بقيمة 1 وإصدار 4 عبر المستودع.
4. احفظ الحوار.
5. أغلق الحوار، اخرج إلى `/customers`، ثم أعد فتح `/customers/c_55`.

**المتوقع:** جملة التعارض الموحّدة `AppStrings.versionConflict`، وإبطال `accountCardProvider`، والرأس يتبع المخزَّن 319.

**الفعلي على `main`:** الحوار يعرض جملة الخادم `تم تعديل البيانات من مستخدم آخر` ولا يعرض `AppStrings.versionConflict`. الرأس يبقى `320 د.ل` بعد إغلاق الحوار وبعد مغادرة الشاشة والعودة. قراءة المستودع 319. أزرار اعتماد الاستلامات ترمي الاستثناء، فـ `GuardedMutation` هناك يعرض الجملة الموحّدة ويعيد الجلب. هذا المسار ليس عيب الحوار.

**على [#55](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/55) `fc140f910fd08d6fa215a70892bd44a86b55eb2c`:** لم يُدمج. الحالة على `main` تبقى **Open** وBlocking. `_submit` يعيد رمي `VERSION_CONFLICT` فقط. `GuardedMutation._presentFailure` ينادي `onVersionConflict` مرة واحدة، فيُبطل الكارت والدفتر وقائمة الحسابات والرئيسية، ويعرض `تم تعديل البيانات. أُعيد الجلب من الخادم.`. الرأس `ledger-header-balance` من `accountCardProvider` على المسار نفسه. اختبار الطلب يتوقع `319 د.ل` وغياب `320 د.ل` **قبل** إغلاق الحوار، ثم بعد المغادرة والعودة. المخزَّن 319 والإصدار 5، و100 الحوار لا يُخزَّن. الأخطاء الأخرى ما زالت تُعاد نصًا ويبقى الحوار. 409 ليس انتهاء جلسة، والاختبار يبقى على الدفتر. لا جلب ثانٍ من `_submit`. التالي الحر DEF-026.

---

### DEF-023 — علامة الدخول الذهبية على الخلفية الفاتحة 1.59:1

**الحالة:** Open on main `a5ca26809578dd013430dcaae78c517043e95491`. غير مانع. رصده [#49](https://github.com/ddaa81108-wq/vib-abdo-company-mobile/pull/49) عند `621f01b172f4dbbccc028bbe3a356d09d5339bf8` تحت اسم DEF-020، وهذا الاسم في السجل هو سداد أكبر من الرصيد. عند `621f01b` التخطي ما زال يكتب DEF-020. عند `546a62342eb78140d550abdfd138de5e0821c77a` اسم التخطي DEF-023، والاختبار ما زال `markTestSkipped` قبل القياس: تشغيل `--name DEF-02` أعطى `+0 ~3` وخروج 0، فهو ليس Pass. التالي الحر DEF-026.

| الحقل | القيمة |
|---|---|
| المرحلة | 7 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `lib/features/login/login_screen.dart` (`brandMark` و`brandWord` بلون `sidebarPalette.base`)؛ `lib/ui/theme.dart` (`AppSidebarPalette.gold.base` `#EAB600`، و`scaffoldBackgroundColor` الفاتح `#E5EDF6`) |

**خطوات الإعادة** على `main` `a5ca268`

1. افتح شاشة الدخول في الوضع الفاتح.
2. قس `#EAB600` على `#E5EDF6`.

**المتوقع:** نص عادي 4.5:1 على الأقل، ونص كبير أو مكوّن واجهة 3:1 على الأقل (WCAG AA).

**الفعلي:** `ع` (40 بكسل، وزن 800) و`VIB` (18 بكسل، وزن 800) مرسومان `#eab600` على `#e5edf6` بنسبة **1.59:1**. يفشل الحدين. إعادة الحساب من البايتات بصيغة WCAG 2.x: 1.588613، وتُقرَّب إلى 1.59:1. #49 يتخطى الاختبار قبل القياس ويبقي الزوج في قائمة معروفة. المسبار المحلي على رأس #49 طبع النسبة ثم حُذف. الطلب لا يغيّر `lib/`.

---

### DEF-024 — دور الشريط الجانبي في الوضع الفاتح 1.02:1

**الحالة:** Open on main `a5ca26809578dd013430dcaae78c517043e95491`. غير مانع. رصده #49 تحت اسم DEF-021، وهذا الاسم في السجل هو غياب صف الإرسال من النظرة. عند `621f01b` التخطي يكتب DEF-021. عند `546a623` الاسم DEF-024 وما زال تخطيًا، لا Pass.

| الحقل | القيمة |
|---|---|
| المرحلة | 7 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `lib/features/home/home_shell.dart` (`IdentityBlock` يرسم `roleLabel` بلا لون)؛ `lib/ui/theme.dart` (`onSurface` الفاتح `#172723`، و`sidebarBg` الفاتح `#102A26`) |

**خطوات الإعادة**

1. ادخل `admin.demo` في الوضع الفاتح على عرض يظهر الشريط.
2. اقرأ نص `مدير النظام`.

**المتوقع:** 4.5:1 على الأقل. النص حجم الجسم.

**الفعلي:** النص مرسوم `#172723` على `#102a26` بنسبة **1.02:1**. إعادة الحساب WCAG 2.x: 1.022427، وتُقرَّب إلى 1.02:1. الغلاف يضع `palette.shine` على سمة النص، والسطر بلا `style` يبقى على `onSurface`. #49 يتخطاه. المسبار طبع النسبة على الرئيسية والخزينة ثم حُذف.

---

### DEF-025 — النص الأساسي الداكن ومبلغ الخزينة تحت 3:1

**الحالة:** Open on main `a5ca26809578dd013430dcaae78c517043e95491`. غير مانع. رصده #49 تحت اسم DEF-022، وهذا الاسم في السجل هو بقاء رأس الدفتر بعد 409. عند `621f01b` التخطي يكتب DEF-022. عند `546a623` الاسم DEF-025 وما زال تخطيًا، لا Pass.

| الحقل | القيمة |
|---|---|
| المرحلة | 7 |
| الشدة | متوسطة |
| التصنيف | Non-blocking |
| الملفات | `lib/ui/theme.dart` (`primary` الداكن `#247763`، و`surface` `#172333`، ونغمة اليوم `#1A2C24`، و`cashPositive` `#087A50`)؛ `lib/features/treasury/treasury_screen.dart` |

**خطوات الإعادة**

1. بدّل إلى الوضع الداكن بعد الدخول.
2. افتح الرئيسية والخزينة والمشتريات.

**المتوقع:** 4.5:1 للنص العادي و3:1 للنص الكبير ومكوّن الواجهة.

**الفعلي:** أفعال الرئيسية (`إضافة عميل` و`حفظ` و`دخول`) `#247763` على `#172333` بنسبة **2.94:1** (WCAG 2.x: 2.939585). `تعديل` و`حذف` في المشتريات `#247763` على `#1a2c24` بنسبة **2.72:1** (2.723645). مبلغ الخزينة `1,000 د.ل` `#087a50` على `#172333` بنسبة **2.95:1** (2.951710). الثلاثة تحت 3:1 و4.5:1. وصف «حوالي 2.9» يطابق الأول والثالث ولا يطابق 2.72. #49 يجمعها في تخطي واحد. المسبار طبعها ثم حُذف.

---

## أسئلة مفتوحة لمدير المشروع على `main` `451ec58`

هذه ليست عيوبًا جديدة، ولا تُغلق من هذه الجولة:

- **صيغة المصراوية:** `workTotalUnits` و`remainingUnits` لا يُعاد حسابهما من القيم المحفوظة. بعد الحفظ يبقى `workTotal` 3050 و`remaining` 8950. لا صيغة معتمدة. ليس عيبًا.
- **صف الدين عند الصفر:** بعد السداد الكامل يبقى صف `c_55` ظاهرًا برصيد 0. هل يختفي الصف عند الصفر سؤال لمدير المشروع، وليس عيبًا.
- **بلاطات #27 الفارغة:** P4-003/DEF-012 ما زال Fail على `main` `8a52160` لأن #27 لم يُدمج. البلاطات الثلاث تعرض `employeesEmpty` و`auditEmpty` و`operationsEmpty`. بانتظار قرار علي. غير مانع.
- **DEF-002:** الحالة تبقى Pending PM decision على `main` `8a52160`. اختبار الاعتماد عند الإداري المحدود ناجح، والعيب لم يُغلق.
- **P3-01** يبقى Blocked. يحتاج staging حقيقيًا.

## سؤال مفتوح على PR #17 — بطاقة «الاستلامات المعتمدة اليوم»

على `c4edd59` البطاقة تأخذ `metrics.collectedUnits` وقيمته **0**، لا `cashOutstandingUnits` وقيمته **250**.

المواصفات صامتة عن عنوان هذه البطاقة. `GET /api/home` مقترح (🔶) في تحليل المشروع (القسم 5 والبند 8 من الأسئلة المفتوحة) وفي `home_models.dart`، والعنوان والقيمة يأتيان من الخادم كما هما. تحليل المشروع (القسم 2.3) يفصل اعتماد الاستلام عن تأكيد النقد، ولا يسمّي حقلًا لبطاقة الرئيسية. `collection_models.dart` يقول إن أشكال الرد أبعد من أسماء الحقول ما زالت 🔶، والتعليق على `collectedUnits` يذكر اسم الحقل فقط.

ما هو موثّق داخل المستودع:

| الحقل | التسمية في الواجهة | القيمة التجريبية |
|---|---|---|
| `collectedUnits` | «إجمالي المعتمد» (`strings.dart` وشاشة الاستلامات و`home_fallback.dart`) | 0 |
| `dayTotalUnits` | «إجمالي اليوم» | 100 |
| `cashOutstandingUnits` | «النقدية غير المسلّمة» | 250، ويطابق الاستلام المعتمد `sb_2` الذي نقده `pending` |

**توصية لمدير المشروع:** لا تُستبدل البطاقة بـ `cashOutstandingUnits` تحت العنوان الحالي، لأن ذلك الحقل معناه النقد غير المسلَّم. أقرب حقل موثّق لكلمة «المعتمد» هو `collectedUnits`. كلمة «اليوم» ليست معرّفة لهذا الحقل. إذا كان المقصود مجموع الاستلامات المعتمدة اليوم، فالقيمة 0 لا تطابق `sb_2` (250) ويحتاج العنوان أو الحقل قرارًا ثم تعديلًا للبيانات. البديل المتسق مع الشاشة الحالية: إبقاء `collectedUnits` وتسمية البطاقة «إجمالي المعتمد».

## سؤال مفتوح على PR #25 — مراجعة التصفير وكتابة القسم

على `e53a8b1` زر مراجعة التصفير للعملاء فقط، وعلى كارت غير نظامي. إذا أرسل الخادم `allowedActions` فالرمز `zero-review` هو القرار. إذا غاب الحقل، الزر يظهر عندما يجتمع الكود المقترح `debts.zero_review` مع كتابة القسم عبر `canOnRecord`، والرصيد 0 تمامًا، والمراجعة معلّقة.

المطوّر سجّل هذا الجمع كسلوك مقصود وسؤال مفتوح للخادم: دور يملك الكود المقترح فقط، بلا كتابة القسم، لا يرى الزر إلى أن يرسل الخادم `allowedActions`. هذا **سؤال مفتوح** وليس عيبًا، ولا يغيّر حكم مطابقة قائمة الكروت في #25.

## ما لم يُسجَّل عيبًا

- إشعارات الدفع `no-op` في `lib/notifications/app_push_service.dart` سلوك مصرَّح به إلى أن تُقبل المرحلة 6. مذكور في ملاحظة التغطية.
- P4-04 وP4-05 لم يُرفعا عيبًا: الأول بلا دفتر أيام متتالية على Fake، والثاني بلا ويب. كلاهما Blocked إلى staging.
- سؤال بطاقة «الاستلامات المعتمدة اليوم» وسؤال `debts.zero_review` بقيا سؤالين مفتوحين ولم يتحولا إلى عيب على `main`.
- خطة المرحلة 5 على `main` `451ec58` لم تفتح عيبًا جديدًا. التالي الحر يبقى DEF-017. ما ليس مبنيًا بعد (انتهاء جلسة حقيقي، مسار `account-requests`، تصفية مرتب بمعرّف) ليس عيبًا. DEF-012 وDEF-002 بقيا على حالهما. أسئلة الحقل `employeeTotals` وتحديث الدور أثناء الجلسة في `phase-5.md`.
- الجولة الثانية لم تفتح DEF-017. إغلاق حقول النموذج عند انتهاء الجلسة سلوك مقصود وسؤال مفتوح، لا عيب. `PendingMutation` يبقي `requestId` في الذاكرة لنفس المستخدم. الرجوع من الخلفية لا يكشف كوكيًا منتهيًا حتى الطلب التالي (P5-63). مفتاح `employeeTotals` في `GET /api/collections` يبقى سؤالًا لعلي، وصف الموظف وحده. جملة الرفض الخام تبقى داخل `ForbiddenException` بينما حالة #34 ونص #37 الموحّد لا يعرضانها. فشل اختبار المضيف البديل في #32 بعد إبقاء إغلاق #9 تفاعل دمج، لا عيب منتج.
- إعادة #39 عند `5defe43` لم تفتح عيبًا. الوثيقة طابقت `/forbidden` وصفوف Fake و`pendingMutationProvider` وطلب الخروج. 401 أو 419 من `GET /api/auth/csrf` يمر بلا خروج في كود #38 و#9. بقاء الشبكة ممكنًا عندما `CI=true` موثّق في الطلب، وليس عيبًا. معرّف أقصر من 8 أحرف لا يُفشل فحص التسريب، ومفتاح `employeeTotals` نفسه لم يُغلق.
- القبول النهائي على `main` `8a52160` لم يفتح DEF-017. فحص `_leaks` صار مساواة تامة لحقول المالك، و`--dry-run` يكتشف `u_20` ويبقي `u_200` والنص العابر نظيفين. إغلاق حقول النموذج وسؤال `employeeTotals` وP5-63 وP5-64 بقوا أسئلة. DEF-002 بقي Pending PM decision. DEF-012 بقي Fail. DEF-010 صار verified. staging لم يُشغَّل، وذلك ليس عيبًا.
- إعادة اختبار #41 عند `ae7311f` (ويحل محل `ad4f3d8`) لم تفتح DEF-017. الشاشة صارت على المتحكّم، والنداء المزدوج طلب واحد، وفشل مسار العدد (404 و500 و403 وشبكة ومهلة) يبقي القائمة ويأخذ الشارة من القائمة بلا خروج. 401 على المسار خروج واحد `session_expired`. `fromDto` يبقي `recipientUserId`، وحمولة الدفع تسقط المفاتيح الحساسة. سؤال `requestId` على السلك وP6-39 مفتوحان وليسا عيبين. التالي الحر يبقى DEF-017.
- الحكم المجمّع للمرحلة 6 على #40 `8149b55` و#41 `ae7311f` و#42 `52ab75f` و#43 `6fc4204` و#44 `8a6f287` لم يفتح DEF-017. مرشح `push` في workflow #42 مانع دمج. درزة النقر ودرزة الإذن وملصق الصينية الصامت طلبات متابعة، لا عيوب داخل رأس واحد. التالي الحر يبقى DEF-017.
- إعادة اختبار فرع الصينية `cursor/phase6-system-tray-bg-poll` عند `82e0e8c` فتحت DEF-017 أعلاه. التالي الحر صار DEF-018. DEF-002 يبقى Pending PM decision. DEF-012 يبقى Fail.
- إعادة اختبار الإصلاح على `cc1bc83` أغلقت DEF-017 على الفرع وليس على `main`. التالي الحر يبقى DEF-018.
- إعادة اختبار #46 عند `f6fa327` لم تفتح DEF-018. DEF-017 يبقى مغلقًا على الفرع. تعليم قراءة صف المستخدم الحالي عندما ترجع الفتاحة `forbidden` خيار لمدير المشروع: المسار `/forbidden` والنص «القسم غير مصرح لهذا الحساب» قائمان، والنقرة الثانية لا تنقص العدد. مستلم آخر لا يُعلَّم ولا يفتح المحتوى ولا يسرّب الاسم. DEF-002 يبقى Pending PM decision. DEF-012 يبقى Fail.
- إعادة اختبار #47 عند `3f8e009` فتحت DEF-018 أعلاه. التالي الحر DEF-019. DEF-017 لم يُعد فتحه. DEF-002 يبقى Pending PM decision. DEF-012 يبقى Fail.
- إعادة اختبار #47 عند `da9183c` أغلقت DEF-018 على الفرع وليس على `main`، وفتحت DEF-019 أعلاه. التالي الحر DEF-020. DEF-017 لم يُعد فتحه. إعادة إرسال نفس الرمز عند إعادة تشغيل العملية غير مكتوبة في التعليق، وليست عيبًا ثانيًا. P6-30 قرار لعلي والالتزام `da9183c` يُرجع وحده. DEF-002 يبقى Pending PM decision. DEF-012 يبقى Fail.
- جولة القبول النهائية على `main` `a5ca268` أغلقت DEF-017 وDEF-018 على `main`. DEF-019 بقي Open وغير مانع. لم يُفتح DEF-020 في تلك الجولة. DEF-010 بقي مغلقًا. DEF-002 يبقى Pending PM decision. DEF-012 يبقى Fail وخارج المرحلة 6. سقف الشارة `99+` فوق 99 سؤال مفتوح كما في الخطة، وليس عيبًا. تعليم القراءة عند `forbidden` لنفس المستخدم يبقى قرار علي.
- مراجعة #51 على `main` `a5ca268` فتحت DEF-020 وDEF-021 وDEF-022 أعلاه. التالي الحر DEF-023. DEF-002 يبقى Pending PM decision. DEF-012 يبقى Fail. DEF-019 يبقى مفتوحًا وغير مانع.
- مراجعة #49 عند `621f01b` أعادت تسمية تباين الوضع الداكن والفاتح إلى DEF-023 وDEF-024 وDEF-025 بالترتيب الذي ظهرت به في الطلب. #49 عند ذلك الرأس ما زال يكتب DEF-020 وDEF-021 وDEF-022. التالي الحر DEF-026. DEF-019 يبقى مفتوحًا على `main`. مسبار #50 لم يغلقه على `main`.
- ملحق #49: الرأس صار `546a623` وأسماء التخطي الثلاثة صارت DEF-023 وDEF-024 وDEF-025. التشغيل `+0 ~3` وخروج 0، فليست Pass. إعادة حساب WCAG 2.x: 1.588613 و1.022427 و2.939585 و2.723645 و2.951710. اختبار DEF-019 المعطّل يفشل على `621f01b` وحده (إرسالان) وينجح `+1` على دمج محلي غير مُلتزم مع #50. DEF-019 وDEF-023 وDEF-024 وDEF-025 تبقى Open على `main`. التالي الحر DEF-026.
- مراجعة #53 و#54 و#55 لم تغلق DEF-020 ولا DEF-022 على `main`. DEF-021 صار عيب بديل اختبار بلا أثر إنتاج، وما زال مفتوحًا على `main` حتى دمج #54، وفحص الخادم الحقيقي staging. رد الخادم التجريبي 400 `VALIDATION_ERROR` للسداد الزائد مؤقت وليس عقدًا. السؤال المفتوح: سقف السداد المباشر، وسقف ناتج القسمة أو الضرب. التالي الحر DEF-026.
