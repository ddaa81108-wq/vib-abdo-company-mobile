# سجل الإصلاحات

الأرقام ثابتة. لا يُعاد استخدام رقم أُلغي. التراجع يكون بالتزام `git revert` جديد، لا بمسح التاريخ ولا بإعادة القاعدة.

الفرع المحلي: `cursor/live-refresh-notify-5c94`.
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

## VIB-FIX-012

- الالتزام: `b3777102eb2379785853ae41d2d6275434907a84`
- العنوان: VIB-FIX-012: Refetch sections when the website changes them.
- العرض: بيان يُضاف من الموقع لا يظهر في التطبيق حتى يكتب المستخدم في القسم نفسه. الاتجاه العكسي يظهر في الموقع فورًا.
- السبب: التطبيق أصلًا يستمع إلى `GET /api/events` و`GET /api/event-changes`، لكن الإشارة كانت تُسقط التحصيل والأستاذ والرئيسية فقط. قوائم العملاء والشركات والأمانات والمشتريات والمصراوية والخزينة تبقى في الذاكرة لأنها ليست `autoDispose`. الموقع يعيد قراءة كل قسم حسب موضوعه (`customer.changed` وما يقابله، بما فيه `treasury.report.closed` و`financial.summary.changed`).
- السلوك: كل موضوع يُسقط قراءة قسمه. `full_resync_required` والعودة من الخلفية يُسقطان الأقسام كلها. فتح مسار فيه رد مخزن يعيد قراءته. السحب للتحديث على المشتريات والمصراوية والتحصيل وسجل الأستاذ. لا استطلاع ضيق جديد، والتوقف في الخلفية كما كان. الإجماليات تبقى من الخادم.
- الدليل: `test/live_refresh_test.dart`.
- يعتمد على: لا يغيّر عقد 001–011. يلمس التنسيق فوق 008 في بضع شاشات.
- التراجع: `git revert b3777102eb2379785853ae41d2d6275434907a84`. afterward: `flutter test test/live_refresh_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-013

- الالتزام: `f11bbabd5d1fb32a6d441b8a447e149dfe1b4e2b` ثم `dde8ebfc42af33da585aca0207acbfe2afa540f2` لإبقاء `onDestroy` واحدًا حتى يبني الإصدار.
- العنوان: VIB-FIX-013: Speak new notifications when النطق is on.
- العرض: الإشعارات «غير منطوقة». المفتاح في الحساب اسمه «النطق» ويحفظ `speechEnabled`. النص الظاهر كان مفتاح الإجراء مثل `collection.submit` لأن الخادم لا يرسل `title` ولا `body`.
- السبب: الموقع عند `speechEnabled` ينطق `notificationSentence`، وعند `soundEnabled` يطلق نغمة قصيرة داخل الصفحة. قناة أندرويد `vib_collections_alerts` أصلًا `IMPORTANCE_HIGH` فشريط النظام له صوت. الشريط الداخلي كان صامتًا، والتطبيق لم يكن ينطق. الدليل يرجّح معنى النطق لا نصًا مشوّهًا وحده، والنص الخام أُصلح معه لأنه مصدر الجملة المنطوقة.
- السلوك: جملة عربية من `actorName` و`action` و`details` كما في الموقع. إذا `speechEnabled` تُنطق بالعربية على الجهاز عبر `app/notification_speech`. إذا `soundEnabled` (الافتراض في الخادم) تُطلق نغمة. الخلفية توقف النطق. لا مسار جديد.
- الدليل: `test/notification_sentence_test.dart`.
- يعتمد على: لا يغيّر 012. القراءة من الحقول الموجودة في `GET /api/notifications`.
- التراجع: `git revert dde8ebfc42af33da585aca0207acbfe2afa540f2` ثم `git revert f11bbabd5d1fb32a6d441b8a447e149dfe1b4e2b`. afterward: `flutter test test/notification_sentence_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-014

- الالتزام: `4108e09819282b614493e09504d6b4ad90377893` ثم `4fc1e00f707c67ea78964199d0b0d3df123362ca` لاختبار الشريط وقناة النطق الغائبة.
- العنوان: VIB-FIX-014: Open the section named on a notification for the owner.
- العرض: النقر على أي إشعار يفتح «القسم غير مصرح لهذا الحساب» والمدير الأساسي داخل الحساب.
- السبب: صف `GET /api/notifications` يرسل `sectionKey` و`entityId` ولا يرسل `recipientUserId`. التطبيق كان يقرأ `section` و`relatedRef` فقط، ورفض نقرة الشريط واللافتة إذا غاب المستلم قبل أن يفحص القسم. المدير الأساسي (`isOwner` مع دور `admin`) لم يُعامل كدخول كامل إذا وُجدت قائمة صلاحيات جزئية، بينما الموقع يفتح له كل الأقسام.
- السلوك: `sectionKey` يفتح القسم، ومع المعرّف يفتح الكارت. غياب المستلم يعني أن الصف لحساب الجلسة. مستلم آخر ما زال يُرفض. `isOwner` مع دور `admin` دخول كامل للأقسام. إنشاء الحسابات يبقى للمدير الأساسي. موظف بلا صلاحية القسم ما زال يُمنع.
- الدليل: `test/notification_opener_test.dart` و`packages/api_layer/test/permission_service_test.dart`.
- يعتمد على: يكمّل 013 في نموذج الإشعار. لا يوسّع صلاحيات الموظف.
- التراجع: `git revert 4fc1e00f707c67ea78964199d0b0d3df123362ca` ثم `git revert 4108e09819282b614493e09504d6b4ad90377893`. afterward: `flutter test test/notification_opener_test.dart test/system_tray_navigation_test.dart packages/api_layer/test/permission_service_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-015

- الالتزام: `cd32d2d00bd949e151745f1aa344fffae74a445b`
- العنوان: VIB-FIX-015: Play a sound for notifications on a new channel.
- العرض: «غير منطوقة» تعني بلا صوت. القناة `vib_collections_alerts` إن أُنشئت بلا صوت لا تقبل تغيير الأهمية لاحقًا.
- السبب: الموقع عند `soundEnabled` يطلق نغمة 760 هرتز لـ 200 مللي ثانية عند إشعار جديد، ولا يطلقها عند التحميل الأول. شريط أندرويد يحتاج قناة جديدة بأهمية عالية وصوت الإشعار الافتراضي.
- السلوك: القناة `vib_notices_sound_v1`، وأهمية عالية، وصوت `TYPE_NOTIFICATION`، واهتزاز. النغمة داخل التطبيق بنفس التردد والمدة عندما `soundEnabled` ليس `false`. `speechEnabled` يبقى للنطق كما في 013. إيقاف الصوت من الحساب يبقى كما هو.
- الدليل: `test/notifications/notification_channels_test.dart`.
- يعتمد على: فوق 013. لا مسار جديد.
- التراجع: `git revert cd32d2d00bd949e151745f1aa344fffae74a445b`. afterward: `flutter test test/notifications/notification_channels_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-016

- الالتزام: `33b1c4238feaf09c14cef69b230b59fd885dd9d2` ثم `80620f65499024580f52ce5ec5edf0a484ebd915` لإبقاء القائمة الطويلة كسولة مع وصول آخر كارت.
- العنوان: VIB-FIX-016: Scroll the last account card fully above the bottom bar.
- العرض: آخر كروت الديون والأمانات لا تظهر كاملة حتى أسفل الصفحة.
- السبب: القائمة الطويلة كانت داخل صندوق بارتفاع 560، فيُقص أسفلها تحت الشريط. التمرير الداخلي لا يُظهر الجزء الواقع خارج الشاشة.
- السلوك: تمرير واحد للصفحة حتى آخر كارت، مع فراغ أسفل 32. علامة مراجعة الصفر وارتفاع كرت الديون بقيا. الأقسام الأربعة: العملاء والشركات والأمانات الليبية والمصرية.
- الدليل: `test/account_list_overflow_test.dart` باسم `the last card scrolls fully above the bottom bar` على 320×568 ومقياس نص 2.
- يعتمد على: لا يغيّر 012–015. لا يغيّر بيانات الكارت.
- التراجع: `git revert 80620f65499024580f52ce5ec5edf0a484ebd915` ثم `git revert 33b1c4238feaf09c14cef69b230b59fd885dd9d2`. afterward: `flutter test test/account_list_overflow_test.dart --name "last card" test/p7_long_history_test.dart test/def027_history_window_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-017

- الالتزام: `cc9fb2054f6780400888fc01f233cabf612e1e4e`
- العنوان: VIB-FIX-017: Match the four account ledgers to the website totals.
- العرض: إجمالي السجل في الأقسام الأربعة لم يطابق لون الموقع وعباراته.
- السبب: الموقع يرسم إجمالي العملاء والشركات والأمانات الليبية ذهبًا، والمصرية أخضر للموجب وأحمر للسالب.
- السلوك: نفس الكلمات حسب إشارة الرصيد، والمبلغ بالقيمة المطلقة في الأمانات. أعمدة السجل وأزرار التعديل والإلغاء بقيت.
- الدليل: `test/deposit_website_tone_test.dart` و`test/ledger_table_test.dart`.
- يعتمد على: لا مسار جديد.
- التراجع: `git revert cc9fb2054f6780400888fc01f233cabf612e1e4e`. afterward: `flutter test test/deposit_website_tone_test.dart test/ledger_table_test.dart --name "glossy" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-018

- الالتزام: `456cfa7fdcd6f9063eb741e36a18544e302e7a00`
- العنوان: VIB-FIX-018: Colour deposit cards like the website, by the balance sign.
- العرض: كروت الأمانات كانت تُلوَّن بعمر الدين لا بإشارة الرصيد.
- السبب: الموقع يفرّق لون الديون عن الأمانات: الموجب في الأمانة أخضر، والسالب أحمر، والصفر أسود، في الثيمين.
- السلوك: العبارة «أمانة للعميل» أو «دين على العميل» أو «لصالح المنظومة» أو «دين علينا للعميل» أو «حساب صفر»، والمبلغ مطلقًا. علامة الصفر بقيت.
- الدليل: `test/deposit_website_tone_test.dart`.
- يعتمد على: فوق 017 للألوان المشتركة. لا مسار جديد.
- التراجع: `git revert 456cfa7fdcd6f9063eb741e36a18544e302e7a00`. afterward: `flutter test test/deposit_website_tone_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-019

- الالتزام: `3d62fd0167d8b2cfd9b9315b67109b8d5128cd07`
- العنوان: VIB-FIX-019: Show collection actions in white on the coloured cards.
- العرض: أزرار كروت الاستلامات للموظف لا تُرى على لون الكرت.
- السبب: الزر المفرغ كان بلون قريب من الكرت. الموقع يضع الأزرار بيضاء بخط أخضر داكن.
- السلوك: استلام كلي وجزئي واتصال في صف واحد، واعتماد ورفض بألوان الموقع، مع قيمة التوجيه والرصيد الحالي من الحقل الموجود.
- الدليل: `test/collections_presentation_test.dart`.
- يعتمد على: حقل `assignedBalanceUnits` الموجود في رد الخادم. لا مسار جديد.
- التراجع: `git revert 3d62fd0167d8b2cfd9b9315b67109b8d5128cd07`. afterward: `flutter test test/collections_presentation_test.dart --name "each fake role" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-020

- الالتزام: `293bfd16afb5b8bd29c2724de743f35939964ba7`
- العنوان: VIB-FIX-020: Make the appearance toggle readable in light and dark.
- العرض: زر المظهر باهت في الثيمين.
- السبب: مسار المفتاح كان قريبًا من لون البطاقة، وأيقونة الدخول بلا أرضية.
- السلوك: المسار كحلي والمؤشر أبيض في النهار، والمسار ذهبي والمؤشر داكن في الليل. باقي الألوان لم تتغير.
- الدليل: مفتاح `theme-switch` و`login-theme`.
- يعتمد على: لا مسار جديد.
- التراجع: `git revert 293bfd16afb5b8bd29c2724de743f35939964ba7`. afterward: `flutter test test/shell_group_test.dart --name "P4" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-021

- الالتزام: `68a7681874ae2b275928eeba3c9022a30b7a45a1` ثم `69ac5c901e1bea4945537a6e946285f673c8c98e` لملء لوحة النموذج.
- العنوان: VIB-FIX-021: Add four login layouts for review without replacing the live screen.
- العرض: خيارات شاشة دخول للمراجعة فقط.
- السبب: الاختيار لم يُحسم، والشاشة الحالية تبقى.
- السلوك: أربع واجهات في `login_design_options.dart` غير مربوطة بالمسار.
- الدليل: `test/ali_preview_screenshots_test.dart` باسم `preview login`.
- يعتمد على: لا يغيّر الدخول.
- التراجع: `git revert 68a7681874ae2b275928eeba3c9022a30b7a45a1`.

## VIB-FIX-022

- الالتزام: `77c628c778764f4fe2028945f8a48f1d266325e1`
- العنوان: VIB-FIX-022: Add four home layouts for review without replacing the live screen.
- العرض: خيارات رئيسية للمراجعة فقط.
- السبب: الاختيار لم يُحسم، والشبكة الحالية تبقى.
- السلوك: أربع واجهات في `home_design_options.dart` غير مربوطة بالمسار.
- الدليل: `test/ali_preview_screenshots_test.dart` باسم `preview login`.
- يعتمد على: لا يغيّر الرئيسية.
- التراجع: `git revert 77c628c778764f4fe2028945f8a48f1d266325e1`.

## VIB-FIX-023

- الالتزام: `07ab6c6509a1ca26fc2088be282f391ee465f8b7`
- العنوان: VIB-FIX-023: Align purchases with the website ledger.
- العرض: «التصحيح مغلق» لم تكن عبارة الموقع، واليوم المرحّل لا يُعدَّل من القائمة، والرأس يختفي، والرصيد الافتتاحي ظاهر.
- السبب: الموقع يقول «مُرحّل» ويفتح اليوم بزر «تعديل اليوم» عبر نفس مسار التصحيح، ويثبّت رأس الجدول، ولا يعرض رصيدًا افتتاحيًا دائمًا.
- السلوك: اليوم المسودة «اليوم الحالي»، والمرحّل «مُرحّل»، والمفتوح «مفتوح للتعديل». رأس الأعمدة يبقى أثناء التمرير. فاصل اليوم يعرض التاريخ وآخر باقي. إجماليات السجل في إطار ذهبي. بطاقة الرصيد الافتتاحي أُزيلت من الصفحة.
- الدليل: `test/purchases_opening_correction_test.dart` و`test/purchases_ledger_layout_test.dart`.
- يعتمد على: `PATCH /api/purchases/{book}/days/{id}/correction` الموجود. لا مسار جديد.
- التراجع: `git revert 07ab6c6509a1ca26fc2088be282f391ee465f8b7`. afterward: `flutter test test/purchases_opening_correction_test.dart test/purchases_ledger_layout_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-024

- الالتزام: `8f86b1cca953a2d34faef3a2e51e12be6f3de013`
- العنوان: VIB-FIX-024: Rebuild the account ledger table to the website's columns.
- العرض: 017 غيّر لون الإجمالي فقط، والجدول بقي كما كان.
- السبب: الموقع جدول أسود الرأس، أقراص للحركة والعملية، والاسم تحت التاريخ، والترقيم يبدأ بـ #.
- السلوك: عمود بواسطة أُلغي وظهر الاسم تحت التاريخ. ديون أحمر، دفع جزئي أخضر، دفع كلي أسود، ومباشر أسود. الإجمالي الذهبي بقي.
- الدليل: `test/ledger_table_test.dart` و`test/ledger_presentation_test.dart`.
- يعتمد على: لا مسار جديد.
- التراجع: `git revert 8f86b1cca953a2d34faef3a2e51e12be6f3de013`. afterward: `flutter test test/ledger_table_test.dart --name "runs 1" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-025

- الالتزام: `8228d747ed098efab90744d026d1ea638c794c30`
- العنوان: VIB-FIX-025: Lay collection cards out like the website.
- العرض: الأزرار صارت ظاهرة والنص مكدّس.
- السبب: الموقع يضع الاسم ثم عمودين (قيمة التوجيه والرصيد الحالي) ثم حالة الكرت.
- السلوك: نفس الترتيب، والحالة من الحقول الموجودة: يحتاج مراجعة، نقدية لم تُسلّم، تم تسليم النقدية، جاهز للمتابعة.
- الدليل: `test/collections_presentation_test.dart`.
- يعتمد على: لا مسار جديد.
- التراجع: `git revert 8228d747ed098efab90744d026d1ea638c794c30`. afterward: `flutter test test/collections_presentation_test.dart --name "fake role" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-026

- الالتزام: `46919585b366e16e425c30204feedbf52e5d4a6b`
- العنوان: VIB-FIX-026: Match the purchases day bar, check mark, and green header.
- العرض: لقطات 023 لم تُظهر الفرق.
- السبب: الموقع يفصل اليوم بشريط «الباقي المرحّل من اليوم السابق»، ويضع علامة صح على الصف المرحّل، ورأس الجدول أخضر.
- السلوك: الشريط ذهبي مع التاريخ وآخر باقي وزر تعديل اليوم. الصف المرحّل عليه علامة صح. الرصيد الافتتاحي ما زال محذوفًا والرأس يبقى ثابتًا.
- الدليل: `test/purchases_ledger_layout_test.dart`.
- يعتمد على: لا مسار جديد.
- التراجع: `git revert 46919585b366e16e425c30204feedbf52e5d4a6b`. afterward: `flutter test test/purchases_ledger_layout_test.dart --name "440" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-027

- الالتزام: `eae40353f6346d8b0e8ecdb505a8157ee488eaa0`
- العنوان: VIB-FIX-027: Remove the rejected login options and keep the live screen.
- العرض: خيارات الدخول الأربعة رُفضت.
- السبب: لا تُستبدل شاشة الدخول.
- السلوك: حُذف `login_design_options.dart`. شاشة الدخول الحية كما كانت.
- الدليل: لا مرجع للملف في الشجرة.
- يعتمد على: يلغي 021 من الواجهة.
- التراجع: `git revert eae40353f6346d8b0e8ecdb505a8157ee488eaa0`.

## VIB-FIX-028

- الالتزام: `658bceb9cf016c62aaca5d7c03820fdc7b0e346b`
- العنوان: VIB-FIX-028: Keep home layout 1 and add three more icon styles.
- العرض: كل تخطيطات الرئيسية رُفضت إلا الأول.
- السبب: المطلوب تطوير الأيقونات على نفس الشبكة.
- السلوك: أربعة أساليب: ثنائي اللون، زجاج متدرج، إطار ذهبي، عمق أخضر. الرئيسية الحية لم تتغير.
- الدليل: `test/ali_preview_screenshots_test.dart`.
- يعتمد على: لا يربط الأساليب بالمسار.
- التراجع: `git revert 658bceb9cf016c62aaca5d7c03820fdc7b0e346b`.

## VIB-FIX-029

- الالتزام: `0eb59f4be86347b7d624a514ff3d4d56885c7953`
- العنوان: VIB-FIX-029: Give the ledger the website's full-screen gold frame.
- العرض: جدول 024 كان داخل شريط التطبيق والصفحة الفاتحة.
- السبب: لقطة الهاتف إطار ذهبي، اسم في كبسولة سوداء، وقلم وإغلاق دائريان، وصفوف كريمية.
- السلوك: شريط التطبيق والشريط السفلي يختفيان على سجل الكرت. الرؤوس أقراص سوداء. بواسطة قرص أسود تحت التاريخ. التعديل أخضر والإلغاء أحمر.
- الدليل: `test/ledger_presentation_test.dart`.
- يعتمد على: لا مسار جديد. التعديل والإلغاء والإغلاق هي الأزرار الموجودة.
- التراجع: `git revert 0eb59f4be86347b7d624a514ff3d4d56885c7953`. afterward: `flutter test test/ledger_presentation_test.dart --name "missing sequence" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-030

- الالتزام: `ba618b43614e0fba4b899fd8e19cc7a5b825dbb6`
- العنوان: VIB-FIX-030: Match the phone collections cards, tabs, and action colours.
- العرض: الكروت كانت كتلًا عريضة والنص غير مرتب.
- السبب: لقطة الهاتف كرت بعرض الشاشة: الاسم، عمودا المبلغ، الحالة، وشريط تفاصيل الاستلامات.
- السلوك: أزرار المرتبات والإغلاق والكشف أخضر وأحمر وأخضر. التبويب الذهبي. التفاصيل تتسع وتظهر أزرار الاعتماد والنقد داخلها.
- الدليل: `test/collections_presentation_test.dart`.
- يعتمد على: لا مسار جديد.
- التراجع: `git revert ba618b43614e0fba4b899fd8e19cc7a5b825dbb6`. afterward: `flutter test test/collections_presentation_test.dart --name "fake role" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-031

- الالتزام: `02c64c1e559869fafcd318f171bb87c974ad8f80`
- العنوان: VIB-FIX-031: Show purchases on a phone as website cards, not a wide table.
- العرض: الجدول الأفقي لا يشبه صفحة المشتريات على عرض الهاتف.
- السبب: الموقع يعرض كل حركة كرت حقول، والباقي بخلفية ذهبية، وفاصل اليوم شريطًا أخضر.
- السلوك: تحت 560 نقطة تصبح الحركات كروتًا. الرأس الأخضر للجدول العريض يبقى على الشاشات الأوسع. لا رصيد افتتاحي. إجماليات السجل تبقى.
- الدليل: `test/purchases_ledger_layout_test.dart`.
- يعتمد على: لا مسار جديد.
- التراجع: `git revert 02c64c1e559869fafcd318f171bb87c974ad8f80`. afterward: `flutter test test/purchases_ledger_layout_test.dart --name "440" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-032

- الالتزام: `0e53fd1a159386dd1903af5512b7f6e4b4f3d750`
- العنوان: VIB-FIX-032: Widen the ledger name capsule and gold-rim the draft pills.
- العرض: اسم الحساب كان حبة صغيرة في الشريط، وأزرار المسودة لم تكن كبسولات سوداء مذهبة.
- السبب: لقطة الهاتف 23 تضع الاسم في كبسولة سوداء عريضة بإطار ذهبي تملأ الشريط، وبجانبها دائرتا القلم والإغلاق.
- السلوك: الكبسولة تأخذ عرض الشريط المتبقي. عناوين الأعمدة حبات سوداء. إطار الصفحة تدرج كريمي إلى ذهبي. أزرار ÷ و × ومباشر سوداء بإطار ذهبي.
- الدليل: `test/ledger_presentation_test.dart`.
- يعتمد على: 029. لا مسار جديد.
- التراجع: `git revert 0e53fd1a159386dd1903af5512b7f6e4b4f3d750`. afterward: `flutter test test/ledger_presentation_test.dart --name "missing sequence" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-033

- الالتزام: `c9beb17b74c28fd940921fdbccd2357aa7b90209`
- العنوان: VIB-FIX-033: Match the phone collection card spacing and gold edge.
- العرض: اسم الموظف كان حبة، وعدد الاستلامات والخط فوق التفاصيل غير ظاهرين.
- السبب: لقطة 20 تضع الموظف نصًا صغيرًا يسار الاسم، و«1 استلام»، وخطًا رفيعًا فوق شريط التفاصيل، وحافة ذهبية أسفل الكرت.
- السلوك: عمود واحد بعرض الشاشة تحت 560. الموظف نص عادي. العدد من طول السجل أو الاستلامات المعلقة. ظل ذهبي أسفل الكرت.
- الدليل: `test/collections_presentation_test.dart`.
- يعتمد على: 030. لا مسار جديد.
- التراجع: `git revert c9beb17b74c28fd940921fdbccd2357aa7b90209`. afterward: `flutter test test/collections_presentation_test.dart --name "fake role" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-034

- الالتزام: `bf48709353fda28bee95089b9ffede2df1082313`
- العنوان: VIB-FIX-034: Put the purchase day controls in one green gold panel.
- العرض: أزرار اليوم والإجماليات كانت متفرقة عن شريط «يوم #».
- السبب: لقطتا 24 و25 تجمعان المبدل والأزرار والإجماليات في لوحة خضراء واحدة بإطار ذهبي وشريط يوم.
- السلوك: اللوحة الخضراء تضم «يوم #» والكتب والإضافة والإنهاء والمربعات الأربعة وفودافون. صف الباقي المرحّل أبيض وحبة المبلغ ذهبية. كروت الحركة كريمية بحقول دائرية.
- الدليل: `test/purchases_ledger_layout_test.dart`.
- يعتمد على: 031. لا مسار جديد.
- التراجع: `git revert bf48709353fda28bee95089b9ffede2df1082313`. afterward: `flutter test test/purchases_ledger_layout_test.dart --name "440" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-035

- الالتزام: `668dba21e0a011c8e5c2e969755e235318f18692`
- العنوان: VIB-FIX-035: Draw four distinct home icon sets on the kept grid.
- العرض: الأنماط الأربعة كانت أيقونة المادة نفسها داخل دائرة معاد تلوينها.
- السبب: المطلوب أربع مجموعات مرسومة: ذهبي على كحلي، زجاج متدرج، عمق، ومربعات بتدرج.
- السلوك: الشبكة عمودان كما هي. كل نمط يرسم مسار القسم بقلمه. الشاشة الحية لم تتبدل. لقطات فاتحة وداكنة لكل نمط.
- الدليل: `test/ali_preview_screenshots_test.dart`.
- يعتمد على: 028 استُبدل رسمه. الدخول الحي كما هو.
- التراجع: `git revert 668dba21e0a011c8e5c2e969755e235318f18692`. afterward: `flutter test test/ali_preview_screenshots_test.dart --name "icon styles" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-036

- الالتزام: `8cd2509218fb505254956a7d04d85bd76c843ab0`
- العنوان: VIB-FIX-036: Give collection cards a solid gold bottom edge.
- العرض: ظل الكرت الذهبي كان رفيعًا ويكاد يختفي تحت الكرت التالي.
- السبب: لقطة 20 تضع حافة ذهبية واضحة أسفل الكرت، وعدد الاستلامات في صف الحالة.
- السلوك: شريط ذهبي 5 نقاط داخل الحافة السفلية وظل ذهبي تحته. شريط التفاصيل أقصر. العدد يظهر عندما يوجد استلام.
- الدليل: `test/collections_presentation_test.dart`.
- يعتمد على: 033. لا مسار جديد.
- التراجع: `git revert 8cd2509218fb505254956a7d04d85bd76c843ab0`. afterward: `flutter test test/collections_presentation_test.dart --name "fake role" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-037

- الالتزام: `fb4fd1b6d608aeedd2050e6a133ae2d8befe0676`
- العنوان: VIB-FIX-037: Draw the collection details mark with a chevron icon.
- العرض: شريط «تفاصيل الاستلامات» كان يرسم مربع حرف ناقص قبل الكلمات.
- السبب: خط Cairo لا يحتوي الرمز ◂، فظهرت خانة بديلة.
- السلوك: السهم أيقونة Material بجانب النص. الكلمات كما هي.
- الدليل: `test/collections_presentation_test.dart`.
- يعتمد على: 036. لا مسار جديد.
- التراجع: `git revert fb4fd1b6d608aeedd2050e6a133ae2d8befe0676`. afterward: `flutter test test/collections_presentation_test.dart --name "fake role" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-038

- الالتزام: `bcfdfa2b41a5d57fbcba66676fe5100a2f7e76e9`
- العنوان: VIB-FIX-038: Rebuild the expanded collection receipt as a white card.
- العرض: الاستلام المفتوح كان صندوقًا مذهبًا داخله لوحة بيضاء للأزرار.
- السبب: لقطة الهاتف تجعل كل استلام كرتًا أبيض بحافة ذهبية: الاسم والمبلغ، ثم الموظف ونوع الاستلام، ثم التاريخ، ثم حبات الإجراء.
- السلوك: الاعتماد والرفض حبتان فاتحتان. تأكيد استلام النقدية الحبة الخضراء الموصولة بـ `markCashReceived`. بعد التسليم حبة محايدة «تم استلام النقدية». شريط التفاصيل يضع ▾ عند الفتح و◂ عند الإغلاق يمين النص. إلغاء الاعتماد غير ظاهر: مساره `POST .../cancel-approval` ليس في العميل و`CollectionsCapabilities.cancelApproval` مغلق.
- الدليل: `test/collections_presentation_test.dart`.
- يعتمد على: 037. لا مسار جديد.
- التراجع: `git revert bcfdfa2b41a5d57fbcba66676fe5100a2f7e76e9`. afterward: `flutter test test/collections_presentation_test.dart --name "fake role" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-039

- الالتزام: `299852337c46a38db69474e3b04ccb5ec9b21369`
- العنوان: VIB-FIX-039: Add cancel-approval beside the cash receipt pill.
- العرض: خطوة النقدية كانت تعرض تأكيد استلام النقدية وحدها.
- السبب: الموقع يضع بجانبها «إلغاء الاعتماد». المسار المؤكد `POST /api/collections/submissions/{id}/cancel-approval`، والجسم `requestId` و`reason` من 5 إلى 500 و`expectedTransactionId`. الخادم يقبله من `role === 'admin'` فقط. معرّف الحركة يأتي من `GET /api/collections/workspace` لأن صفوف `GET /api/collections` لا تختاره.
- السلوك: الحبة الحمراء للإداري عندما يكون الاستلام معتمدًا وبلا نقدية ومعه `approvedTransactionId` وبلا تعارض عملة. الحوار يطلب السبب ثم يرسل. الرد يُعاد جلبه كما أرسله الخادم. الموظف لا يراها.
- الدليل: `packages/api_layer/test/collection_cancel_approval_test.dart` و`test/collections_cancel_approval_test.dart`.
- يعتمد على: 038. لا تغيير في الخادم.
- التراجع: `git revert 299852337c46a38db69474e3b04ccb5ec9b21369`. afterward: `flutter test test/collections_cancel_approval_test.dart --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-040

- الالتزام: `5cc1253e751432e9a85aa38041e763f655cb2f1f`
- العنوان: VIB-FIX-040: Put the ledger save mark inside the draft row.
- العرض: علامة حفظ المسودة كانت خارج الجدول في هامش أيسر.
- السبب: الموقع يضع ✓ خضراء في عمود التعديل و✕ حمراء في عمود الإلغاء على صف الإدخال نفسه.
- السلوك: الصف المحفوظ قلم أخضر وإلغاء أحمر. صف المسودة ✓ باهتة حتى تصلح القيمة ثم ✓ خضراء، وبجانبها مسح الحقول. الشريط أسود: كبسولة الاسم، تعديل البيانات في الوسط، وإغلاق. الإجمالي الذهبي يذكر التالي إن أرسله الخادم.
- الدليل: `test/ledger_table_test.dart` و`test/deposits_ledger_tick_test.dart`.
- يعتمد على: 032. لا مسار جديد.
- التراجع: `git revert 5cc1253e751432e9a85aa38041e763f655cb2f1f`. afterward: `flutter test test/ledger_table_test.dart --name "opens on" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-041

- الالتزام: `613fbb9b880c8c44e0b525b1b6e68381c3b93ee7`
- العنوان: VIB-FIX-041: Give deposit cards a gold rim and two per row.
- العرض: كروت الأمانات كانت بلا إطار ذهبي واضح، وعمود واحد على الهاتف.
- السبب: الموقع يعرض كروتا في الصف، بإطار ذهبي، واللون من إشارة الرصيد.
- السلوك: أخضر لأمانة للعميل، أحمر لدين على العميل، أسود لحساب صفر. الإطار ذهبي. عمودان حين يضيق العرض. التصفية كما هي: الذكية واليوم والديون والمسدد والمثبت.
- الدليل: `test/deposit_website_tone_test.dart`.
- يعتمد على: 018. لا مسار جديد.
- التراجع: `git revert 613fbb9b880c8c44e0b525b1b6e68381c3b93ee7`. afterward: `flutter test test/deposit_website_tone_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-042

- الالتزام: `84ebd12d55a900cd1c12a28432983e8e59576151`
- العنوان: VIB-FIX-042: Show purchases as a ledger table on every width.
- العرض: الهاتف كان يعرض حركات المشتريات كروتًا.
- السبب: المطلوب جدول كجدول التطبيق على الفرع الرئيسي، مع إبقاء لوحة اليوم وفاصل الباقي.
- السلوك: الجدول الأفقي على كل العرض. لوحة اليوم الخضراء، وتعديل اليوم، والرأس اللاصق، وصف الباقي المرحّل، وبلا رصيد افتتاحي.
- الدليل: `test/purchases_ledger_layout_test.dart`.
- يعتمد على: 034. لا مسار جديد.
- التراجع: `git revert 84ebd12d55a900cd1c12a28432983e8e59576151`. afterward: `flutter test test/purchases_ledger_layout_test.dart --name "440" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-043

- الالتزام: `8e00286745837d416c83c3bbce97d0ab6473780f`
- العنوان: VIB-FIX-043: Remove login signup and add four preview designs.
- العرض: بوابة الدخول كانت تعرض طلب حساب، ولا توجد معاينات جديدة.
- السبب: الإدارة تنشئ الحسابات. المطلوب أربع شاشات معاينة فقط لا تستبدل الدخول الحي.
- السلوك: زر طلب الحساب أزيل من البوابة. مسار معلومات الطلب بقي لمن يفتحه مباشرة. أربع معاينات: زجاج على تدرج، شعار منقسم، كريمي ذهبي، أسود بخطوط ذهبية. بلا إنشاء حساب في أي منها.
- الدليل: `test/screens_ui_test.dart`.
- يعتمد على: 027. إنشاء الحسابات من الإعدادات كما هو.
- التراجع: `git revert 8e00286745837d416c83c3bbce97d0ab6473780f`. afterward: `flutter test test/screens_ui_test.dart --name "login is RTL" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-044

- الالتزام: `fa1953beefa532d23825e9806b694486642cdfad`
- العنوان: VIB-FIX-044: Close the collections batch the way the website does.
- العرض: زر «الإغلاق» في استلامات الديون لا يمسح دفعة العمل.
- السبب: الزر كان يرسل تأكيدًا من سطر واحد إلى `POST /api/collections/days/close`. الدفعة التجريبية والحقيقية غالبًا فيها مراجعة معلّقة أو نقدية لم تُستلم، فيرد الخادم 409 `COLLECTION_DAY_NOT_SETTLED`. الرسالة كانت عابرة، بلا حوار الإغلاق الاستثنائي، والزر كان مربوطًا بصلاحية `collections.close_day` بينما الخادم يقبل أي دور `admin`.
- السلوك: الحوار يطابق الموقع: «تأكيد مسح دفعة العمل». إن وُجدت عمليات تنتظر الاعتماد يُعطّل التأكيد. إن بقيت نقدية غير مستلمة يظهر الإغلاق الاستثنائي مع السبب. النجاح يمسح الدفعة من النظرة التالية، والدفعة الجديدة تُفتح عند أول كتابة لاحقة. أي رسالة خطأ من الخادم تبقى في الحوار بالعربية.
- الدليل: `packages/api_layer/test/collection_close_day_test.dart` و`test/collections_close_batch_test.dart`.
- يعتمد على: 019 و039. لا مسار جديد.
- التراجع: `git revert fa1953beefa532d23825e9806b694486642cdfad`. afterward: `flutter test test/collections_close_batch_test.dart --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-045

- الالتزام: `b637d9b95cc9961a8e16749affff2ea45a0e29ff`
- العنوان: VIB-FIX-045: Add four new preview login designs.
- العرض: علي رفض معاينات الدخول 1–4.
- السبب: المعاينات الأربع كانت بطاقة واحدة بخلفيات مختلفة. المطلوب أربع بوابات جديدة، مختلفة في التركيب، بلا ربط بالدخول الحي.
- السلوك: تصاميم 5 و6 و7 و8 للمعاينة فقط. 5 رصيف زجاجي على تدرج كامل. 6 لوحة علامة بجانب النموذج. 7 حروف كبيرة بلا بطاقة. 8 بطاقة على موجات وخطوط ذهبية. خط القاهرة، واتجاه عربي. الحقول اسم المستخدم وكلمة المرور مع إظهار وإخفاء. الزر «تسجيل الدخول». الخطأ «بيانات الدخول غير صحيحة». بلا طلب حساب وبلا إنشاء حساب. شاشة الدخول الحية كما هي.
- الدليل: `test/login_preview_045_test.dart`.
- يعتمد على: 043. لا مسار جديد ولا خط على الدخول الحي.
- التراجع: `git revert b637d9b95cc9961a8e16749affff2ea45a0e29ff`. afterward: `flutter test test/login_preview_045_test.dart --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-046

- الالتزام: `3c7b8eda7b49d4efed440047c7d5b370dd2e062f`
- العنوان: VIB-FIX-046: Use login design 8 on the live login screen.
- العرض: علي اختار تصميم الدخول 8.
- السبب: المعاينة كانت منفصلة عن شاشة الدخول الحية.
- السلوك: الدخول الحي صار التصميم 8: خلفية كحلية وموجات وخطوط ذهبية ودائرة ومعين، وبطاقة كريمية بإطار ذهبي وزوايا، وVIB وأهلًا بك، واسم المستخدم وكلمة المرور وزر إظهار، وزر «تسجيل الدخول» الكحلي. شارة الرقم 8 أزيلت. الخطأ داخل البطاقة. منطق الدخول والجلسة وMFA كما هو. بلا طلب حساب. البطاقة تُمرَّر عند فتح لوحة المفاتيح ولا تفيض على 360×640 بمقياس 1.3.
- الدليل: `test/live_login_046_test.dart`.
- يعتمد على: 045. لا مسار جديد.
- التراجع: `git revert 3c7b8eda7b49d4efed440047c7d5b370dd2e062f`. afterward: `flutter test test/live_login_046_test.dart --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-047

- الالتزام: `2eba44de5970760d934e0bd17a78cdbc61f64404`
- العنوان: VIB-FIX-047: Use home icon set 1 on the live home grid.
- العرض: علي اختار مجموعة الأيقونات 1 على تخطيط الرئيسية 1.
- السبب: المجموعة كانت معاينة فقط، والشبكة الحية ما زالت أيقونات المادة.
- السلوك: كل قسم على الرئيسية يرسم العلامة الكحلية بإطار ذهبي من المجموعة 1، بما فيها الإعدادات. بلا رقم معاينة. المسارات والصلاحيات كما هي. الفاتح والداكن يبقيان تخطيط الشبكة نفسه.
- الدليل: `test/live_home_047_test.dart`.
- يعتمد على: 035 و022. لا مسار جديد.
- التراجع: `git revert 2eba44de5970760d934e0bd17a78cdbc61f64404`. afterward: `flutter test test/live_home_047_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-048

- الالتزام: `22ddddbad5bdbfa7f9b27c57e9945c83f015d617`
- العنوان: VIB-FIX-048: Make the fake suite match the approved screens.
- العرض: 39 اختبارًا في التطبيق و2 في الحزمة كانت تفشل بعد 040–047، و`flutter analyze` كان يُظهر ملاحظات.
- السبب: أغلب الاختبارات ما زالت تتوقع الشكل القديم: شريط الصدفة على الدفتر، تدرجات العمر، صلاحية `collections.close_day`، أيقونة المادة، ومفاتيح `Key`. بعضها كشف عيوبًا حقيقية: فيض «تعديل البيانات»، حبر فاتح على الجدول الكريمي وعلى شريط المشتريات الذهبي، ورسائل التحقق التي لا تظهر عندما `reportErrorInline` مغلق.
- السلوك: الواجهة التي اعتمدها علي لم تُعد تصميمها. الاختبارات القديمة صارت تتوقع السلوك المعتمد. العيوب الحقيقية أُصلحت في مكانها: الزر يتقلص، حبر الجدول والعنوان يُقرأ على الخلفية، وخطأ التاريخ والمبلغ يظهر في شريط. لا حذف لاختبار ولا تخطٍ.
- الدليل: `flutter analyze` بلا ملاحظات. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 820 نجحت، 8 تُركت، 0 فشلت. الحزمة `flutter test --dart-define=USE_FAKE_API=true`: 551 نجحت، 14 تُركت، 0 فشلت.
- يعتمد على: 040 و041 و042 و044 و046 و047. لا مسار جديد.
- التراجع: `git revert 22ddddbad5bdbfa7f9b27c57e9945c83f015d617`. afterward: `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true` ثم `flutter test --dart-define=USE_FAKE_API=true` داخل `packages/api_layer`.

## VIB-FIX-049

- الالتزام: `7c32407d3b503094a9135e135c15003f93e27bed`
- العنوان: VIB-FIX-049: Format the files the CI format check flagged.
- العرض: فحص التنسيق في CI على رأس `06985194` كان يفشل.
- السبب: `dart format` على Dart 3.13.5 يريد إعادة لف خمسة ملفات: `purchases_screen.dart` و`ali_preview_screenshots_test.dart` و`collections_close_batch_test.dart` و`login_design_screenshots_test.dart` و`purchases_presentation_test.dart`.
- السلوك: تنسيق فقط. لا تغيير في السلوك ولا في الواجهة. المسارات نفسها التي يفحصها CI: `lib` و`test` و`packages/api_layer/lib` و`packages/api_layer/test`.
- الدليل: `dart format --output=none --set-exit-if-changed` يخرج 0. `flutter analyze` بلا ملاحظات. التطبيق 820 نجحت و8 تُركت. الحزمة 551 نجحت و14 تُركت.
- يعتمد على: 008 و011 و048. لا مسار جديد.
- التراجع: `git revert 7c32407d3b503094a9135e135c15003f93e27bed`. afterward: `dart format --output=none --set-exit-if-changed lib test packages/api_layer/lib packages/api_layer/test`.

## VIB-FIX-050

- الالتزام: `8491b65f4bf1a6d5a0a6a39a4f850dd41139a1c8`
- العنوان: VIB-FIX-050: Simplify the purchase day break and fit the home grid.
- العرض: فاصل يوم المشتريات كان يكدّس «الباقي المرحّل من اليوم السابق» و«يوم #» والتاريخ السابق والتاريخ الجديد. أيقونات الرئيسية لم تكن في وسط البلاطة، والصفوف العشرة لا تظهر معًا على هاتف 360.
- السبب: الشريط الذهبي كان يعرض رقم اليوم والتاريخين معًا، والمبلغ في طرف الجدول العريض. البلاطة كانت تحاذي محتواها لبداية الاتجاه. ارتفاع الصف الثابت كان أكبر من المساحة تحت الشريط وفوق الشريط السفلي.
- السلوك: سطر واحد للعبارة التي على الموقع «الباقي المرحّل من اليوم السابق» مع مبلغها، وتحته تاريخ اليوم الجديد فقط ثم معاملاته. «تعديل اليوم» والرأس اللاصق وإجماليات الخادم كما هي. كل أيقونة واسمها في وسط البلاطة. ارتفاع الصف يُحسب من الارتفاع المتاح، فيظهر المدير والموظف كاملين على 360×800 و360×640 بمقياس 1. النص الكبير يمرَّر ولا يفيض.
- الدليل: `test/home_purchases_050_test.dart`. `flutter analyze` بلا ملاحظات. `dart format --set-exit-if-changed` على مسارات CI يخرج 0. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 824 نجحت، 8 تُركت، 0 فشلت.
- يعتمد على: 042 و047. لا مسار جديد.
- التراجع: `git revert 8491b65f4bf1a6d5a0a6a39a4f850dd41139a1c8`. afterward: `flutter test test/home_purchases_050_test.dart --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-051

- الالتزام: `6dddb221e5cb55358a426030874bdc7b237fde14`
- العنوان: VIB-FIX-051: Put the purchase day break on one ledger row.
- العرض: فاصل اليوم ما زال يكدّس العبارة والمبلغ والتاريخ والزر فوق بعض.
- السبب: الشريط كان عمودًا بعرض الجدول، فالمبلغ لا يقع تحت عمود «الباقي» والزر لا يقع تحت عمود التعديل.
- السلوك: صف واحد بمحاذاة أعمدة الدفتر. التاريخ الجديد في أول الأعمدة من اليمين. المبلغ تحت «الباقي»، وعبارة «الباقي المرحّل من اليوم السابق» تلميح لأن العمود لا يتسع لها في سطر. «تعديل اليوم» في العمود الأخير. الرأس اللاصق وإجماليات الخادم وتعديل اليوم المرحّل كما هي.
- الدليل: `test/home_purchases_050_test.dart`. `flutter analyze` بلا ملاحظات. التنسيق على مسارات CI يخرج 0. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 825 نجحت، 8 تُركت، 0 فشلت.
- يعتمد على: 042 و050. لا مسار جديد.
- التراجع: `git revert 6dddb221e5cb55358a426030874bdc7b237fde14`. afterward: `flutter test test/home_purchases_050_test.dart test/purchases_ledger_layout_test.dart --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-052

- الالتزام: `649a0bbb7ae45419a7f09c8576da7ae53152c6c6`
- العنوان: VIB-FIX-052: Match the website purchase day break and move totals below.
- العرض: فاصل اليوم لم يطابق الموقع، وكتلة «إجماليات السجل من البداية» ظاهرة، وبطاقات الإجمالي فوق الدفتر، والصفحة لا تفتح على آخر يوم.
- السبب: الصف الواحد كان بين اليومين فقط. الموقع يضع صف إقفال ثم فاصلًا ثم صف افتتاح. الإجماليات كانت فوق الجدول.
- السلوك: في نهاية اليوم «الباقي المُرحّل لليوم التالي — يوم #N» مع حبة ذهبية بالمبلغ تحت «الباقي». ثم شريط داكن رفيع. ثم «الباقي المرحّل من اليوم السابق» بنفس المبلغ، والتاريخ الجديد يمينًا و«تعديل اليوم» في آخر الصف. على الهاتف العبارة والمبلغ ظاهران بلا تمرير أفقي. على الشاشة العريضة الحبة تحت عمود الباقي. المبلغ من `dayClosingDebtUnits`. كتلة إجماليات السجل حُذفت. بطاقات اليوم نُقلت تحت الدفتر بنفس ألوانها. عند الدخول الرأس اللاصق أعلى الشاشة وآخر يوم مع صف الإدخال ظاهر، والإجماليات تحته. تحميل الأقدم عند الصعود كما كان.
- الدليل: `test/home_purchases_050_test.dart`. `flutter analyze` بلا ملاحظات. التنسيق على مسارات CI يخرج 0. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 826 نجحت، 8 تُركت، 0 فشلت.
- يعتمد على: 042 و051. لا مسار جديد.
- التراجع: `git revert 649a0bbb7ae45419a7f09c8576da7ae53152c6c6`. afterward: `flutter test test/home_purchases_050_test.dart test/purchases_presentation_test.dart --exclude-tags screenshots --dart-define=USE_FAKE_API=true`.

## VIB-FIX-053

- الالتزام: `ef5f2b96344f8026d0f3f7cb19a052d588f63670`
- العنوان: VIB-FIX-053: Keep the purchase carry amount on one line.
- العرض: حبة المبلغ «2,000 د.ل» تحت «الباقي» كانت تنزل على سطرين في صفي الترحيل.
- السبب: عرض عمود الباقي أضيق من النص، والنص كان يلتف داخل الحبة.
- السلوك: المبلغ سطر واحد. الحبة تتسع أكثر من العمود وتبقى في وسطه، بلا التفاف وبلا فيض، على 360 و1024 و1280 وبمقياس 1.3. بقية 052 كما هي.
- الدليل: `test/home_purchases_050_test.dart`. `flutter analyze` بلا ملاحظات. التنسيق على مسارات CI يخرج 0. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 832 نجحت، 8 تُركت، 0 فشلت.
- يعتمد على: 052. لا مسار جديد.
- التراجع: `git revert ef5f2b96344f8026d0f3f7cb19a052d588f63670`. afterward: `flutter test test/home_purchases_050_test.dart --name "carry pills" --dart-define=USE_FAKE_API=true`.

## VIB-FIX-054

- الالتزام: `5ebeee6a68fd2a9bff5277349d72347075b97679`
- العنوان: VIB-FIX-054: Show the website running balance in the purchases الباقي column.
- العرض: عمود «الباقي» في التطبيق كان يطبع `remainingUnits` لكل صف، وهو الناتج ناقص المسدد لذلك الصف. الموقع يطبع الرصيد التراكمي بعد المعاملة.
- السبب: الخادم يخزّن `remaining_units = result − paid` في `parseEntry`. الموقع لا يطبع هذا الحقل في العمود. يثبت المشي على `totalDebtUnits` لليوم المفتوح ويمشي من الأحدث إلى الأقدم.
- السلوك: كل صف يعرض الرصيد بعد المعاملة من هذا المشي، بخلفية `#FFE7A3` وحبر `#211A08`. صف الترحيل يبقى على `dayClosingDebtUnits`. غياب إجمالي اليوم، أو صف بناتج أو مسدد غير صالح، يفرغ العمود كله. صف جديد فارغ يبقى «—» لأن التطبيق لا يحسب الناتج محليًا. التنسيق يبقى عبر `MoneyFormatter` مع «د.ل».
- الدليل: `test/purchase_running_balance_test.dart`. `flutter analyze` بلا ملاحظات. التنسيق على مسارات CI يخرج 0. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 837 نجحت، 8 تُركت، 0 فشلت. الحزمة `flutter test --dart-define=USE_FAKE_API=true`: 551 نجحت، 14 تُركت، 0 فشلت.
- يعتمد على: 052 لصفوف الترحيل. لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 5ebeee6a68fd2a9bff5277349d72347075b97679`. afterward: `flutter test test/purchase_running_balance_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-055

- الالتزام: `e5d2362150c2d11ba94b51e6d5880382acd9f940`
- العنوان: VIB-FIX-055: Match the purchases ledger numbers, live الباقي preview, and partial carry label.
- العرض: عمود الباقي وحبوب الترحيل كانت تضيف «د.ل». صف الإدخال الجديد كان يبقي «—» أثناء الكتابة. الصفحة التي ما زال لها أقدم لم تغيّر عنوان أول ترحيل.
- السبب: الموقع يطبع أرقام الدفتر بـ `purchaseNumber` بلا رمز. المعاينة `before + (result − paid)` من معادلة المتصفح. عنوان أول صف يتبدل عندما `nextBefore` ليس فارغًا.
- السلوك: أرقام الدفتر وحبوب الترحيل فواصل آلاف بلا «د.ل». بطاقات اليوم تبقي «د.ل» و«ج.م». الصف الجديد يعرض المعاينة فور الكتابة، والقيمة المحفوظة تبقى من الخادم. إذا بقي `nextBefore` يظهر «الرصيد السابق للمعاملات المعروضة» فوق أقدم صف محمّل، وصفوف الترحيل بين الأيام تبقى «الباقي المرحّل من اليوم السابق».
- الدليل: `test/purchase_preview_test.dart`. `flutter analyze` بلا ملاحظات. التنسيق يخرج 0. التطبيق: 844 نجحت، 8 تُركت، 0 فشلت. الحزمة: 551 نجحت، 14 تُركت، 0 فشلت.
- يعتمد على: 054. لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert e5d2362150c2d11ba94b51e6d5880382acd9f940`. afterward: `flutter test test/purchase_preview_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-056

- الالتزام: `e612f59eb6ab954386f7e535679583e0215ab7fe`
- العنوان: VIB-FIX-056: Center the purchases ledger tick in its cell.
- العرض: علامة الصف المرحّل كانت أيقونة خضراء، وزر الحفظ في صف الإدخال كان زرًا ذهبيًا كبيرًا في أعلى الخلية.
- السبب: عمود الإجراء كان يضع الزر في بداية العمود. الموقع يوسّط الحبة داخل الخلية.
- السلوك: الصف المرحّل حبة 38×22 بخلفية `#007B45` وحد `#A4F6CA`. زر الحفظ حبة 37×26 بخلفية `#008851` وحد `#8AEFBF`، وتصبح 40×40 تحت عرض 700. الإلغاء عند تعديل صف قائم بنفس المقاس بخلفية `#BD152C` وحد `#FF9BAD`. الثلاثة في وسط الخلية أفقيًا وعموديًا، وعلى 360 وبمقياس 2. رسالة الخطأ الطويلة تظهر في الشريط السفلي حتى لا تزيح العلامة.
- الدليل: `test/purchase_tick_056_test.dart`. `flutter analyze` بلا ملاحظات. التنسيق يخرج 0. التطبيق: 849 نجحت، 8 تُركت، 0 فشلت.
- يعتمد على: 055. لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert e612f59eb6ab954386f7e535679583e0215ab7fe`. afterward: `flutter test test/purchase_tick_056_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-057

- الالتزام: `2e11daecb1e546907e1374681d786612f9d18e16`
- العنوان: VIB-FIX-057: Align the purchases edit and delete icons on one line.
- العرض: في صف المشتريات المرحّل كانت أيقونة الحذف أعلى من القلم.
- السبب: زر الحذف كان داخل عمود يتمدد فيملأ ارتفاع الخلية ويجلس في أعلاها، بينما القلم في وسطها.
- السلوك: الزران في صف واحد بعرض ثابت، في وسط الخلية أفقيًا وعموديًا. الحذف `#BD152C` وحد `#FF9BAD`، والتعديل `#008851` وحد `#8AEFBF`. تحت عرض 700 المقاس 40، وفوقه 32.
- الدليل: `test/ali_057_060_test.dart` «purchase edit and delete share one centered line».
- يعتمد على: 056. لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 2e11daecb1e546907e1374681d786612f9d18e16`. afterward: `flutter test test/ali_057_060_test.dart --dart-define=USE_FAKE_API=true --name "purchase edit"`.

## VIB-FIX-058

- الالتزام: `6d0923034ee657473ab88beb0ebb4f03cad96a09`
- العنوان: VIB-FIX-058: Widen المصراوية القيمة and narrow العمولة.
- العرض: الأرقام الطويلة في عمود القيمة كانت تُقطع في جدول شغل اليوم.
- السبب: الأعمدة الأربعة كانت تتقاسم العرض بالتساوي (`flex` 2، 4، 4، 4)، فبقيت القيمة ضيقة والعمولة أعرض مما تحتاج.
- السلوك: التسلسل 2، القيمة 8، العمولة 2، إجمالي الصف 3. الحشو الأفقي للخلية 1. الرقم الطويل يبقى في الحقل بلا حذف ويبلا نقاط قطع، على 360 والعريض وبمقياس النص 2. إجمالي الصف يصغر ليتسع في عموده.
- الدليل: `test/ali_057_060_test.dart` «masraweya القيمة stays wider than العمولة».
- يعتمد على: لا يعتمد على 057. لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 6d0923034ee657473ab88beb0ebb4f03cad96a09`. afterward: `flutter test test/ali_057_060_test.dart --dart-define=USE_FAKE_API=true --name "masraweya القيمة"`.

## VIB-FIX-059

- الالتزام: `41d4fb9067a0c9e440067b2a834b79658f4568cd`
- العنوان: VIB-FIX-059: Apply a remote المصراوية edit while the day is on screen.
- العرض: الكتابة في التطبيق على شغل اليوم تظهر في الموقع فورًا، والكتابة في الموقع أولًا لا تظهر في التطبيق إلا بعد مغادرة الصفحة والعودة.
- السبب: التطبيق مشترك أصلًا في `GET /api/events` و`GET /api/event-changes` ويُسقط ذاكرة القسم عند الموضوع. شاشة المصراوية كانت تُبقي حقول اليوم المربوطة وتحدّث الإجمالي فقط، فلا يُستبدل النص إلا عند إعادة بناء الشاشة.
- السلوك: إذا كانت الحالة محفوظة ولا حقل في التركيز والنص الظاهر يختلف عن رد الخادم، تُعاد تعبئة الحقول. المسودة المتسخة أو أثناء الإرسال أو الخطأ أو التركيز تبقى كما هي، مثل الموقع. التمرير لا يُعاد لأن الاستبدال لا يحدث أثناء الكتابة. الخلفية توقف الاشتراك ثم تُحدّث كل الأقسام عند العودة.
- الدليل: `test/ali_057_060_test.dart` «a saved masraweya day adopts a remote edit unless a field is busy».
- يعتمد على: اشتراك VIB-FIX-012. لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 41d4fb9067a0c9e440067b2a834b79658f4568cd`. afterward: `flutter test test/ali_057_060_test.dart --dart-define=USE_FAKE_API=true --name "remote edit"`.

## VIB-FIX-060

- الالتزام: `52022b4d7c41b77bd285a53f8eaf90f9be5f1fb2`
- العنوان: VIB-FIX-060: Separate the ledger header and lift the total above the nav bar.
- العرض: قلم الإلغاء وزر التعديل لم يكونا على خط واحد. صف الاسم و«تعديل البيانات» والإغلاق كانت مضغوطة في أعلى الصفحة. إجمالي الأسفل كان يغطيه شريط النظام، وعنوانه لم يتبع تسمية كل قسم في الموقع.
- السبب: الزران لم يشاركا صندوقًا واحدًا. الشريط العلوي كان صفًا أفقيًا بلا هامش. البطاقة المثبتة كانت تلتصق بأسفل الشاشة. عنوان العملاء بقي «إجمالي الدين الحالي» حتى عندما يكون الرصيد أمانة.
- السلوك: الزران في صندوق 32 داخل وسط الصف. الاسم، ثم «تعديل البيانات» في الوسط، ثم الإغلاق في الوسط، وتحتهم فراغ صغير. الإجمالي يستخدم تسمية الموقع: «إجمالي الدين الحالي» أو «أمانة للعميل» أو «أمانة للشركة» أو تسمية الأمانة حسب الإشارة، ومعها الكلمة والمبلغ و«التالي» أو «الحساب مسدّد». أسفل البطاقة يحترم `viewPadding`.
- الدليل: `test/ali_057_060_test.dart`. `flutter analyze` بلا ملاحظات. التنسيق يخرج 0. التطبيق: 854 نجحت، 8 تُركت، 0 فشلت.
- يعتمد على: لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 52022b4d7c41b77bd285a53f8eaf90f9be5f1fb2`. afterward: `flutter test test/ali_057_060_test.dart test/ledger_table_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-061

- الالتزام: `5a2ede5289d45a1615962c3ccbbb14a6d86f782c`
- العنوان: VIB-FIX-061: Keep ledger scroll still when a live refresh arrives.
- العرض: السجلات كانت ترتعش عند وصول تحديث. القائمة تقفز إلى آخر الصفوف ثم تعود.
- السبب: كل رد جديد، حتى لو كان نفس النافذة، كان مفتاحه `identityHashCode`. ذلك يمسح الصفوف الأقدم المحمّلة ويعيد طلبها، ثم يقفز التمرير إلى الأسفل. المحاذاة الأفقية كانت تجدول إطارات إضافية بعد أن استقرت.
- السلوك: المفتاح صار الحساب ومؤشر الصفحة الأقدم. تحديث نفس النافذة يبقي الصفوف ويبقي موضع التمرير. القفز إلى أسفل السجل مرة واحدة عند فتح الحساب فقط. أزرار القفز تعلو الجدول ولا تغيّر ارتفاعه. المصراوية تكتب الرقم في الحقل القائم بدل استبداله. المشتريات لا تعيد طلب إظهار آخر صف بعد أول فتح.
- الدليل: `test/ledger_flicker_061_test.dart`. موضع التمرير يبقى 40 بعد إبطال المزود، وعنصر الصف وعنصر حقل القيمة يبقيان هما هما.
- يعتمد على: 059. لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 5a2ede5289d45a1615962c3ccbbb14a6d86f782c`. afterward: `flutter test test/ledger_flicker_061_test.dart --dart-define=USE_FAKE_API=true`.
- متابعة: `e76e75578d55764c3c6466869c43fc74f02b2ac8`. تحميل الصفحات الأقدم كان يعيد محاذاة الأعمدة أفقياً في كل صفحة (`ledger_screen.dart` `_loadOlder`). رأس المشتريات المثبت كان يُعاد بناؤه لأن `shouldRebuild` يقارن هوية الودجت (`purchases_screen.dart` `_FixedHead`). فتح المشتريات كان يسحب القائمة إلى آخر يوم حتى لو حرّكها الإصبع. التحصيل ليس فيه قفز: التمرير يبقى على نفس الحالة بعد إبطال المزود. لا لوحة مفاتيح ولا حركة تتكرر. التراجع عن المتابعة: `git revert e76e75578d55764c3c6466869c43fc74f02b2ac8` أولاً.

## VIB-FIX-062

- الالتزام: `9149c413806b9566bc7f497d8eeb16a85f38c8e2`
- العنوان: VIB-FIX-062: Speak only notifications that arrive after the app is open.
- العرض: فتح التطبيق كان ينطق كل الإشعارات التي وصلت وهو مغلق.
- السبب: `refresh(announce: true)` في `realtime_lifecycle.dart` يرسل كل صف غير مقروء لم يكن في الذاكرة إلى الناقل، واللافتة تنطقه. عند الفتح الذاكرة فارغة أو أُعيد ضبطها، فالقائمة القديمة كلها «جديدة».
- السلوك: علامة «انطق من هنا» تُسجَّل عند الفتح والعودة. صفوف ما قبلها تُعلَّم مسموعة بلا نطق. لا يُنطق إلا صف أحدث من العلامة، ومرة واحدة لكل معرّف. صوت شريط النظام في الخلفية لم يُمس.
- الدليل: `test/speech_watermark_062_test.dart`.
- يعتمد على: لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 9149c413806b9566bc7f497d8eeb16a85f38c8e2`. afterward: `flutter test test/speech_watermark_062_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-063

- الالتزام: `a038918095163b8623e42d8452e8325fdcf5396e`
- العنوان: VIB-FIX-063: Dismiss the incoming banner after five seconds.
- العرض: لافتة الإشعار الداخل كانت تبقى حتى الضغط.
- السبب: `_note` في `foreground_notification_banner.dart` لا يُمسح إلا في `_open`. لا مؤقت ولا سحب.
- السلوك: المؤقت خمس ثوانٍ من `ForegroundNotificationBanner.hold`. الضغط ما زال يفتح. السحب يُغلق. إشعار أحدث يستبدل السابق ويعيد المؤقت. الإغلاق التلقائي والسحب لا يعلّمان الصف مقروءًا، فقائمة الإشعارات كما هي.
- الدليل: `test/banner_063_test.dart`. الساعة الوهمية عبر `tester.pump`.
- يعتمد على: لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert a038918095163b8623e42d8452e8325fdcf5396e`. afterward: `flutter test test/banner_063_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-064

- الالتزام: `5ab602431ae86c61bec3fd5afd7dc235eef16803`
- العنوان: VIB-FIX-064: Restore the pre-060 ledger header row and total card.
- العرض: ترتيب 060 (الاسم فوق «تعديل البيانات» فوق ✕، و«التالي» في سطر المبلغ) رُفض. المطلوب شكل ما قبل 060.
- السبب: شريط الرأس في 060 صار عموداً، وبطاقة الإجمالي غيّرت العنوان ووضعت «التالي» بجانب المبلغ.
- السلوك: صف أفقي واحد كما قبل 060 (الاسم، «تعديل البيانات»، ✕) مع 10dp إضافية من الأعلى. بطاقة الإجمالي عادت: «إجمالي الدين الحالي»، المبلغ والشريحة، ثم «التالي #N» في سطره. هامش سفلي بقدر `viewPadding` فقط. أزرار تعديل الصف وحذفه من 060 بقيت.
- الدليل: `test/ali_057_060_test.dart`. لقطات 360 في مسار المراجعة: قبل 064، بعد 064، ومرجع ما قبل 060.
- يعتمد على: لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 5ab602431ae86c61bec3fd5afd7dc235eef16803`. afterward: `flutter test test/ali_057_060_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-065

- الالتزام: `550388efb295b930f481a9788f539b895ef8f17e`
- العنوان: VIB-FIX-065: Make the whole card the توجيه target.
- العرض: في وضع التوجيه كان مربع صغير داخل الكرت هو وسيلة الاختيار، والضغط على بقية الكرت يفتح السجل.
- السبب: `InkWell` على الكرت يستدعي فتح السجل، ومربع `Checkbox` وحده يستدعي الاختيار.
- السلوك: الزر موجود في ديون العملاء وديون الشركات فقط، كما في الموقع. في الوضع، الضغط في أي مكان على كرت قابل للاختيار يبدّل التحديد (حد، طبقة، وعلامة) ولا يفتح السجل. الضغط المطوّل لا يفعل شيئًا. الكروت غير القابلة تبهت ولا تنتقل. بعد التأكيد أو الإلغاء يعود الضغط لفتح السجل. الأمانات الليبية والمصرية بلا زر توجيه.
- الدليل: `test/fix065_assign_test.dart`.
- يعتمد على: لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 550388efb295b930f481a9788f539b895ef8f17e`. afterward: `flutter test test/fix065_assign_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-066

- الالتزام: `5290e07c4c7d37057d2f7d10e59e86653fb3deb2`
- العنوان: VIB-FIX-066: Match the account cards to the website card.
- العرض: كرت ديون العملاء كان بارتفاع ثابت، فاسم من سطرين يخفي المبلغ ويقص «لدى». الألوان كانت فاتحة في الوضع الفاتح.
- السبب: `customerCardHeight` يقص المحتوى، والترتيب لم يطابق `DebtAccountsView`.
- السلوك: الأقسام الأربعة تستخدم كرت الموقع نفسه. صف علوي: دبوس يسارًا و«لدى: الاسم» يمينًا عند الإسناد (العملاء والشركات فقط، كالموقع). ثم حالة الكرت بقواعد الموقع: دين جديد، مرّ عليه 3 أيام، دين متأخر، أمانة، حساب صفر، وللتأمينات تسميات الإشارة. الاسم في الوسط، المبلغ بالقيمة المطلقة بتجميع `ar-LY` (`2.198`) وبلا سالب، ثم «آخر حركة: yyyy/mm/dd, h:mm ص/م». الدين أحمر داكن، الأمانة أخضر، الصفر أسود، وحافة ذهبية. ارتفاع الكرت يتبع النص. انتظار الاختبار `32a5c227e5c521892506f6023b3b98a4af6977c3`.
- حقل ناقص: الموقع يسقط إلى `updatedAt ?? createdAt` لسطر الحركة. عقد التطبيق يقرأ `lastActivityAt` (أو `lastTransactionAt`) فقط. إن غاب الحقل يظهر «—» ولا يُختلق وقت.
- الدليل: `test/fix066_card_test.dart`.
- يعتمد على: لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert 5290e07c4c7d37057d2f7d10e59e86653fb3deb2`. afterward: `flutter test test/fix066_card_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-067

- الالتزام: `df1ae997207f9604fdb562a9b2974ad8180cd1be`
- العنوان: VIB-FIX-067: Keep the alert socket alive while the screen is locked.
- العرض: صوت التنبيه لا يصل والتطبيق في الخلفية أو الشاشة مقفلة أو بعد إغلاقه.
- السبب: `RealtimeLifecycle` يوقف SSE عند `paused` و`hidden` و`detached`. لا خدمة أمامية. استطلاع WorkManager مطفأ في الإصدار النهائي وفترته 15 دقيقة على الأقل. لا FCM فعّال بلا خادم. قناة التنبيه `vib_notices_sound_v1` عالية الأهمية وبصوت الجهاز، وهذا لم يتغير.
- السلوك: الاتصال يبقى في الخلفية وقفل الشاشة. خدمة أمامية صامتة منخفضة الأهمية (`vib_presence_v1`, `dataSync`) تطلب إبقاء العملية. النطق يبقى موقوفًا أثناء الغياب. إزالة التطبيق من الأخيرة أو إغلاقه بالقوة يقتل محرك Flutter فلا يصل الصوت في وقته. لا بدء بعد إعادة التشغيل لأن أندرويد 12 يمنع خدمة أمامية من `BOOT_COMPLETED`.
- ما يحتاجه الخادم لصوت موثوق بعد القتل: FCM. تسجيل جهاز `POST` لرمز الجهاز (المسار موجود في التطبيق إن فُعّل النقل)، إرسال رسالة بيانات عالية الأهمية على الموضوع عند إشعار جديد، والقناة الافتراضية `vib_notices_sound_v1`. بلا تغيير خادم في هذا الالتزام.
- الدليل: `test/fix067_background_sound_test.dart`.
- يعتمد على: لا مسار جديد ولا تغيير في الخادم.
- التراجع: `git revert df1ae997207f9604fdb562a9b2974ad8180cd1be`. afterward: `flutter test test/fix067_background_sound_test.dart --dart-define=USE_FAKE_API=true`.

## VIB-FIX-068

- الالتزام: `00e990c1f0de70cc2d716e28652d085444115d60`
- العنوان: VIB-FIX-068: Play the notification sound through FCM when the app is killed.
- العرض: إزالة التطبيق من الأخيرة، أو إغلاقه بالقوة، أو إعادة تشغيل الجهاز تقطع صوت التنبيه. اتصال 067 يبقى فقط ما دامت العملية حية.
- السبب: محرك Flutter يموت مع العملية، وأندرويد 12 يمنع خدمة أمامية من الإقلاع. الصوت الموثوق بعد القتل يأتي من رسالة نظام على القناة الموجودة.
- السلوك: `firebase_core` و`firebase_messaging`. بلا `google-services.json` يفشل `initializeApp` مغلقًا، والنقل يبقى بلا عمل، وSSE كما هو، والبناء ينجح. بعد الدخول يُطلب `POST_NOTIFICATIONS` مرة إن كان Firebase قد اشتغل، ويُرسل رمز الجهاز إلى `POST /api/mobile-push/devices` ويُحدَّث عند التبديل، ويُحذف عند الخروج. رسالة النظام تحمل `channel_id` = `vib_notices_sound_v1` فالنظام يشغّل الصوت والتطبيق مقتول. في المقدمة SSE هو مصدر النغمة، ولا يُضاف شريط ثانٍ. علامة النطق من 062 تبقى: المعرّف يُنطق مرة إن كان أحدث من العلامة.
- الدليل: `test/fix068_fcm_test.dart`. بناء debug APK بلا ملف Firebase نجح محليًا، و`FirebaseInitProvider` غير موجود في الحزمة.
- يعتمد على: مسودة الخادم `cursor/fcm-mobile-push-5c94` في `wep-erp-support`. ليست مدمجة وليست منشورة. بلا ملف حساب الخدمة الخادم لا يرسل.
- التراجع: `git revert 00e990c1f0de70cc2d716e28652d085444115d60`. afterward: `flutter test test/fix068_fcm_test.dart test/push_transport_test.dart --dart-define=USE_FAKE_API=true`.
- ملحق بلا نشر: `11d36aab6b70a24bb942368564b7782d96472f84` يثبت أن غياب إعداد Firebase يُبقي النقل بلا عمل. خطة النسخ والتحقق والتراجع بخطوة واحدة في `docs/fcm-deploy-rollback.ar.md`. لا تُنفَّذ الآن. مسودة الخادم المحلية `46b55c854f1c6eb3012d37dd6cae3ffedd995586` فوق `5d45a155893c546c163cf67b33ebf1e816a64a3f`، والتراجع هناك يحذف الجدولين الجديدين وإصدار 59 فقط، ولا يستعيد نسخة مالية أقدم.
- توجيه الدفع: `b6d696c6134d214ffa4f6d0e72ea2ca3673f4daa` يسجّل الفرق. صفوف الإشعار داخل التطبيق لم تُمس. مسودة الخادم `b0d771bf6a1ded89eb219b42fd2fdd0a7a503753` ترسل لكل مدير عملية أي موظف بتفاصيلها، وللموظف ذي صلاحية الاستلام توجيه الكروت فقط.
- جرد الإدارة: `07be1a8fddc7d339f9c2db5985ebb947aaf56d0a`. مسودة الخادم `598d1c58702e416cd404abe41e1277f4a5d26f5f` تدفع لكل مدير عن كل صف إشعار موجود اليوم، بما فيه عملية مدير آخر. الموظف كما هو. الدخول الناجح والفاشل وأخطاء الخادم بلا صف، والاقتراح في `docs/fcm-admin-inventory.ar.md` لا يغيّر التطبيق.
- فك `google-services.json`: `efc3bf690dc8a4f18626f7a2ea8c5920e4494212`. الاختبار يكتب ملفًا مؤقتًا ولا يحذف ملف التطبيق. بناء التصحيح والإصدار يضع `ENABLE_GOOGLE_SERVICES=true` عندما يكون السر موجودًا.
- صوت التطبيق المقتول: `0db8cf8ed10364dc90cc852ab7cfb09af13260c3`. `FirebaseInitProvider` يبقى؛ بلا الملف يسجّل ويتجاوز. `VibApplication` ينشئ قناة `vib_notices_sound_v1` عند بدء العملية حتى يعرض النظام رسالة الإشعار بلا Dart.
- رمز تالف: مسودة الخادم `0fb966e20151685aa3711bda38ed6a3d6e107696`. `INVALID_ARGUMENT` على حقل الرمز و`UNREGISTERED` يحذفان الجهاز بلا إعادة. خطأ الحمولة يُعاد.
- رمز الدخول: مسودة الخادم `58d4d809f56c31803be1f186e3b161976e6cd729`. يُعاد استخدام رمز OAuth حتى خمس دقائق قبل انتهائه.
- دمج `origin/main` `567e9cb5eeb3b7113083dc573bbe69a1dd9706cb` في المسودة عند `d748df2` بلا إعادة قاعدة.
- رمز الجهاز للتجربة: `7a3b2da73c759673ae427a6b0da4a097e85e5ebd`. في بناء التصحيح فقط، شاشة الإعدادات «تطوير التطبيق» تعرض «رمز إشعارات Firebase»: مفعّل أو غير مفعّل، وحالة إذن الإشعارات، وزر «نسخ الرمز»، وزر طلب الإذن إن لم يُمنح. بناء الإصدار لا يضم الصف. فشل تسجيل الرمز على الخادم لا يمنع تهيئة Firebase ولا طلب الإذن، ويبقى صامتًا.

## VIB-FIX-069

- الالتزام: `f77a08d604f5ac5bca8d67b2dd70c29371cc55ad`
- العنوان: VIB-FIX-069: Compact the debt header and keep load-more at the list end.
- العرض: شريط ديون العملاء والشركات كان طويلًا، و«تحميل المزيد» ظاهرًا دائمًا تحت القائمة.
- السلوك: صف واحد مضغوط: إجمالي القسم وزر الإضافة وبينهما فاصل. تحته «النشطة» والبحث و«توجيه» بارتفاع واحد ولون واحد للزرّين. «تحميل المزيد» يظهر بعد بلوغ نهاية الكروت.
- الدليل: `test/customers_summary_total_only_test.dart` و`test/fix069_074_test.dart`.

## VIB-FIX-069b

- الالتزام: `1e21ec4f6b7e53d644b88f70608e0af6e4fc3b9b`
- العنوان: VIB-FIX-069b: Frame the debt total and center the add button.
- السلوك: إجمالي القسم داخل إطار. زر الإضافة في منتصف النصف الآخر. «نشرة الديون» أُزيلت. «النشطة» تعرض `summary.activeCards` كما يصل، مثل «النشطة (10)»، بلا رقم مخترع. للعملاء والشركات.
- الدليل: `test/customers_summary_total_only_test.dart`.

## VIB-FIX-069c

- الالتزام: `ee222ab940b99d78ebfc862078f890fa913aae0b`
- العنوان: VIB-FIX-069c: Match the debt total and the add button.
- السلوك: إجمالي القسم وزر الإضافة إطاران متماثلان: نفس الارتفاع، نفس الزوايا المستديرة، نفس الحد والخلفية. الزر ليس حبة. في منتصف كل نصف. للعملاء والشركات، في النهار والليل.
- الدليل: `test/customers_summary_total_only_test.dart`.

## VIB-FIX-069d

- الالتزام: `dd2893edc14caf0dc51ca48d792bf79f80651d7c`
- العنوان: VIB-FIX-069d: Shorten the two debt header rows.
- السلوك: صف الإجمالي وزر الإضافة، وصف «النشطة» والبحث و«توجيه»، أقصر حشواً وارتفاعاً. الإطار المتماثل والتمركز بقيا. النص يتضاءل مع مقياس الخط ولا يُقص. للعملاء والشركات.
- الدليل: `test/customers_summary_total_only_test.dart`.

## VIB-FIX-070

- الالتزام: `a8238306182650d99ca54eeb744e2ac35305e33c` للبطاقة، والصف الواحد في `f77a08d604f5ac5bca8d67b2dd70c29371cc55ad`.
- العنوان: VIB-FIX-070: Give the wide account card a larger status, name, and amount.
- السلوك: كرت واحد في الصف لديون العملاء والشركات. الحالة في الأعلى، ثم الاسم، ثم مبلغ أكبر، ثم آخر حركة، و«لدى» عند وجود موظف. الألوان كما في 066. لا قص.
- الدليل: مقارنة الصفّين والصف الواحد في لقطات `fix070-cards-compare`.

## VIB-FIX-071

- الالتزام: `3b8d15b37c5bf966206ca4d70749ac45a3fd59d9`
- العنوان: VIB-FIX-071: Keep a day/night toggle in the top bar.
- السلوك: زر المظهر في شريط التطبيق بجانب البحث والإشعارات في كل صفحة تستخدم الهيكل.

## VIB-FIX-072

- الالتزام: `fae2f14e8f062a2cd19632165f0fc112d2ec0945`
- العنوان: VIB-FIX-072: Stack the collections rows at one height.
- السلوك: صفوف الاستلامات تحت بعضها، كل صف أفقي بارتفاع واحد ويفصله خط. حُذفت الجمل التي كانت بين الصفوف.

## VIB-FIX-072b

- الالتزام: `da9d2c21326071ee3125b7225ee21393d252e6ed`
- العنوان: VIB-FIX-072b: Restore the original collections row size.
- السلوك: الصفوف تبقى تحت بعضها، والجمل التي كانت بينها تبقى محذوفة. الارتفاع والحشو والفراغ 6px عادا كما كانا قبل 072.
- الدليل: `test/collections_layout_test.dart`.

## VIB-FIX-072c

- الالتزام: `a630d0b92bf7e0bc74892290241ef3c63fccc923` بعد التراجع `e24ec5a` ثم `5ee4388`.
- العنوان: VIB-FIX-072c: Drop the explanatory lines from collections.
- السلوك: صفوف الاستلامات عادت كما كانت قبل 072: القائمتان جنباً إلى جنب، والأزرار الثلاثة، وصناديق الملخص الأربعة في صف واحد، والبحث مع إجماليات الموظفين. حُذفت فقط جمل الشرح بين الصفوف. سطر «مراجعة» و«نقدية غير مستلمة» بقي.
- الدليل: `test/collections_layout_test.dart`.

## VIB-FIX-073

- الالتزام: `f39cb8d05a6a7ad691db7bfdb6ea8ca05695bec2`
- العنوان: VIB-FIX-073: Open the named purchase day and pencil the active rows.
- السبب: زر «تعديل اليوم» كان مرسومًا على صف افتتاح اليوم التالي، بينما المعرّف هو اليوم الذي يسمّيه صف «الباقي المُرحّل لليوم التالي — يوم #N» فوق الفاصل، فبدا أنه يفتح اليوم الأسفل.
- السلوك: الزر على صف اليوم المُسمّى (اليوم الأعلى). معاملات اليوم المفتوح تظهر بقلم، وبعد الترحيل تصبح علامة ✓. التعديل يستخدم مسار التحديث المنشور. لا مسار جديد.
- الدليل: `test/fix069_074_test.dart`.

## VIB-FIX-074

- الالتزام: `5d51ef36221a2a8e5edefd09fdbca2c03e224c0f`
- العنوان: VIB-FIX-074: Make the appearance switch readable in the light theme.
- السبب: مفتاح المظهر وهو مطفأ كان يتوه في الخلفية الفاتحة.
- السلوك: المسار كحلي والإبهام أبيض في النهار، وذهبي في الليل. العنوان «المظهر».

## VIB-FIX-075

- الالتزام: `8e3e7785b2cf2f838ded06e16a3fa3329cf699b6`
- العنوان: VIB-FIX-075: Match unified search to the website suggestions.
- السلوك: البحث الموحّد يستدعي `GET /api/account-search` بعد 250ms ومن حرفين، مثل الموقع. كل صف يعرض الاسم والقسم والتوجيه والرصيد، ويفتح السجل. «عرض الكارت» للعملاء والشركات. بلا نتائج: «لا توجد حسابات مشابهة.». لا مسار جديد.
- الدليل: `test/fix075_search_test.dart`.

## VIB-FIX-076

- الالتزام: `e32c8a0`
- العنوان: VIB-FIX-076: Show pencil and trash on the active purchase day.
- السلوك: صف محفوظ في اليوم النشط يظهر قلمًا وسلة بعد التأكيد. اليوم المُرحّل يبقي ✓ حتى «تعديل اليوم».
- الدليل: `test/fix076_purchases_test.dart`.

## VIB-FIX-077

- الالتزام: `40678af`
- العنوان: VIB-FIX-077: Open the notification target, then mark it read.
- السلوك: الضغط يفتح القسم أو السجل من `sectionKey` أو `entityType`، ثم يعلّم الإشعار مقروءًا. كارت مفقود يفتح قسمه.
- الدليل: `test/notification_opener_test.dart`.

## VIB-FIX-078

- الالتزام: `c47a6aa`
- العنوان: VIB-FIX-078: Show the cash ledger oldest first.
- السلوك: الأقدم في الأعلى والأحدث في الأسفل. فتح الخزينة يبقي بطاقات الإجمالي ظاهرة ونافذة السجل على آخر حركة.
- الدليل: `test/treasury_cash_grid_test.dart`.

## VIB-FIX-079

- الالتزام: `e644949`
- العنوان: VIB-FIX-079: Keep last movement and drop the empty توجيه gap.
- السلوك: سطر آخر حركة ظاهر. بلا توجيه يبدأ المحتوى من الأعلى. مع توجيه يُعاد ترتيب الكرت. للأقسام الأربعة.
- الدليل: `test/customers_summary_total_only_test.dart`.

## VIB-FIX-080

- الالتزام: `e644949`
- العنوان: VIB-FIX-080: Paint light cards white with nature-coloured text.
- السلوك: في النهار الخلفية بيضاء. الدين أحمر، الأمانة أخضر، الصفر بني. بدائل الخلفيات والإطارات في لقطات `fix080`.
- الدليل: `test/fix076_081_screenshots_test.dart`.

## VIB-FIX-081

- الالتزام: `e644949`
- العنوان: VIB-FIX-081: Show Egyptian deposits one card per row.
- السلوك: الأمانات المصرية كرت واحد في الصف، مثل ديون العملاء. حسابها يبقى مستقلًا.

## VIB-FIX-082

- الالتزام: `9ec0ba0502692f4b31f9f4987c1b10e0bb48f223`
- العنوان: VIB-FIX-082: Use the cream card fill in light mode.
- السلوك: كروت الأقسام الأربعة في النهار خلفيتها الكريمي `#FFF8EE`. لون النص يبقى حسب الطبيعة: دين أحمر، أمانة أخضر، صفر بني.

## VIB-FIX-083

- الالتزام: `9ec0ba0502692f4b31f9f4987c1b10e0bb48f223`
- العنوان: VIB-FIX-083: Match the deposit total, active count, and add button.
- السلوك: صف الإجمالي والنشط وإضافة الأمانة في الأمانات الليبية والمصرية ثلاثة مستطيلات متساوية بزوايا 12، أقصر من الصف السابق.

## VIB-FIX-084

- الالتزام: `9ec0ba0502692f4b31f9f4987c1b10e0bb48f223`
- العنوان: VIB-FIX-084: Keep Egyptian deposits one card per row.
- السلوك: قائمة الأمانات المصرية عمود واحد بعرض الشاشة في كل المقاسات، في النهار والليل. ليست شبكة.
- الدليل: `test/fix082_084_test.dart`.

## VIB-FIX-085

- الالتزام: `e112fafc20ef9ee8b87fc50ced589fc554b445dc`
- العنوان: VIB-FIX-085: Show one card per row in all four sections.
- السلوك: عملاء الديون وشركات الديون والأمانات الليبية والأمانات المصرية كرت واحد في الصف بأي عرض. جسم الكرت واحد، وحساب كل قسم يبقى مستقلًا.
- الدليل: `test/fix085_086_test.dart`.

## VIB-FIX-086

- الالتزام: `e112fafc20ef9ee8b87fc50ced589fc554b445dc` ثم `c69adc839247a1a8ec7c21d5019ceac4be6e0826`
- العنوان: VIB-FIX-086: Start card text at the top and park the pin in the corner.
- السلوك: صف التثبيت لم يعد يحجز فراغًا فوق النص. الدبوس في زاوية الكرت. نص التوجيه، إن وُجد، يدخل في أول السطر ثم يتبعه الحال والاسم. فتح كرت من البحث يقرأ مسار الموجّه مباشرة حتى لا يتوقف الانتقال عند مغادرة الكشف.

## VIB-FIX-087

- الالتزام: `49b2853abe7478a41c585a2ff9f9fd8bbe81d506`
- العنوان: VIB-FIX-087: Show آخر حركة from the list card's updatedAt.
- السلوك: قوائم الأقسام الأربعة على الإنتاج لا ترسل `lastActivityAt`. الموقع يرسم «آخر حركة» من `updatedAt` ثم `createdAt` على نفس صف القائمة. التطبيق يقرأ هذا الترتيب لكل قسم من استجابته، بلا طلب سجل لكل كرت.
- الدليل: `packages/api_layer/test/fix087_movement_test.dart` و`test/fix087_movement_test.dart`.

## VIB-FIX-089

- الالتزام: `cb969cbe5c46a22e33abfdfff551a3eb26d66f07`
- العنوان: VIB-FIX-089: Paint zero cards in أسمر.
- السلوك: نص كرت حساب صفر وحافته في النهار `#4A3728`، أغمق وأقل برتقاليًا من `#6B4423`. في الليل النص `#D7C4A8` والحافة الذهبية تبقى. الدين والأمانة كما هما في الأقسام الأربعة.
- الدليل: `test/fix089_zero_ink_test.dart`.

## VIB-FIX-090

- الالتزام: `2111e23fc281c7817847b441b75e60c5d860103e` ثم `130db15b6d55c75b739ad27f0af6651b931e63e8`
- العنوان: VIB-FIX-090: Keep pencil and X on every saved active-day purchase.
- السلوك: كل صف محفوظ في اليوم المفتوح يظهر قلمًا وعلامة حذف، بعد الحفظ وبعد إعادة التحميل وبعد إضافة صفوف أخرى. التعديل يحفظ عبر `PATCH /api/purchases/{book}/entries/{id}` والحذف بعد التأكيد عبر `DELETE` على نفس المسار. اليوم المرحّل يبقى بعلامة الصح حتى «تعديل اليوم». حالة اليوم تُنسخ من `entryDays` كما في الموقع.
- الدليل: `test/fix090_purchases_test.dart`.

## VIB-FIX-091

- الالتزام: `c43b888f0ed60c6fdca31558a99564a91ff6ebb8`
- العنوان: VIB-FIX-091: Replace raw server-reply banners with تم الحفظ.
- السلوك: نجاح إضافة معاملة أو تعديل أو حذف لا يعرض «رد الخادم» ولا معرّفًا. يظهر «تم الحفظ» لثانيتين في المشتريات والتحصيلات والأمانات والديون والخزينة. الفشل يبقى جملة عربية، ورمز الخطأ الخام يُستبدل بجملة معروفة أو بجملة عامة. التشخيص يبقى في سجل التصحيح فقط.
- الدليل: `test/fix091_saved_message_test.dart`.

## VIB-FIX-094

- الالتزام: `a44915a0ab1ae27626a98b848fc51ec2bce94b3c`
- العنوان: VIB-FIX-094: Match the masraweya work-table money columns.
- السلوك: أعمدة القيمة والعمولة والإجمالي في جدول شغل اليوم صارت بعرض واحد وإطار واحد وارتفاع واحد. الإجمالي يبقى للعرض فقط. الحساب والحفظ التلقائي والمجموع كما هما.
- الدليل: `test/fix094_work_table_test.dart`.

## ما لم يُرقم لأنه ليس إصلاح عميل

اشتراك دفع المتصفح (`BrowserPushControls`) ولوحة تجربة أصوات المتصفح لا مقابل لهما بلا عقد دفع للهاتف. `GET /api/notifications` يعيد غير المقروء فقط ويحذف الصف عند التعليم كمقروء؛ التطبيق يستعمل نفس المسار. لا مسار جديد في هذه الجولة.

تكرار تقديم التحصيل بعد ضياع الرد، وربط الأمانة المصرية، وتفعيل MFA، وقائمة الجلسات، وإغلاق المصراوية عند 04:00، وقفل الالتقاط. خادم مراجعة الأقسام الأربعة منشور على الإنتاج `https://vip2100.com` منذ 2026-11-09 (مستودع الموقع `64f33ffb3c61db38c78cbe520d90f79a6a3ba7f2`، schema 57).

## فحص المجموعة بعد 016

قبل 012 على `4ecc7cf`: `flutter analyze` بلا ملاحظات. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 810 نجحت، 8 تُركت، 0 فشلت. الحزمة `flutter test --dart-define=USE_FAKE_API=true`: 545 نجحت، 14 تُركت، 0 فشلت.

بعد 014: `flutter analyze` بلا ملاحظات. التطبيق 816 نجحت و8 تُركت. الحزمة 545 نجحت و14 تُركت. بعد 016: اختبار آخر الكارت على 320×568 ومقياس 2 نجح للأقسام الأربعة، واختبارات القناة نجحت. المجموعة الكاملة تُعاد في فحص الطلب. 10 نوفمبر 2026. خادم وهمي فقط.

لا تغيير في عقد الخادم. النطق والنغمة على الجهاز. إشارة التغيير من المسارات الموجودة.
