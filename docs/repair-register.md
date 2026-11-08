# سجل الإصلاحات

الأرقام ثابتة. لا يُعاد استخدام رقم أُلغي. التراجع يكون بالتزام `git revert` جديد، لا بمسح التاريخ ولا بإعادة القاعدة.

الفرع المحلي: `cursor/section-full-grant-ff44`.
رأس السجل عند كتابته: انظر آخر التزام `VIB-FIX-REG` في `git log`. أرقام 001–005 وهاشاتها لم تتغير.

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

## ما لم يُرقم لأنه ليس إصلاح عميل

تكرار تقديم التحصيل بعد ضياع الرد، ومراجعة الصفر لغير العملاء، وربط الأمانة المصرية، وتفعيل MFA، وقائمة الجلسات، وإغلاق المصراوية عند 04:00، وقفل الالتقاط. لا عقد منشور يغلقها من التطبيق.

## فحص المجموعة بعد 006

`flutter analyze` بلا ملاحظات. `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 803 نجحت، 8 تُركت، 0 فشلت. الثمانية لقطات موقوفة. لم يُعد اختبار أندرويد لأن كود الالتقاط لم يتغير. 8 نوفمبر 2026. خادم وهمي فقط. لقطتا 360 بمقياس النص 2 فاتح/داكن: `section-grant-light-360` و`section-grant-dark-360`.

فُحص في هذه الجولة ولم يُغيّر: مسودة الكتابة في `GuardedMutation` مربوطة بمعرّف المستخدم وتُسقط عند تغيّر الجلسة؛ `onSessionTransition` يبطل القراءات ويمسح تاريخ الرجوع عند الخروج. حفظ القيود يقفل الزر أثناء الطيران. لم يُثبت عيب حفظ/إلغاء إضافي. ترقيم الصفحات السابق لم يُعد فتحه.

006 لا يضيف مراجعة صفر للشركات أو الأمانات. لا مصدر خادم في هذا المستودع، ولا مسار `POST` منشور لهذه الأقسام.
