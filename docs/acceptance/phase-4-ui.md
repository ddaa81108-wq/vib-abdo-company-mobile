# قبول واجهة المرحلة 4

هذا سجل الحكم على معايير `phase-4-ui.md` من PR #14. لقطات ذلك الطلب لم تُنسخ إلى هذا الفرع، ولم تُستخدم كمرجع بكسل.

المعايير الأربعة على `main` عند `dff1456` مسجّلة في `phase-4.md`: P4-001 وP4-002 وP4-004 ناجحة. P4-003 فاشل وغير مانع ويبقى DEF-012.

## P4-003 / DEF-012 على PR #27

- **الالتزام:** `5d9700f218efecf1447500c926137e30b3e40930`
- **الفرع:** فوق `main` (`dff1456`). ليس على `main` بعد.
- **الحكم:** Fail. ليس verified.

المعيار من PR #14: شاشة إدارية ببيانات من الخادم، أو إخفاء البلاطة إن لم تُعتمد. إجماليات الصفحة بوحدة عربية واحدة، بلا مفتاح `LYD` أو `EGP`.

ما طُلب في إعادة الاختبار: البلاطات تعرض بيانات Fake بلا نص بديل وبلا مفاتيح لاتينية، في الفاتح والداكن، للمدير الكامل والإداري المحدود. من لا يملك الوصول لا يراها.

| الدور والسمة | الدليل | الحكم |
|---|---|---|
| مدير كامل، فاتح وداكن | `the financial ledger tile shows the server totals`: «0 د.ل» و«0 ج.م»، و`find.textContaining('LYD'/'EGP')` لا يجد نصًا | نصف سجل الأستاذ ناجح |
| مدير كامل، الشاشات الثلاث | `employees, audit, and operations use an empty pane`: `EmptyPane` مع `employeesEmpty` و`auditEmpty` و`operationsEmpty` في السمتين | Fail. نص بديل، ولا بيانات Fake |
| إداري محدود | الملف لا يمنح `settings.manage`. `admin tiles stay hidden without settings.manage` و`limited admin has no settings entry`: الشاشة والبلاطات غائبة | لا بيانات. الإخفاء يطابق «من بلا وصول»، ولا يحقّق عرض البيانات لهذا الدور |
| موظف، ضيف، `flag.admin` | `an employee does not see settings or admin routes` و`guest and flag admin see no sections and no settings` | Pass لمن بلا وصول |

`admin_destinations.dart` يصرّح أن Fake لا يعيد موظفين ولا تدقيقًا ولا حالة تشغيل، وأن الإبقاء على البلاطات لم يقرره علي. لذلك P4-003 وDEF-012 يبقيان مفتوحين.

## انحدار على #27

`tool/check.sh` خرج 0: تحليل التطبيق بلا مشكلات (5.0s) و**250/0**، وتحليل `packages/api_layer` بلا مشكلات (0.8s) و**74/0**. اختبار القبول `test/acceptance/phase_1_3_fake_test.dart` نجح **4/4** على هذه الشجرة ثم حُذف من شجرة الفحص (الملف ليس جزءًا من #27).

| البند | الحكم | الدليل داخل المجموعة الناجحة |
|---|---|---|
| DEF-001 | Pass | تحليل التطبيق والحزمة بلا مشكلات |
| DEF-003 | Pass | `DEF-003 full payment stores balance 0` |
| DEF-004 | Pass | `DEF-004 cancel copies the stored balance of the latest posted line` |
| DEF-005 | Pass | `DEF-005 a second decision with the same version is a conflict` |
| DEF-006 | Pass | `DEF-006 the fake server enforces the permission matrix with 403` |
| P4-001 | Pass | `P4-001 debt and payment amounts use the status colours` |
| P4-002 | Pass | `P4-002 the ledger header paints the ageStatus gradient` |
| P4-004 | Pass | `customer and company cards show the server age once` |
| P4-02 | Pass | `a reader sees the ledger and no write actions` و`opening and correction stay hidden without their permissions` |
| P4-03 | Pass | `custom purchase item requires a free-text label` |
| P4-06 | Pass | `empty reports and a missing treasury rate stay neutral` |
| المراحل 1–3 | Pass | `phase_1_3_fake_test.dart` أربعة اختبارات |

لا عيب جديد من هذه الإعادة.
