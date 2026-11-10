# سجل الإصلاحات

الأرقام ثابتة. لا يُعاد استخدام رقم أُلغي. التراجع يكون بالتزام `git revert` جديد، لا بمسح التاريخ ولا بإعادة القاعدة.

الفرع المحلي: `cursor/client-hygiene-008-011-5c94`.
رأس السجل عند كتابته: انظر آخر التزام `VIB-FIX-REG` في `git log`. أرقام 001–007 وهاشاتها لم تتغير.

## VIB-FIX-001

- الالتزام: `c57d48d6a48e5aa5326b9e100e1909fc4d9ce8bf`
- العنوان: Load older purchase rows with the server before cursor.
- العرض: دفتر المشتريات يقف عند أول صفحة (`limit` 100) ولا يرسل `before`.
- السبب: العقد `GET /api/purchases/{merchant}` ينشر `before` و`nextBefore` الرقمي.
- السلوك: «تحميل الأقدم» يرسل المؤشر، ويلحق الصفوف بلا تكرار، ويسقط الرد إذا تغيّر التاجر، ويبقي الخطأ للإعادة. `registerTotals` تبقى من الصفحة الأولى ولا تُجمع.
- الدليل: `test/purchases_pagination_test.dart`
- يعتمد على: لا شيء من هذا السجل. هو أول بند، فوق `4828902`.
- التراجع: `git revert c57d48d6a48e5aa5326b9e100e1909fc4d9ce8bf`. إن وُجدت 002 أو 003 فوقه، ارجع الأحدث أولًا لأن الثلاثة تلمس `fake_api_client.dart`. afterward: `flutter test test/purchases_pagination_test.dart --dart-define=USE_FAKE_API=true` ثم المجموعة الوهمية.

## VIB-FIX-002

- الالتزام: `e76173c6b066f306529393cc5c408e4f76ca829a`
- العنوان: VIB-FIX-002 Keep the current ledger page when the older page fails.
- العرض: طلب الصفحة الأقدم في سجل الأستاذ كان يبدّل مفتاح التحميل فورًا. الفشل أخفى الصفوف وإجماليات الصفحة.
- السبب: `pageTotals` إجمالي الصفحة المعروضة فقط. إخفاؤها عند فشل الشبكة يترك الشاشة بلا آخر رد صالح.
- السلوك: الصفحة الحالية تبقى مع إجمالياتها. النجاح يستبدلها برد تلك الصفحة كما أرسلها الخادم، بلا جمع. تغيير التصفية يسقط الرد المتأخر. طلب واحد في الطيران.
- الدليل: `test/financial_ledger_page_test.dart`
- يعتمد على: لا يعتمد سلوكه على 001. ملف الخادم الوهمي مشترك، فالتراجع الآمن بعد 003 هو عكس الترتيب.
- التراجع: `git revert e76173c6b066f306529393cc5c408e4f76ca829a` بعد التراجع عن 003 إن كانت موجودة. afterward: `flutter test test/financial_ledger_page_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-003

- الالتزام: `50e87755b44669def3e63cee90edc0614790309e`
- العنوان: VIB-FIX-003 Keep audit rows when an older page fails and do not repeat them.
- العرض: فشل الصفحة الأقدم في سجل التدقيق لم يُظهر الخطأ. صف متكرر في الرد كان يُضاف مرة أخرى.
- السبب: الشاشة كانت تفرغ بيان الخطأ ما دامت الصفوف موجودة، وتلحق عناصر الصفحة بلا فحص المعرّف.
- السلوك: الصفوف المحمّلة تبقى، والخطأ ظاهر، والإعادة لا تضاعف معرّفًا موجودًا، وطلب ثانٍ لا يدخل أثناء الطيران.
- الدليل: `test/audit_older_page_test.dart` مع بقاء اختبار المؤشر في `test/settings_directory_test.dart`.
- يعتمد على: لا يعتمد على 001 أو 002 في السلوك. التراجع يلمس `fake_api_client.dart` فوق تعديلاتهما.
- التراجع: `git revert 50e87755b44669def3e63cee90edc0614790309e` أولًا إن أريد الإبقاء على 001 و002. afterward: `flutter test test/audit_older_page_test.dart test/settings_directory_test.dart --dart-define=USE_FAKE_API=true --name audit`.

## VIB-FIX-004

- الالتزام: `3b6eca98c7ad6344a06d79da3cfc51519bee021b`
- العنوان: VIB-FIX-004 Show an account-list page failure without dropping the cards.
- العرض: فشل `cursor` في قائمة البطاقات كان استثناءً غير ممسوك. لا رسالة، والاختبار يرى خطأ منطقة.
- السبب: الزر «تحميل المزيد» يستدعي الصفحة التالية دون `catch`. البطاقات السابقة لا تُفسد، لكن الفشل لا يُعرض ولا يُعاد بشكل واضح.
- السلوك: الخطأ يظهر تحت القائمة، والبطاقات المحمّلة تبقى، والزر يعيد نفس المؤشر. دون اتصال لا يُرسل الطلب. تغيير البحث ما زال يسقط الصفحة المتأخرة كما في الاختبار السابق.
- الدليل: `test/account_list_paging_test.dart`
- يعتمد على: لا يعتمد سلوكه على 001–003. الملف `fake_api_client.dart` مشترك، فالتراجع الآمن هو من الأحدث: 004 ثم 003 ثم 002 ثم 001.
- التراجع: `git revert 3b6eca98c7ad6344a06d79da3cfc51519bee021b`. afterward: `flutter test test/account_list_paging_test.dart test/account_list_actions_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-005

- الالتزام: `46d50547e97ccf42e27039c54c63560967d8fccd`
- العنوان: VIB-FIX-005 Drop a search reply that is no longer the current query.
- العرض: بحث أبطأ كان يكتب أسماءه فوق نتائج بحث أحدث. النص في الخانة لا يطابق الصفوف.
- السبب: `/search` يدور على أربعة أقسام بلا رقم طلب. الرد المتأخر يغيّر الخريطة بعد أن بدأ بحث جديد، أو بعد خروج المستخدم.
- السلوك: يُقبل الرد فقط إذا بقي نفس رقم الطلب ونص البحث ومعرّف الجلسة. طلب أحدث لا يُطفأ مؤشره بسبب انتهاء الطلب الأقدم.
- الدليل: `test/search_lifecycle_test.dart`. اختبار التحميل والخطأ في `test/section_errors_test.dart` ما زال ناجحًا.
- يعتمد على: لا يعتمد على 001–004. لا يلمس `fake_api_client.dart`. تراجعه لا يتعارض مع تلك الملفات.
- التراجع: `git revert 46d50547e97ccf42e27039c54c63560967d8fccd`. afterward: `flutter test test/search_lifecycle_test.dart test/section_errors_test.dart --dart-define=USE_FAKE_API=true --name search`.

## VIB-FIX-006

- الالتزام: `4fd231c713f8c7c1971e24f9bd6f2c6b55870491`
- العنوان: VIB-FIX-006: Section grants are denied or full, with no read-only choice.
- العرض: نموذج صلاحيات حساب الدخول كان يعرض ثلاثة اختيارات للقسم: لا شيء، قراءة، إدارة. اختيار القراءة كان يُحفظ كوصول محدود.
- السبب: العمل على القسم يعني صلاحية كاملة لذلك القسم. العقد ما زال يقبل القيمة `read` للسجلات القديمة، لكن النموذج لا يعرضها كاختيار.
- السلوك: الاختياران فقط «ممنوع» و«دخول كامل». الدخول الكامل يرسل `manage` مع رموز القراءة والكتابة المنشورة لذلك القسم (`debts` و`companies` والأمانات والمصراوية والمشتريات دون `purchases.finalize` والخزينة؛ التقارير `reports.read` فقط). المنع يرسل `none` ويزيل رموز ذلك القسم. سجل `read` يظهر تنبيهًا غير قابل للاختيار ويبقى `read` بلا رموز كتابة إلى أن يختار المدير الدخول الكامل أو المنع ويحفظ. لا ترحيل صامت لحسابات قائمة ولا لجلسة الدخول ولا لعلم `fullAccess` ولا لإنشاء الحسابات. إنشاء الحسابات يبقى للمدير الذي `isOwner` عنده `true`.
- الدليل: `test/section_grant_test.dart` و`test/settings_directory_test.dart`.
- يعتمد على: لا يغيّر سلوك 001–005. يضيف `extraLoginUsers` في `fake_api_client.dart`، فالتراجع الآمن إن لزم عكس 006 قبل العودة إلى 004 وما قبلها على ذلك الملف.
- التراجع: `git revert 4fd231c713f8c7c1971e24f9bd6f2c6b55870491`. afterward: `flutter test test/section_grant_test.dart test/settings_directory_test.dart --dart-define=USE_FAKE_API=true --exclude-tags screenshots`.

## VIB-FIX-007

- الالتزام: `2b6adbdad218594abab187c4624c7b35f43660f5`
- العنوان: VIB-FIX-007: Review a pending zero card in all four account sections.
- العرض: علامة مراجعة الصفر كانت للعملاء فقط. الشركات والأمانات لم تعرض العلامة حتى بعد نشر العقد على مصدر الخادم غير المنشور.
- السبب: العقد `VIB-SRV-ZERO-001` عند `0bf3de701e5a6b3d718d9d15fd1c3f2b8bd7ae1a` يعيد `zeroReview` للأقسام الأربعة ويفتح `POST /api/{section}/{id}/zero-review`. نص العقد مطابق لـ `fd7126507fcc2b36fdfd2c4d07bbe9870dd0b6da`. التنفيذ عند `d8d4d01375032932748df3a65e2755dec5872544` لم يتغير. الخادم نُشر على الإنتاج `https://vip2100.com`: التزام مستودع الموقع `64f33ffb3c61db38c78cbe520d90f79a6a3ba7f2`، schema 57، في 2026-11-09.
- السلوك: العلامة تظهر عندما يكون الرصيد صفرًا و`zeroReview.pending` صحيحًا والحساب غير مرتبط بنظام، وللمدير في العملاء، أو للمدير أو رمز الكتابة في الشركات والأمانات. `fullAccess` لا يغني عن ذلك. غياب الحقل لا يعرض علامة ولا يرسل طلبًا. الصفر التاريخي (`pending: false` و`reviewedAt: null`) بلا علامة وينزل مع الأصفار المراجعة. المعاينة لا تكتب. الإلغاء لا يرسل. التأكيد يرسل `{expectedFinancialVersion}` إلى مسار القسم. النجاح يأخذ `zeroReview` من الرد ثم يعيد قراءة القائمة. فشل التحديث يبقي رد المراجعة ظاهرًا مع خطأ القائمة. `409` لا يعتمد الكارت. تكرار النسخة `replayed: true` لا يضاعف الكتابة. خروج الجلسة أثناء الطلب لا يثبت الرد على المستخدم التالي. الرصيد وإصدار الكارت لا يتغيران. نموذج 006 وإنشاء الحسابات للمدير الأساسي بقيا.
- الدليل: `test/section_zero_review_test.dart` و`packages/api_layer/test/section_zero_review_contract_test.dart` و`test/zero_card_confirm_test.dart`. هذه اختبارات الخادم الوهمي المطابق للعقد، وليست اتصالًا بخادم Node.
- يعتمد على: يضم 006 في تاريخ الفرع. يلمس `fake_api_client.dart` فوق 006 و001–004، فالتراجع الآمن هو 007 ثم 006 ثم الأقدم.
- التراجع: `git revert 2b6adbdad218594abab187c4624c7b35f43660f5`. afterward: `flutter test test/section_zero_review_test.dart test/zero_card_confirm_test.dart packages/api_layer/test/section_zero_review_contract_test.dart --dart-define=USE_FAKE_API=true --exclude-tags screenshots`.

## VIB-FIX-008

- الالتزام: `c02b56b4d188dea195d5c3e995c0cc47edba875f`
- العنوان: VIB-FIX-008: Format the app and api_layer with dart format.
- العرض: `dart format` على Dart 3.13.5 بعد حل الحزم كان يغيّر 21 ملفًا من 278 في `lib` و`test`، و37 ملفًا من 125 في `packages/api_layer`.
- السبب: تلك الملفات لم تكن على تنسيق المترجم المثبت. لا ملفات مولَّدة في المسارين، ولا قاعدة في المستودع تستثنيها. بلا `flutter pub get` تُقرأ حزمة `api_layer` كأحدث لغة لأن قيدها `>=3.3.0`، فيتغيّر عدد أكبر؛ التنسيق المعتمد هو الذي بعد حل الحزم.
- السلوك: تنسيق فقط. النصوص والتعليقات كما هي. بعد حذف المسافات والفواصل لا يبقى فرق في الرموز. لا عقد ولا شبكة ولا قاعدة بيانات ولا موقع.
- الدليل: 58 ملفًا في الالتزام. `dart format --output=none --set-exit-if-changed lib test packages/api_layer/lib packages/api_layer/test` يخرج 0 بعده.
- يعتمد على: لا يغيّر سلوك 001–007. يعيد تنسيق `fake_fixtures.dart` فوق 007، فإزالة 008 مع الإبقاء على 007 هي `git revert` لهذا الالتزام وحده.
- التراجع: `git revert c02b56b4d188dea195d5c3e995c0cc47edba875f`. afterward: `dart format --output=none --set-exit-if-changed lib test packages/api_layer/lib packages/api_layer/test`.

## VIB-FIX-009

- الالتزام: `8c315941c5bc69df908edcb97debe3a082c56f5a`
- العنوان: VIB-FIX-009: Remove two unused client files.
- العرض: `lib/features/settings/admin_placeholder_screen.dart` و`packages/api_layer/lib/core/security/screen_security.dart` لا يستوردهما أحد.
- السبب: لا استيراد ولا تصدير من `api_layer.dart` ولا مسار ولا اختبار ولا انعكاس. مسارات الإعدادات تعرض `LoginAccountsScreen` و`SecurityScreen` و`DevelopmentScreen`. قناة `app/screen_security` في `AndroidCaptureGate` و`MainActivity.kt` مسار التقاط حي، وليست ملف الحزمة.
- السلوك: حُذف الملفان فقط. القناة وملفات Kotlin وسلوك الالتقاط بقيت. ذكر الاسم في سجلات القبول القديمة بقي لأنه لا يستورد الملفين.
- الدليل: بحث المستودع عن الاسمين في Dart وKotlin. لا اختبار يعتمد عليهما.
- يعتمد على: لا يعتمد على 001–008. 008 لم يُعد تنسيق هذين الملفين.
- التراجع: `git revert 8c315941c5bc69df908edcb97debe3a082c56f5a`. afterward: `flutter analyze` ثم `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-010

- الالتزام: `7fea4b93452ed61caf262b2f7af2098fa574696a`
- العنوان: VIB-FIX-010: Record that the four-section server is deployed.
- العرض: بند 007 كان ينتهي بـ «الخادم لم يُنشر»، وفقرة ما لم يُرقم كانت تقول «لم يُنشر بعد».
- السبب: خادم مراجعة الأقسام الأربعة صار على الإنتاج `https://vip2100.com` في 2026-11-09. التزام مستودع الموقع `64f33ffb3c61db38c78cbe520d90f79a6a3ba7f2`، schema 57.
- السلوك: نص السجل فقط. بقية بند 007 كما هي، ومنها جملة العرض عن مصدر الخادم وقت العيب. عناوين 001–007 بقيت مطابقة لالتزاماتها. لا كود ولا عقد ولا شبكة من هذا المستودع.
- الدليل: سطران في `docs/repair-register.md`.
- يعتمد على: يوثّق 007 ولا يغيّر سلوكه. تراجعه يلمس السجل، فيُعكس بعد التزامات `VIB-FIX-REG` التي تليه إن وُجدت.
- التراجع: `git revert 7fea4b93452ed61caf262b2f7af2098fa574696a`. afterward: مراجعة نص 007 فقط. لا اختبار.

## VIB-FIX-011

- الالتزام: `723090010326a0428b0bb964d2cde430943c91d8`
- العنوان: VIB-FIX-011: Check dart format in CI without changing other jobs.
- العرض: فحص CI لم يكن يفشل إذا انحرف تنسيق `lib` أو `test` أو `packages/api_layer`.
- السبب: 008 يحتاج حارسًا على نفس المسارات ونفس Flutter 3.47.7. `dart format` يختار الأسلوب من إصدار لغة الحزمة بعد `flutter pub get`.
- السلوك: وظيفة جديدة `format` في `.github/workflows/ci.yml`، وصفها في `docs/TESTING.md`. الأمر `dart format --output=none --set-exit-if-changed`. بلا أسرار ولا نشر ولا توقيع ولا بناء. نص الوظائف الثلاث السابقة لم يتغير.
- الدليل: الوظيفة `Format check`. التشغيل على طلب السحب.
- يعتمد على: يغطي ناتج 008 بعد حذف 009. لا يغيّر سلوك 001–010.
- التراجع: `git revert 723090010326a0428b0bb964d2cde430943c91d8`. afterward: الوظائف الثلاث السابقة تبقى، ويفقد الفحص الجديد.

## ما لم يُرقم لأنه ليس إصلاح عميل

تكرار تقديم التحصيل بعد ضياع الرد، وربط الأمانة المصرية، وتفعيل MFA، وقائمة الجلسات، وإغلاق المصراوية عند 04:00، وقفل الالتقاط. خادم مراجعة الأقسام الأربعة منشور على الإنتاج `https://vip2100.com` منذ 2026-11-09 (مستودع الموقع `64f33ffb3c61db38c78cbe520d90f79a6a3ba7f2`، schema 57).

## فحص المجموعة بعد 011

`flutter analyze` بلا ملاحظات للتطبيق و`packages/api_layer`، قبل 008 وبعد 011. `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 810 نجحت، 8 تُركت، 0 فشلت، قبل التنسيق وبعده. حزمة `packages/api_layer` بأمر `flutter test --dart-define=USE_FAKE_API=true`: 545 نجحت، 14 تُركت، 0 فشلت، قبل التنسيق وبعده. الثمانية لقطات موقوفة في التطبيق. لم يُعد اختبار أندرويد لأن ملفات Kotlin وقناة `app/screen_security` لم تتغير. 10 نوفمبر 2026. خادم وهمي فقط، لا اتصال حي.

سلوك 006 و007 يبقى كما هو. هذه الجولة تنسيق وحذف ملفين غير مستخدمين وتوثيق نشر الخادم وفحص تنسيق للقراءة فقط.
