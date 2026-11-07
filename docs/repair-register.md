# سجل الإصلاحات

الأرقام ثابتة. لا يُعاد استخدام رقم أُلغي. التراجع يكون بالتزام `git revert` جديد، لا بمسح التاريخ ولا بإعادة القاعدة.

الفرع المحلي: `cursor/settings-visual-ff44`.
رأس السجل عند كتابته: انظر آخر التزام `VIB-FIX-REG` في `git log`.

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

## ما لم يُرقم لأنه ليس إصلاح عميل

تكرار تقديم التحصيل بعد ضياع الرد، ومراجعة الصفر لغير العملاء، وربط الأمانة المصرية، وتفعيل MFA، وقائمة الجلسات، وإغلاق المصراوية عند 04:00، وقفل الالتقاط. لا عقد منشور يغلقها من التطبيق.

## فحص المجموعة بعد 003

`flutter analyze` بلا ملاحظات. `flutter test --exclude-tags screenshots --dart-define=USE_FAKE_API=true`: 795 نجحت، 8 تُركت، 0 فشلت. الثمانية لقطات موقوفة. لم يُعد اختبار أندرويد لأن كود الالتقاط لم يتغير. 7 نوفمبر 2026. خادم وهمي فقط.
