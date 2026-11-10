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

## ما لم يُرقم لأنه ليس إصلاح عميل

اشتراك دفع المتصفح (`BrowserPushControls`) ولوحة تجربة أصوات المتصفح لا مقابل لهما بلا عقد دفع للهاتف. `GET /api/notifications` يعيد غير المقروء فقط ويحذف الصف عند التعليم كمقروء؛ التطبيق يستعمل نفس المسار. لا مسار جديد في هذه الجولة.

تكرار تقديم التحصيل بعد ضياع الرد، وربط الأمانة المصرية، وتفعيل MFA، وقائمة الجلسات، وإغلاق المصراوية عند 04:00، وقفل الالتقاط. خادم مراجعة الأقسام الأربعة منشور على الإنتاج `https://vip2100.com` منذ 2026-11-09 (مستودع الموقع `64f33ffb3c61db38c78cbe520d90f79a6a3ba7f2`، schema 57).

## فحص المجموعة بعد 016

قبل 012 على `4ecc7cf`: `flutter analyze` بلا ملاحظات. التطبيق `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 810 نجحت، 8 تُركت، 0 فشلت. الحزمة `flutter test --dart-define=USE_FAKE_API=true`: 545 نجحت، 14 تُركت، 0 فشلت.

بعد 014: `flutter analyze` بلا ملاحظات. التطبيق 816 نجحت و8 تُركت. الحزمة 545 نجحت و14 تُركت. بعد 016: اختبار آخر الكارت على 320×568 ومقياس 2 نجح للأقسام الأربعة، واختبارات القناة نجحت. المجموعة الكاملة تُعاد في فحص الطلب. 10 نوفمبر 2026. خادم وهمي فقط.

لا تغيير في عقد الخادم. النطق والنغمة على الجهاز. إشارة التغيير من المسارات الموجودة.
