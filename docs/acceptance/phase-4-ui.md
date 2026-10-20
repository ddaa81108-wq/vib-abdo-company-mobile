# قبول المرحلة 4: واجهة المستخدم على Fake API

الحكم: الشاشات المطلوبة كلها موجودة. لا عيب مانع. أربعة عيوب غير مانعة، أهمها أن مبلغ الدين ومبلغ السداد في الدفتر يشتركان في لون واحد، وأن تدرج `ageStatus` يظهر على كارت القائمة ولا يظهر في رأس الدفتر ولا في نشرة الديون على الرئيسية.

لم يُعدَّل أي ملف إنتاج لإخفاء عيب أو إصلاحه. الأدلة لقطات golden من اختبار ودجت على عميل Fake API، مع فحص الكود حيث لا ترسم البيانات التجريبية الحالة.

رموز خانات الجدول: **ناجح** (Pass)، **فاشل** (Fail)، **ملاحظة** (Note).

## النطاق والمنهج

المراجعة على الفرع الذي بُني من `main`، لتطبيق Flutter «سجل التحصيل» والعلامة VIB. التشغيل افتراضيًا على Fake API (`USE_FAKE_API=true`) بلا شبكة. مرجع الصلاحيات هو القسم 4 من تحليل مدير المشروع، ومعايير الواجهة المطلوبة لهذه الجولة هي الستة أدناه. معايير المرحلة 4 في القسم 6 من التحليل (المشتريات والخزينة) مذكورة في آخر الوثيقة عندما لا يغطيها عمود الجدول.

الشاشات المطلوبة كلها لها مسار في `lib/state/router_provider.dart`. لا شاشة ناقصة. «إعدادات المستخدم» في المنتج شاشتان منفصلتان، فسُجّلتا صفّين: `/account` لكل من دخل، و`/settings` لمن يملك صلاحية كاملة أو `settings.manage`.

| الشاشة | المعرف | المسار | الملف |
|---|---|---|---|
| تسجيل الدخول | `login` | `/login` | `lib/features/login/login_screen.dart` |
| الرئيسية | `home` | `/` | `lib/features/home/home_dashboard.dart` |
| القائمة الجانبية / قائمة الجوال | `menu` | فوق `/` | `lib/features/home/home_shell.dart` |
| ديون العملاء | `customers` | `/customers` | `lib/features/accounts/account_list_screen.dart` |
| ديون الشركات | `companies` | `/companies` | الملف نفسه |
| دفتر العميل | `customer-ledger` | `/customers/c_55` | `lib/features/accounts/ledger_screen.dart` |
| دفتر الشركة | `company-ledger` | `/companies/c_55` | الملف نفسه |
| الأمانات الليبية | `libyan-deposits` | `/libyan-deposits` | قائمة الحسابات |
| الأمانات المصرية | `egyptian-deposits` | `/egyptian-deposits` | قائمة الحسابات |
| المشتريات | `purchases` | `/purchases` | `lib/features/purchases/purchases_screen.dart` |
| استلامات الديون | `collections` | `/collections` | `lib/features/collections/collections_screen.dart` |
| الخزينة | `treasury` | `/treasury` | `lib/features/treasury/treasury_screen.dart` |
| التقارير الذكية | `reports` | `/reports` | `lib/features/reports/reports_screen.dart` |
| الإعدادات الإدارية | `settings` | `/settings` | `lib/features/settings/settings_screen.dart` |
| إعدادات المستخدم | `account` | `/account` | `lib/features/settings/account_screen.dart` |
| الإشعارات | `notifications` | `/notifications` | `lib/features/notifications/notifications_screen.dart` |

دفتر الأمانات الليبية والمصرية هو `LedgerScreen` نفسه. لم يُطلب صف مستقل له. إخفاء «سداد كلي» في الأمانات فُحص من الكود (`ledger_screen.dart` حوالي السطر 113) ولم يُرسم في اللقطات.

المنهج لكل خلية `theme × size × role`:

- اختبار `test/phase4_ui_acceptance_test.dart` يضخ `CompanyApp` مع `ApiLayer` تجريبي وزمن استجابة صفر.
- الخطوط المحمّلة: `Cairo` و`JetBrainsMono` من `assets/fonts/`.
- السطح: `360×640` و`412×915` و`800×1280`، و`devicePixelRatio = 1`.
- السمتان: `ThemeMode.light` و`ThemeMode.dark` عبر `buildAppTheme`.
- اللقطات: `test/goldens/phase4/` (366 ملف PNG). الفهرس في آخر هذه الوثيقة، والخلايا الآلية في `test/goldens/phase4/observations.json`.
- فيض التخطيط يُلتقط من `FlutterError` ولا يُفشل الاختبار، حتى يبقى `tool/check.sh` قادرًا على المرور. لم يُسجَّل أي فيض في الخلايا الـ366.
- ما لا ترسمه البيانات التجريبية وُسم «فحص كود»: بقية قيم `ageStatus` غير `warning`، وصف الخروج في دفتر الخزينة، وتنبيه غياب سعر التحويل، ويوم مشتريات `finalized`.

عند عرض 800 نقطة تكون القائمة `NavigationRail` ممتدة (`width > 560` و`width <= 900` في `lib/ui/tokens.dart`) لا `Drawer`. الـ`Drawer` يُفتح من الحافة الابتدائية (اليمين في RTL) على 360 و412. هذا سلوك نقاط التوقف الحالية، لا شاشة ناقصة.

## حسابات Fake API

كلمة المرور في الاختبار `demo-only`. أي كلمة غير `wrong` مقبولة في `fake_api_client.dart`. اختيار الملف من بادئة اسم الدخول في `FakeFixtures.meFor` (`packages/api_layer/lib/data/fake/fake_fixtures.dart`).

| الدور في هذه المراجعة | اسم الدخول | قيمة `role` | ما يمنحه الكود |
|---|---|---|---|
| `admin` | `admin.demo` | `admin` | قوائم فارغة بلا `fullAccess` صريح، فالصلاحية كاملة |
| `limited.admin` | `limited.admin` | `admin` | `collections.read/write/decide` و`debts.read` و`customerDebts: read` |
| `employee` | `employee.demo` | `employee` | `collections.read/write` و`debts.read` و`customerDebts: read` وبقية الأقسام `none` |
| `guest` | `guest.demo` | `guest` | دور غير معروف. الأكواد المرسلة لا تُمنح |

`limited.admin` يظهر في الواجهة «مدير النظام» لأن نص الدور يتبع تصنيف `AccountRole.admin` (`roleLabel` في `lib/ui/section_labels.dart`). الاسم المعروض «إداري محدود تجريبي». التقييد يظهر بإخفاء الأقسام والأزرار لا بتغيير لقب الدور. هذا مطابق للكود، وليس عيبًا.

الممنوع يُخفى ولا يُعطّل (`PermissionService`). فتح مسار بلا قراءة يعيد التوجيه إلى `/` (`permissionRedirect` في `lib/authentication/auth_gate.dart`). لم يظهر `forbidden-pane` في أي خلية.

## جدول الشاشة × المعيار

| الشاشة | العربية وRTL | الفاتح والداكن | الهوية | المقاسات | ألوان المال | الصلاحيات |
|---|---|---|---|---|---|---|
| تسجيل الدخول | ناجح | ناجح | ناجح | ناجح | ملاحظة | ملاحظة |
| الرئيسية | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| القائمة | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| ديون العملاء | ناجح | ناجح | ناجح | ناجح | ناجح | ناجح |
| ديون الشركات | ناجح | ناجح | ناجح | ناجح | ناجح | ناجح |
| دفتر العميل | ملاحظة | ناجح | ناجح | ناجح | فاشل | ناجح |
| دفتر الشركة | ملاحظة | ناجح | ناجح | ناجح | فاشل | ناجح |
| الأمانات الليبية | ناجح | ناجح | ناجح | ناجح | ناجح | ناجح |
| الأمانات المصرية | ناجح | ناجح | ناجح | ناجح | ناجح | ناجح |
| المشتريات | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| استلامات الديون | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| الخزينة | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| التقارير الذكية | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| الإعدادات الإدارية | ملاحظة | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| إعدادات المستخدم | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |
| الإشعارات | ناجح | ناجح | ناجح | ناجح | ملاحظة | ناجح |

خلاصة الخانات: لا فشل إلا عمود ألوان المال في دفتري العميل والشركة. «ملاحظة» تعني أن المعيار لا ينطبق، أو أن الدليل جزئي، أو أن هناك عيبًا غير مانع موضحًا تحت الشاشة. لا خانة فاشلة مانعة.

الهوية التي قيست في كل الخلايا المطابقة: عائلة `Cairo` على `bodyMedium`، و`ColorScheme.primary` يساوي `#175F50` في الفاتح و`#247763` في الداكن (`lib/ui/theme.dart`). مبالغ `MoneyText` ترسم بـ`JetBrainsMono`. الشريط والقائمة على خلفية `sidebarBg` مع ذهبي العلامة (`AppSidebarPalette.gold`). كلمة `VIB` وعلامة «ع» من `AppStrings`، وهما جزء من الهوية لا نص إنجليزي دخيل.

اتجاه `Directionality` كان `rtl` في كل الخلايا. حقول البريد وكلمة المرور والهاتف والمبلغ `ltr` داخل الصفحة، وهذا متعمّد (`LtrText` / `MoneyText` / حقول الدخول).

## العيوب

### مانعة

لا يوجد.

لم يُرصد: شاشة ناقصة، اتجاه صفحة LTR، فيض `RenderFlex`، قص يرسم شريط الفيض، زر كتابة أو اعتماد أو نقد أو إقفال أو إعدادات ظاهر لدور لا يملكه، ولا انعكاس لون دين/سداد إلى اللون المعاكس.

### غير مانعة

#### P4-001 — مبلغ الدين ومبلغ السداد بلون واحد في الدفتر

- الشاشة: دفتر العميل ودفتر الشركة (`LedgerScreen`). الأمانات تستخدم الشاشة نفسها.
- الأدوار: `admin` و`limited.admin` و`employee` (من يفتح دفتر العملاء). الشركات للمدير فقط.
- السمة والمقاس: الفاتح والداكن، و360×640 و412×915 و800×1280.
- الخطوات: الدخول بحساب يملك قراءة العملاء، فتح `/customers/c_55`.
- المتوقع: لون `debtText` للحركة `debt` ولون `creditText` للحركة `payment`، كما في نبرة ملخصات الرئيسية (`#A54339` / `#23705D` فاتح، و`#FFB1B7` / `#92DFC2` داكن).
- الفعلي: التسميتان «دين» و«سداد» صحيحتان، ومبلغا `500 د.ل` و`180 د.ل` يرثان لون النص (`style.color` فارغ في المجس). المعنى يبقى في الكلمة لا في اللون.
- الدليل: `lib/features/accounts/ledger_screen.dart` في `_EntryTile` (أسلوب `MoneyText` حوالي السطور 580–585). التعريف في `lib/ui/theme.dart` (`debtText` / `creditText`). المجس في `observations.json` للحقل `probe.ledgerMoney`.
- اللقطة: [دفتر العميل، فاتح، 360](../../test/goldens/phase4/customer-ledger__light__360x640__admin.png).

#### P4-002 — تدرج `ageStatus` على كارت القائمة فقط

- الشاشة: الرئيسية (نشرة الديون) ورأس الدفتر. كارت القائمة نفسه يلوّن التدرج بشكل صحيح.
- الأدوار والسمات والمقاسات: كل من يرى النشرة أو الدفتر، في السمتين والمقاسات الثلاثة.
- الخطوات: مقارنة كارت «عميل تجريبي» في `/customers` مع صف النشرة في `/` ومع رأس `/customers/c_55`.
- المتوقع: حالة `warning` تستخدم تدرج `warningDebt` في كل سطح يعرض عمر الدين.
- الفعلي: الكارت يرسم `#FF9A00 → #E36D00 → #9F3F00` في الفاتح و`#78551E → #503912` في الداكن، مطابقًا لـ`AppStatusColors`. صف `old-debt-c_55` بلا تدرج (`oldDebtHasGradient: false`). رأس الدفتر يعرض التسمية والرصيد بلون النص العادي.
- الدليل: `lib/features/accounts/account_list_screen.dart` في `_AccountCard`؛ `lib/features/home/home_dashboard.dart` في `_DebtRow`؛ `lib/features/accounts/ledger_screen.dart` في `_Header`. الخريطة في `ageVisual` داخل `lib/ui/presentation.dart`.
- اللقطات: [كارت العملاء الفاتح](../../test/goldens/phase4/customers__light__360x640__admin.png)، [الداكن](../../test/goldens/phase4/customers__dark__360x640__admin.png)، [الرئيسية](../../test/goldens/phase4/home__light__360x640__admin.png).

#### P4-003 — الإعدادات الإدارية نص ثابت، ومفاتيح العملة لاتينية

- الشاشة: `/settings`.
- الدور: `admin` فقط. الأدوار الأخرى تُعاد إلى الرئيسية، وهذا ناجح.
- السمة والمقاس: السمتان والمقاسات الثلاثة.
- الخطوات: الدخول بـ`admin.demo` ثم فتح الإعدادات.
- المتوقع: شاشة إدارية ببيانات، أو إخفاء البلاطة إن لم تُعتمد في الجوال. إجماليات الصفحة بوحدة عربية واحدة.
- الفعلي: «الموظفون والإداريون» و«سجل التدقيق» و«مركز التشغيل» تعرض `AppStrings.unavailable`: «لا تتوفر بيانات من الخادم لهذه الشاشة في تطبيق الجوال.» سجل الأستاذ يُظهر المفتاح الخام ثم الرمز: `LYD` مع `0 د.ل` و`EGP` مع `0 ج.م`. زر «تصدير PDF» ظاهر للصلاحية الكاملة على Fake فقط، وهذا مطابق للكود.
- الدليل: `lib/features/settings/settings_screen.dart` حوالي السطور 31–34 و92–95. النص في `lib/ui/strings.dart` (`unavailable`). هذا بند المرحلة 5 في تحليل المدير، ويُبقى غير مانع لأن الغلاف والصلاحية والسمة يعملون.
- اللقطة: [الإعدادات، فاتح، 360](../../test/goldens/phase4/settings__light__360x640__admin.png).

#### P4-004 — عمران مختلفان على كارت الحساب التجريبي

- الشاشة: قوائم العملاء والشركات والأمانات (نفس كرت `FakeFixtures.accounts`).
- الأدوار: من يرى القائمة. السمتان والمقاسات الثلاثة.
- الخطوات: فتح `/customers` بحساب المدير أو الموظف.
- المتوقع: عمر واحد concept من الخادم. التطبيق لا يحسب العمر، ويعرض الحقلين كما وصلا.
- الفعلي: `ageStatusLabel` هو «مرّ عليه 3 أيام» و`debtAgeDays` هو 4 فيُرسم أيضًا «منذ 4 أيام». نشرة الرئيسية لنفس الكرت تستخدم تسمية أخرى من ملف الرئيسية: «منذ 4 أيام».
- الدليل: `packages/api_layer/lib/data/fake/fake_fixtures.dart` حوالي السطور 117–119 و248–258. العرض في `account_list_screen.dart` (`sinceDays`) و`ageVisual` الذي يفضّل تسمية الخادم. العيب في بيانات العرض لا في حساب داخل التطبيق. غير مانع.

## تفاصيل الشاشات

روابط المقاس الصغير الفاتح للمدير ما لم يُذكر غير ذلك. بقية الخلايا في الفهرس.

### تسجيل الدخول

ناجح في العربية وRTL والسمتين والهوية والمقاسات. لا فيض. زر السمة على طرف `centerEnd` (يسار الشاشة في RTL). `VIB` و«ع» هوية. ألوان المال لا تنطبق. الدور لا ينطبق قبل الدخول، واللقطة واحدة لكل السمات والمقاسات (الدور في اسم الملف `anonymous`).

- [فاتح 360](../../test/goldens/phase4/login__light__360x640__anonymous.png)
- [داكن 360](../../test/goldens/phase4/login__dark__360x640__anonymous.png)

### الرئيسية

العربية وRTL والسمتان والهوية والمقاسات ناجحة. ملخص «صافي ديون العملاء» بلون `debtText`، و«صافي الأمانات المصرية» و«الفلوس النشطة» بلون `creditText`. «الاستلامات المعتمدة اليوم» محايدة بلا لون، وهذا يطابق `tone: neutral`. نشرة الديون بلا تدرج (P4-002).

الصلاحيات ناجحة عند المقاس 800 حيث تُبنى كل مفاتيح الأقسام. على 360 و412 لا يبني `ListView` بلاطات أسفل الطية، لذلك غياب المفتاح في المجس الأول ليس غياب الزر. عند 800 للمدير تظهر الأقسام التسعة وأزرار الكتابة ما عدا التقارير (`write` للتقارير `null` حتى مع الصلاحية الكاملة) وإجراءات الإدارة الثمانية. الموظف: العملاء والاستلامات وزر كتابة الاستلامات فقط. الإداري المحدود: مثل الموظف زائد `action-collections.decide`. الضيف: «لا توجد أقسام مفعّلة لحسابك» ولا أي مفتاح قسم. شريطه السفلي «الرئيسية» و«المزيد» فقط (تُحقق بالنص على اللقطة، لا بوصف بصري عام).

- [مدير 360](../../test/goldens/phase4/home__light__360x640__admin.png)
- [مدير داكن 360](../../test/goldens/phase4/home__dark__360x640__admin.png)
- [ضيف 360](../../test/goldens/phase4/home__light__360x640__guest.png)
- [موظف 360](../../test/goldens/phase4/home__light__360x640__employee.png)

### القائمة الجانبية وقائمة الجوال

على 360 و412 يُفتح `Drawer` وحافته اليمنى تطابق عرض الشاشة (`drawerOnStart`). على 800 الشريط `NavigationRail` على اليمين ويضم الهوية وزر السمة. لا فيض. للمدير على 360 تظهر الأقسام حتى ما بعد الطية؛ «حسابي» أسفل قائمة المدير الطويلة ويُبلغ بالتمرير (`ListView`)، وليس قصًا بشريط فيض. الإعدادات ظاهرة للمدير فقط. الضيف والموظف والمحدود لا يرون «الإعدادات». ألوان المال لا تنطبق.

- [درج المدير 360](../../test/goldens/phase4/menu__light__360x640__admin.png)
- [شريط 800](../../test/goldens/phase4/menu__light__800x1280__admin.png)
- [درج الضيف 360](../../test/goldens/phase4/menu__light__360x640__guest.png)
- [درج الداكن 360](../../test/goldens/phase4/menu__dark__360x640__admin.png)

### ديون العملاء وديون الشركات

الكرت البرتقالي يطابق `warning`. الداكن يطابق تدرج التحذير الداكن والنص الفاتح. أزرار المدير: إضافة، وتوجيه (`collections.assign`)، وتثبيت، ومراجعة التصفير للعملاء فقط. الشركات بلا مراجعة تصفير. الموظف والمحدود: قراءة بلا هذه الأزرار. الضيف يُعاد للرئيسية. اسم الكرت في الشركات «عميل تجريبي» لأن ملف الحسابات التجريبي واحد لكل الأقسام؛ عنوان الشاشة «ديون الشركات» صحيح. تعارض 3 أيام و4 أيام هو P4-004.

بقية حالات العمر (`new` و`overdue` و`zero` و`credit`) غير موجودة في الكرت التجريبي. خريطتها في `ageVisual` لا تعكس الألوان: الجديد أزرق، والتحذير برتقالي، والمتأخر أحمر، والصفر رمادي، والرصيد الدائن أخضر. المنهج لهذه الحالات: فحص كود، لا لقطة.

- [عملاء فاتح](../../test/goldens/phase4/customers__light__360x640__admin.png)
- [عملاء داكن](../../test/goldens/phase4/customers__dark__360x640__admin.png)
- [شركات](../../test/goldens/phase4/companies__light__360x640__admin.png)
- [موظف، بلا كتابة](../../test/goldens/phase4/customers__light__360x640__employee.png)

### دفتر العميل ودفتر الشركة

الاتجاه RTL وسهم الرجوع `Icons.arrow_back` مع `IconData.matchTextDirection` فينعكس نحو اليمين. هذا ناجح لاتجاه الأيقونة. الخانة «ملاحظة» لأن معرف الحركة `tx_1` / `tx_2` ظاهر للمستخدم. السمة والهوية والمقاس ناجحة: الصف الثاني يكتمل بالتمرير بلا فيض. الألوان فاشلة (P4-001 وP4-002).

المدير يرى «دين» و«سداد» و«سداد كلي» و«إلغاء الحركة». الموظف والمحدود لا يرونها على دفتر العملاء. دفتر الشركات للمدير فقط؛ غير ذلك يعود للرئيسية.

- [دفتر عميل](../../test/goldens/phase4/customer-ledger__light__360x640__admin.png)
- [دفتر عميل داكن](../../test/goldens/phase4/customer-ledger__dark__412x915__admin.png)
- [دفتر شركة](../../test/goldens/phase4/company-ledger__light__360x640__admin.png)
- [دفتر موظف بلا أزرار](../../test/goldens/phase4/customer-ledger__light__360x640__employee.png)

### الأمانات الليبية والمصرية

نفس كرت التحذير والهوية. لا زر توجيه ولا مراجعة تصفير. المصرية تعرض «كم جنيه لكل دينار» والقيمة `9.5`، وزر حفظ السعر للمدير (`save-rate` موجود في الشجرة عند 412 و800). لا «سداد كلي» على قائمة الأمانات. الأدوار غير المدير تُعاد للرئيسية. تسمية العمر «مرّ عليه 3 أيام» على أمانة هي نص الخادم التجريبي نفسه (P4-004).

- [ليبية](../../test/goldens/phase4/libyan-deposits__light__360x640__admin.png)
- [مصرية 412](../../test/goldens/phase4/egyptian-deposits__light__412x915__admin.png)
- [مصرية داكنة](../../test/goldens/phase4/egyptian-deposits__dark__360x640__admin.png)

### المشتريات

يوم `#12` حالته `draft`، فتظهر إضافة البند و«ترحيل اليوم» وتعديل `pe_1` وحذفه للمدير فقط. لا فيض على 360. ألوان `dayTones` تمييز بصري لرقم اليوم (`dayToneIndex`) وليست `ageStatus` ولا دينًا مقابل سداد، لذلك الخانة ملاحظة لا فشل. يوم `finalized` ورفض الاسم الفارغ لنوع `custom` غير مرسومين؛ انظر قسم معايير التحليل.

- [فاتح 360](../../test/goldens/phase4/purchases__light__360x640__admin.png)
- [داكن 412](../../test/goldens/phase4/purchases__dark__412x915__admin.png)

### استلامات الديون

المدير: مؤشرات، وإسناد، وتسجيل، واستلام غير مربوط، واعتماد `sb_1` ورفضه، وربط `ur_1`، واستلام نقد `sb_2` (`cashStatus: pending`)، وإقفال الدفعة `b_1`. الإداري المحدود: التسجيل والاعتماد والربط بلا نقد ولا إقفال (`collections.decide` فقط). الموظف: «تسجيل استلام» و«استلام غير مربوط» و«مرتبي» بلا اعتماد ولا نقد ولا إقفال ولا مؤشرات. الضيف يُعاد للرئيسية. لا مفتاح ممنوع ظهر في الشجرة.

ألوان حالات الاستلام النصية. ألوان `unlinkedPending` / `unlinkedApproved` معرّفة في السمة. لا تدرج عمر دين هنا، فالخانة ملاحظة.

- [مدير](../../test/goldens/phase4/collections__light__360x640__admin.png)
- [إداري محدود](../../test/goldens/phase4/collections__light__360x640__limited.admin.png)
- [موظف](../../test/goldens/phase4/collections__light__360x640__employee.png)

### الخزينة

البطاقات الخمس ظاهرة: صافي الخزينة، وديون لنا، وديون علينا، والفلوس النشطة، وترحيلات المصرية مع السعر `9.5`. بطاقة النشط وحركة الدخول `#087A50` أي `cashPositive`. حركة الخروج غير موجودة في الصفحة الأولى من الدفتر التجريبي؛ الكود يلوّنها `cashNegative` (`treasury_screen.dart` حوالي 417–420). تنبيه «يلزم سعر تحويل معتمد» لا يظهر لأن السعر موجود. الزران «دخول» و«خروج» للمدير؛ على 360 يقعان تحت البطاقات ويظهر مفتاحاهما في شجرة 412 و800. غير المدير يُعاد للرئيسية.

- [فاتح 360](../../test/goldens/phase4/treasury__light__360x640__admin.png)
- [داكن 412](../../test/goldens/phase4/treasury__dark__412x915__admin.png)
- [عريض 800](../../test/goldens/phase4/treasury__light__800x1280__admin.png)

### التقارير الذكية

قراءة فقط. لا زر كتابة ولا مفتاح `write-reports` حتى للمدير. شارة `normal` بخلفية `#E7F7F1` ونص «طبيعي»، مطابقة لـ`chipNormalBg`. الشارة نفسها في الداكن لأن `AppStatusColors.dark` يعيد ألوان الشارات الفاتحة. المعنى لم ينعكس (الطبيعي يبقى أخضر). حالات `needs_review` و`urgent_review` و`rate_missing` غير موجودة في الملف التجريبي؛ ألوانها في `reportChipColors` (`lib/ui/presentation.dart`). على 360 البطاقات، وعلى 800 جدول أفقي قابل للتمرير مع عمود التاريخ مثبتًا. «تصدير PDF» للصلاحية الكاملة على Fake فقط.

- [360](../../test/goldens/phase4/reports__light__360x640__admin.png)
- [800](../../test/goldens/phase4/reports__light__800x1280__admin.png)
- [داكن](../../test/goldens/phase4/reports__dark__360x640__admin.png)

### الإعدادات الإدارية وإعدادات المستخدم

`/settings` للمدير فقط (P4-003). `/account` لكل دور داخل الجلسة بما فيه الضيف: مفتاح السمة، وتفضيلات الصوت والنطق، وتغيير كلمة المرور، والخروج، وجملة «اللغة العربية فقط.» لا أزرار مالية. ألوان المال لا تنطبق على الحساب، وتنطبق ملاحظة P4-003 على الإعدادات الإدارية.

- [إعدادات إدارية](../../test/goldens/phase4/settings__light__360x640__admin.png)
- [حساب الضيف](../../test/goldens/phase4/account__light__360x640__guest.png)
- [حساب داكن](../../test/goldens/phase4/account__dark__412x915__employee.png)

### الإشعارات

عنوان عربي، وعدد غير المقروء من الخادم، و«قراءة الكل»، ونص الإشعار العربي. متاحة للمدير والموظف والمحدود والضيف. لا أزرار أقسام مالية. الشريط السفلي للموظف يعرض أقسامه فقط.

- [موظف 360](../../test/goldens/phase4/notifications__light__360x640__employee.png)
- [ضيف](../../test/goldens/phase4/notifications__light__360x640__guest.png)
- [داكن](../../test/goldens/phase4/notifications__dark__360x640__admin.png)

## ما يقابل معايير القسم 6 (فحص كود حيث لا لقطة)

هذه ليست أعمدة الجدول أعلاه. ذُكرت لأن تحليل المدير يجعلها معايير المرحلة 4 (المشتريات والخزينة) وما جاورها في المرحلة 5.

| المعيار | النتيجة | المنهج |
|---|---|---|
| يوم `finalized` بلا إضافة أو تعديل أو حذف، وزر الترحيل في `draft` فقط لمن يملك `purchases.finalize` | ملاحظة | اللقطة على يوم `draft` فتُظهر الأزرار للمدير وتخفيها عن غيره. الشرط في `purchases_screen.dart` (`dayIsEditable` و`day.status == 'draft'`). يوم معتمد غير مرسوم. |
| النوع `custom` يرفض الاسم الفارغ أو «نوع آخر» | ملاحظة | `PurchaseItemCodes.require` في طبقة API. نموذج الإضافة لم يُفتح في اللقطات. |
| بطاقات الخزينة الخمس وتنبيه سعر التحويل | ناجح للبطاقات، ملاحظة للتنبيه | البطاقات في اللقطة. التنبيه يُرسم عند `rateMissing` أو غياب السعر (`_Egyptian` في `treasury_screen.dart`) والملف التجريبي يرسل `9.5`. |
| التقارير بلا زر كتابة وألوان الحالات | ناجح لغياب الكتابة ولشارة `normal` | بقية الحالات فحص كود كما سبق. |
| الشاشات الإدارية لم تعد تقول «لا تتوفر بيانات» | فاشل غير مانع | P4-003. البند في التحليل تابع للمرحلة 5. |
| السجل المالي للصلاحية الكاملة فقط | ناجح | المفتاح `financial-ledger` للمدير فقط، وغيابه مع إعادة التوجيه لغيره. |

صفحة المصراوية موجودة في التطبيق وليست ضمن قائمة هذه الجولة، فلم تُعامل شاشة ناقصة.

## نتيجة `tool/check.sh`

التشغيل على Flutter 3.47.7 وDart 3.13.5. السكربت `tool/check.sh` يتوقف عند أول أمر لأن `set -e`، وأول أمر هو `flutter analyze` للتطبيق.

| الخطوة | النتيجة |
|---|---|
| `flutter analyze` للتطبيق | خروج 1. تحذير واحد سابق على `main`، وليس من هذه المراجعة: `unused_import` في `test/qa_round_test.dart:4` (`package:flutter_riverpod/flutter_riverpod.dart`). الملف غير معدّل في هذا الفرع. |
| `flutter analyze test/phase4_ui_acceptance_test.dart` | بلا مشاكل. |
| `flutter test` للتطبيق | ناجح. 77 اختبارًا، ومنها مقارنة الـ366 لقطة بلا `--update-goldens`. |
| `flutter analyze` في `packages/api_layer` | ناجح. |
| `flutter test` في `packages/api_layer` | ناجح. 52 اختبارًا. |

اختبارات هذه الجولة لا تضيف تحذير تحليل ولا تكسر مجموعة الاختبارات. تعذّر إكمال `tool/check.sh` حتى نهايته بسبب التحذير السابق في `qa_round_test.dart`، ولم يُحذف ذلك الاستيراد لأن إصلاحه خارج نطاق قبول الواجهة ولم يُلمس كود الإنتاج.

## فهرس اللقطات

المسار النسبي من هذه الوثيقة: `../../test/goldens/phase4/<file>.png`. كل خلية أدناه منهجها `widget-golden` إلا إن ذُكر خطأ تنقل، ولم يُسجل خطأ تنقل.

### تسجيل الدخول (`login`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `anonymous` | `light` | `360x640` | [login__light__360x640__anonymous.png](../../test/goldens/phase4/login__light__360x640__anonymous.png) |
| `anonymous` | `light` | `412x915` | [login__light__412x915__anonymous.png](../../test/goldens/phase4/login__light__412x915__anonymous.png) |
| `anonymous` | `light` | `800x1280` | [login__light__800x1280__anonymous.png](../../test/goldens/phase4/login__light__800x1280__anonymous.png) |
| `anonymous` | `dark` | `360x640` | [login__dark__360x640__anonymous.png](../../test/goldens/phase4/login__dark__360x640__anonymous.png) |
| `anonymous` | `dark` | `412x915` | [login__dark__412x915__anonymous.png](../../test/goldens/phase4/login__dark__412x915__anonymous.png) |
| `anonymous` | `dark` | `800x1280` | [login__dark__800x1280__anonymous.png](../../test/goldens/phase4/login__dark__800x1280__anonymous.png) |

### الرئيسية (`home`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [home__light__360x640__admin.png](../../test/goldens/phase4/home__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [home__light__412x915__admin.png](../../test/goldens/phase4/home__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [home__light__800x1280__admin.png](../../test/goldens/phase4/home__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [home__dark__360x640__admin.png](../../test/goldens/phase4/home__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [home__dark__412x915__admin.png](../../test/goldens/phase4/home__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [home__dark__800x1280__admin.png](../../test/goldens/phase4/home__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [home__light__360x640__limited.admin.png](../../test/goldens/phase4/home__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [home__light__412x915__limited.admin.png](../../test/goldens/phase4/home__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [home__light__800x1280__limited.admin.png](../../test/goldens/phase4/home__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [home__dark__360x640__limited.admin.png](../../test/goldens/phase4/home__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [home__dark__412x915__limited.admin.png](../../test/goldens/phase4/home__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [home__dark__800x1280__limited.admin.png](../../test/goldens/phase4/home__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [home__light__360x640__employee.png](../../test/goldens/phase4/home__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [home__light__412x915__employee.png](../../test/goldens/phase4/home__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [home__light__800x1280__employee.png](../../test/goldens/phase4/home__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [home__dark__360x640__employee.png](../../test/goldens/phase4/home__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [home__dark__412x915__employee.png](../../test/goldens/phase4/home__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [home__dark__800x1280__employee.png](../../test/goldens/phase4/home__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [home__light__360x640__guest.png](../../test/goldens/phase4/home__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [home__light__412x915__guest.png](../../test/goldens/phase4/home__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [home__light__800x1280__guest.png](../../test/goldens/phase4/home__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [home__dark__360x640__guest.png](../../test/goldens/phase4/home__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [home__dark__412x915__guest.png](../../test/goldens/phase4/home__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [home__dark__800x1280__guest.png](../../test/goldens/phase4/home__dark__800x1280__guest.png) |

### القائمة (`menu`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [menu__light__360x640__admin.png](../../test/goldens/phase4/menu__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [menu__light__412x915__admin.png](../../test/goldens/phase4/menu__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [menu__light__800x1280__admin.png](../../test/goldens/phase4/menu__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [menu__dark__360x640__admin.png](../../test/goldens/phase4/menu__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [menu__dark__412x915__admin.png](../../test/goldens/phase4/menu__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [menu__dark__800x1280__admin.png](../../test/goldens/phase4/menu__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [menu__light__360x640__limited.admin.png](../../test/goldens/phase4/menu__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [menu__light__412x915__limited.admin.png](../../test/goldens/phase4/menu__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [menu__light__800x1280__limited.admin.png](../../test/goldens/phase4/menu__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [menu__dark__360x640__limited.admin.png](../../test/goldens/phase4/menu__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [menu__dark__412x915__limited.admin.png](../../test/goldens/phase4/menu__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [menu__dark__800x1280__limited.admin.png](../../test/goldens/phase4/menu__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [menu__light__360x640__employee.png](../../test/goldens/phase4/menu__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [menu__light__412x915__employee.png](../../test/goldens/phase4/menu__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [menu__light__800x1280__employee.png](../../test/goldens/phase4/menu__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [menu__dark__360x640__employee.png](../../test/goldens/phase4/menu__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [menu__dark__412x915__employee.png](../../test/goldens/phase4/menu__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [menu__dark__800x1280__employee.png](../../test/goldens/phase4/menu__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [menu__light__360x640__guest.png](../../test/goldens/phase4/menu__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [menu__light__412x915__guest.png](../../test/goldens/phase4/menu__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [menu__light__800x1280__guest.png](../../test/goldens/phase4/menu__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [menu__dark__360x640__guest.png](../../test/goldens/phase4/menu__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [menu__dark__412x915__guest.png](../../test/goldens/phase4/menu__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [menu__dark__800x1280__guest.png](../../test/goldens/phase4/menu__dark__800x1280__guest.png) |

### ديون العملاء (`customers`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [customers__light__360x640__admin.png](../../test/goldens/phase4/customers__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [customers__light__412x915__admin.png](../../test/goldens/phase4/customers__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [customers__light__800x1280__admin.png](../../test/goldens/phase4/customers__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [customers__dark__360x640__admin.png](../../test/goldens/phase4/customers__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [customers__dark__412x915__admin.png](../../test/goldens/phase4/customers__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [customers__dark__800x1280__admin.png](../../test/goldens/phase4/customers__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [customers__light__360x640__limited.admin.png](../../test/goldens/phase4/customers__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [customers__light__412x915__limited.admin.png](../../test/goldens/phase4/customers__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [customers__light__800x1280__limited.admin.png](../../test/goldens/phase4/customers__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [customers__dark__360x640__limited.admin.png](../../test/goldens/phase4/customers__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [customers__dark__412x915__limited.admin.png](../../test/goldens/phase4/customers__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [customers__dark__800x1280__limited.admin.png](../../test/goldens/phase4/customers__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [customers__light__360x640__employee.png](../../test/goldens/phase4/customers__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [customers__light__412x915__employee.png](../../test/goldens/phase4/customers__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [customers__light__800x1280__employee.png](../../test/goldens/phase4/customers__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [customers__dark__360x640__employee.png](../../test/goldens/phase4/customers__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [customers__dark__412x915__employee.png](../../test/goldens/phase4/customers__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [customers__dark__800x1280__employee.png](../../test/goldens/phase4/customers__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [customers__light__360x640__guest.png](../../test/goldens/phase4/customers__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [customers__light__412x915__guest.png](../../test/goldens/phase4/customers__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [customers__light__800x1280__guest.png](../../test/goldens/phase4/customers__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [customers__dark__360x640__guest.png](../../test/goldens/phase4/customers__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [customers__dark__412x915__guest.png](../../test/goldens/phase4/customers__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [customers__dark__800x1280__guest.png](../../test/goldens/phase4/customers__dark__800x1280__guest.png) |

### ديون الشركات (`companies`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [companies__light__360x640__admin.png](../../test/goldens/phase4/companies__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [companies__light__412x915__admin.png](../../test/goldens/phase4/companies__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [companies__light__800x1280__admin.png](../../test/goldens/phase4/companies__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [companies__dark__360x640__admin.png](../../test/goldens/phase4/companies__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [companies__dark__412x915__admin.png](../../test/goldens/phase4/companies__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [companies__dark__800x1280__admin.png](../../test/goldens/phase4/companies__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [companies__light__360x640__limited.admin.png](../../test/goldens/phase4/companies__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [companies__light__412x915__limited.admin.png](../../test/goldens/phase4/companies__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [companies__light__800x1280__limited.admin.png](../../test/goldens/phase4/companies__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [companies__dark__360x640__limited.admin.png](../../test/goldens/phase4/companies__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [companies__dark__412x915__limited.admin.png](../../test/goldens/phase4/companies__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [companies__dark__800x1280__limited.admin.png](../../test/goldens/phase4/companies__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [companies__light__360x640__employee.png](../../test/goldens/phase4/companies__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [companies__light__412x915__employee.png](../../test/goldens/phase4/companies__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [companies__light__800x1280__employee.png](../../test/goldens/phase4/companies__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [companies__dark__360x640__employee.png](../../test/goldens/phase4/companies__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [companies__dark__412x915__employee.png](../../test/goldens/phase4/companies__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [companies__dark__800x1280__employee.png](../../test/goldens/phase4/companies__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [companies__light__360x640__guest.png](../../test/goldens/phase4/companies__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [companies__light__412x915__guest.png](../../test/goldens/phase4/companies__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [companies__light__800x1280__guest.png](../../test/goldens/phase4/companies__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [companies__dark__360x640__guest.png](../../test/goldens/phase4/companies__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [companies__dark__412x915__guest.png](../../test/goldens/phase4/companies__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [companies__dark__800x1280__guest.png](../../test/goldens/phase4/companies__dark__800x1280__guest.png) |

### دفتر العميل (`customer-ledger`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [customer-ledger__light__360x640__admin.png](../../test/goldens/phase4/customer-ledger__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [customer-ledger__light__412x915__admin.png](../../test/goldens/phase4/customer-ledger__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [customer-ledger__light__800x1280__admin.png](../../test/goldens/phase4/customer-ledger__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [customer-ledger__dark__360x640__admin.png](../../test/goldens/phase4/customer-ledger__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [customer-ledger__dark__412x915__admin.png](../../test/goldens/phase4/customer-ledger__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [customer-ledger__dark__800x1280__admin.png](../../test/goldens/phase4/customer-ledger__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [customer-ledger__light__360x640__limited.admin.png](../../test/goldens/phase4/customer-ledger__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [customer-ledger__light__412x915__limited.admin.png](../../test/goldens/phase4/customer-ledger__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [customer-ledger__light__800x1280__limited.admin.png](../../test/goldens/phase4/customer-ledger__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [customer-ledger__dark__360x640__limited.admin.png](../../test/goldens/phase4/customer-ledger__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [customer-ledger__dark__412x915__limited.admin.png](../../test/goldens/phase4/customer-ledger__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [customer-ledger__dark__800x1280__limited.admin.png](../../test/goldens/phase4/customer-ledger__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [customer-ledger__light__360x640__employee.png](../../test/goldens/phase4/customer-ledger__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [customer-ledger__light__412x915__employee.png](../../test/goldens/phase4/customer-ledger__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [customer-ledger__light__800x1280__employee.png](../../test/goldens/phase4/customer-ledger__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [customer-ledger__dark__360x640__employee.png](../../test/goldens/phase4/customer-ledger__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [customer-ledger__dark__412x915__employee.png](../../test/goldens/phase4/customer-ledger__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [customer-ledger__dark__800x1280__employee.png](../../test/goldens/phase4/customer-ledger__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [customer-ledger__light__360x640__guest.png](../../test/goldens/phase4/customer-ledger__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [customer-ledger__light__412x915__guest.png](../../test/goldens/phase4/customer-ledger__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [customer-ledger__light__800x1280__guest.png](../../test/goldens/phase4/customer-ledger__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [customer-ledger__dark__360x640__guest.png](../../test/goldens/phase4/customer-ledger__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [customer-ledger__dark__412x915__guest.png](../../test/goldens/phase4/customer-ledger__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [customer-ledger__dark__800x1280__guest.png](../../test/goldens/phase4/customer-ledger__dark__800x1280__guest.png) |

### دفتر الشركة (`company-ledger`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [company-ledger__light__360x640__admin.png](../../test/goldens/phase4/company-ledger__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [company-ledger__light__412x915__admin.png](../../test/goldens/phase4/company-ledger__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [company-ledger__light__800x1280__admin.png](../../test/goldens/phase4/company-ledger__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [company-ledger__dark__360x640__admin.png](../../test/goldens/phase4/company-ledger__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [company-ledger__dark__412x915__admin.png](../../test/goldens/phase4/company-ledger__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [company-ledger__dark__800x1280__admin.png](../../test/goldens/phase4/company-ledger__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [company-ledger__light__360x640__limited.admin.png](../../test/goldens/phase4/company-ledger__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [company-ledger__light__412x915__limited.admin.png](../../test/goldens/phase4/company-ledger__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [company-ledger__light__800x1280__limited.admin.png](../../test/goldens/phase4/company-ledger__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [company-ledger__dark__360x640__limited.admin.png](../../test/goldens/phase4/company-ledger__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [company-ledger__dark__412x915__limited.admin.png](../../test/goldens/phase4/company-ledger__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [company-ledger__dark__800x1280__limited.admin.png](../../test/goldens/phase4/company-ledger__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [company-ledger__light__360x640__employee.png](../../test/goldens/phase4/company-ledger__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [company-ledger__light__412x915__employee.png](../../test/goldens/phase4/company-ledger__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [company-ledger__light__800x1280__employee.png](../../test/goldens/phase4/company-ledger__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [company-ledger__dark__360x640__employee.png](../../test/goldens/phase4/company-ledger__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [company-ledger__dark__412x915__employee.png](../../test/goldens/phase4/company-ledger__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [company-ledger__dark__800x1280__employee.png](../../test/goldens/phase4/company-ledger__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [company-ledger__light__360x640__guest.png](../../test/goldens/phase4/company-ledger__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [company-ledger__light__412x915__guest.png](../../test/goldens/phase4/company-ledger__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [company-ledger__light__800x1280__guest.png](../../test/goldens/phase4/company-ledger__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [company-ledger__dark__360x640__guest.png](../../test/goldens/phase4/company-ledger__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [company-ledger__dark__412x915__guest.png](../../test/goldens/phase4/company-ledger__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [company-ledger__dark__800x1280__guest.png](../../test/goldens/phase4/company-ledger__dark__800x1280__guest.png) |

### الأمانات الليبية (`libyan-deposits`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [libyan-deposits__light__360x640__admin.png](../../test/goldens/phase4/libyan-deposits__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [libyan-deposits__light__412x915__admin.png](../../test/goldens/phase4/libyan-deposits__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [libyan-deposits__light__800x1280__admin.png](../../test/goldens/phase4/libyan-deposits__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [libyan-deposits__dark__360x640__admin.png](../../test/goldens/phase4/libyan-deposits__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [libyan-deposits__dark__412x915__admin.png](../../test/goldens/phase4/libyan-deposits__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [libyan-deposits__dark__800x1280__admin.png](../../test/goldens/phase4/libyan-deposits__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [libyan-deposits__light__360x640__limited.admin.png](../../test/goldens/phase4/libyan-deposits__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [libyan-deposits__light__412x915__limited.admin.png](../../test/goldens/phase4/libyan-deposits__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [libyan-deposits__light__800x1280__limited.admin.png](../../test/goldens/phase4/libyan-deposits__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [libyan-deposits__dark__360x640__limited.admin.png](../../test/goldens/phase4/libyan-deposits__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [libyan-deposits__dark__412x915__limited.admin.png](../../test/goldens/phase4/libyan-deposits__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [libyan-deposits__dark__800x1280__limited.admin.png](../../test/goldens/phase4/libyan-deposits__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [libyan-deposits__light__360x640__employee.png](../../test/goldens/phase4/libyan-deposits__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [libyan-deposits__light__412x915__employee.png](../../test/goldens/phase4/libyan-deposits__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [libyan-deposits__light__800x1280__employee.png](../../test/goldens/phase4/libyan-deposits__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [libyan-deposits__dark__360x640__employee.png](../../test/goldens/phase4/libyan-deposits__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [libyan-deposits__dark__412x915__employee.png](../../test/goldens/phase4/libyan-deposits__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [libyan-deposits__dark__800x1280__employee.png](../../test/goldens/phase4/libyan-deposits__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [libyan-deposits__light__360x640__guest.png](../../test/goldens/phase4/libyan-deposits__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [libyan-deposits__light__412x915__guest.png](../../test/goldens/phase4/libyan-deposits__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [libyan-deposits__light__800x1280__guest.png](../../test/goldens/phase4/libyan-deposits__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [libyan-deposits__dark__360x640__guest.png](../../test/goldens/phase4/libyan-deposits__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [libyan-deposits__dark__412x915__guest.png](../../test/goldens/phase4/libyan-deposits__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [libyan-deposits__dark__800x1280__guest.png](../../test/goldens/phase4/libyan-deposits__dark__800x1280__guest.png) |

### الأمانات المصرية (`egyptian-deposits`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [egyptian-deposits__light__360x640__admin.png](../../test/goldens/phase4/egyptian-deposits__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [egyptian-deposits__light__412x915__admin.png](../../test/goldens/phase4/egyptian-deposits__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [egyptian-deposits__light__800x1280__admin.png](../../test/goldens/phase4/egyptian-deposits__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [egyptian-deposits__dark__360x640__admin.png](../../test/goldens/phase4/egyptian-deposits__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [egyptian-deposits__dark__412x915__admin.png](../../test/goldens/phase4/egyptian-deposits__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [egyptian-deposits__dark__800x1280__admin.png](../../test/goldens/phase4/egyptian-deposits__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [egyptian-deposits__light__360x640__limited.admin.png](../../test/goldens/phase4/egyptian-deposits__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [egyptian-deposits__light__412x915__limited.admin.png](../../test/goldens/phase4/egyptian-deposits__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [egyptian-deposits__light__800x1280__limited.admin.png](../../test/goldens/phase4/egyptian-deposits__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [egyptian-deposits__dark__360x640__limited.admin.png](../../test/goldens/phase4/egyptian-deposits__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [egyptian-deposits__dark__412x915__limited.admin.png](../../test/goldens/phase4/egyptian-deposits__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [egyptian-deposits__dark__800x1280__limited.admin.png](../../test/goldens/phase4/egyptian-deposits__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [egyptian-deposits__light__360x640__employee.png](../../test/goldens/phase4/egyptian-deposits__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [egyptian-deposits__light__412x915__employee.png](../../test/goldens/phase4/egyptian-deposits__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [egyptian-deposits__light__800x1280__employee.png](../../test/goldens/phase4/egyptian-deposits__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [egyptian-deposits__dark__360x640__employee.png](../../test/goldens/phase4/egyptian-deposits__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [egyptian-deposits__dark__412x915__employee.png](../../test/goldens/phase4/egyptian-deposits__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [egyptian-deposits__dark__800x1280__employee.png](../../test/goldens/phase4/egyptian-deposits__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [egyptian-deposits__light__360x640__guest.png](../../test/goldens/phase4/egyptian-deposits__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [egyptian-deposits__light__412x915__guest.png](../../test/goldens/phase4/egyptian-deposits__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [egyptian-deposits__light__800x1280__guest.png](../../test/goldens/phase4/egyptian-deposits__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [egyptian-deposits__dark__360x640__guest.png](../../test/goldens/phase4/egyptian-deposits__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [egyptian-deposits__dark__412x915__guest.png](../../test/goldens/phase4/egyptian-deposits__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [egyptian-deposits__dark__800x1280__guest.png](../../test/goldens/phase4/egyptian-deposits__dark__800x1280__guest.png) |

### المشتريات (`purchases`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [purchases__light__360x640__admin.png](../../test/goldens/phase4/purchases__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [purchases__light__412x915__admin.png](../../test/goldens/phase4/purchases__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [purchases__light__800x1280__admin.png](../../test/goldens/phase4/purchases__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [purchases__dark__360x640__admin.png](../../test/goldens/phase4/purchases__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [purchases__dark__412x915__admin.png](../../test/goldens/phase4/purchases__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [purchases__dark__800x1280__admin.png](../../test/goldens/phase4/purchases__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [purchases__light__360x640__limited.admin.png](../../test/goldens/phase4/purchases__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [purchases__light__412x915__limited.admin.png](../../test/goldens/phase4/purchases__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [purchases__light__800x1280__limited.admin.png](../../test/goldens/phase4/purchases__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [purchases__dark__360x640__limited.admin.png](../../test/goldens/phase4/purchases__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [purchases__dark__412x915__limited.admin.png](../../test/goldens/phase4/purchases__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [purchases__dark__800x1280__limited.admin.png](../../test/goldens/phase4/purchases__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [purchases__light__360x640__employee.png](../../test/goldens/phase4/purchases__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [purchases__light__412x915__employee.png](../../test/goldens/phase4/purchases__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [purchases__light__800x1280__employee.png](../../test/goldens/phase4/purchases__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [purchases__dark__360x640__employee.png](../../test/goldens/phase4/purchases__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [purchases__dark__412x915__employee.png](../../test/goldens/phase4/purchases__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [purchases__dark__800x1280__employee.png](../../test/goldens/phase4/purchases__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [purchases__light__360x640__guest.png](../../test/goldens/phase4/purchases__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [purchases__light__412x915__guest.png](../../test/goldens/phase4/purchases__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [purchases__light__800x1280__guest.png](../../test/goldens/phase4/purchases__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [purchases__dark__360x640__guest.png](../../test/goldens/phase4/purchases__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [purchases__dark__412x915__guest.png](../../test/goldens/phase4/purchases__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [purchases__dark__800x1280__guest.png](../../test/goldens/phase4/purchases__dark__800x1280__guest.png) |

### استلامات الديون (`collections`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [collections__light__360x640__admin.png](../../test/goldens/phase4/collections__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [collections__light__412x915__admin.png](../../test/goldens/phase4/collections__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [collections__light__800x1280__admin.png](../../test/goldens/phase4/collections__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [collections__dark__360x640__admin.png](../../test/goldens/phase4/collections__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [collections__dark__412x915__admin.png](../../test/goldens/phase4/collections__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [collections__dark__800x1280__admin.png](../../test/goldens/phase4/collections__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [collections__light__360x640__limited.admin.png](../../test/goldens/phase4/collections__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [collections__light__412x915__limited.admin.png](../../test/goldens/phase4/collections__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [collections__light__800x1280__limited.admin.png](../../test/goldens/phase4/collections__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [collections__dark__360x640__limited.admin.png](../../test/goldens/phase4/collections__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [collections__dark__412x915__limited.admin.png](../../test/goldens/phase4/collections__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [collections__dark__800x1280__limited.admin.png](../../test/goldens/phase4/collections__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [collections__light__360x640__employee.png](../../test/goldens/phase4/collections__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [collections__light__412x915__employee.png](../../test/goldens/phase4/collections__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [collections__light__800x1280__employee.png](../../test/goldens/phase4/collections__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [collections__dark__360x640__employee.png](../../test/goldens/phase4/collections__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [collections__dark__412x915__employee.png](../../test/goldens/phase4/collections__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [collections__dark__800x1280__employee.png](../../test/goldens/phase4/collections__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [collections__light__360x640__guest.png](../../test/goldens/phase4/collections__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [collections__light__412x915__guest.png](../../test/goldens/phase4/collections__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [collections__light__800x1280__guest.png](../../test/goldens/phase4/collections__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [collections__dark__360x640__guest.png](../../test/goldens/phase4/collections__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [collections__dark__412x915__guest.png](../../test/goldens/phase4/collections__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [collections__dark__800x1280__guest.png](../../test/goldens/phase4/collections__dark__800x1280__guest.png) |

### الخزينة (`treasury`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [treasury__light__360x640__admin.png](../../test/goldens/phase4/treasury__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [treasury__light__412x915__admin.png](../../test/goldens/phase4/treasury__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [treasury__light__800x1280__admin.png](../../test/goldens/phase4/treasury__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [treasury__dark__360x640__admin.png](../../test/goldens/phase4/treasury__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [treasury__dark__412x915__admin.png](../../test/goldens/phase4/treasury__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [treasury__dark__800x1280__admin.png](../../test/goldens/phase4/treasury__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [treasury__light__360x640__limited.admin.png](../../test/goldens/phase4/treasury__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [treasury__light__412x915__limited.admin.png](../../test/goldens/phase4/treasury__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [treasury__light__800x1280__limited.admin.png](../../test/goldens/phase4/treasury__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [treasury__dark__360x640__limited.admin.png](../../test/goldens/phase4/treasury__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [treasury__dark__412x915__limited.admin.png](../../test/goldens/phase4/treasury__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [treasury__dark__800x1280__limited.admin.png](../../test/goldens/phase4/treasury__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [treasury__light__360x640__employee.png](../../test/goldens/phase4/treasury__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [treasury__light__412x915__employee.png](../../test/goldens/phase4/treasury__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [treasury__light__800x1280__employee.png](../../test/goldens/phase4/treasury__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [treasury__dark__360x640__employee.png](../../test/goldens/phase4/treasury__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [treasury__dark__412x915__employee.png](../../test/goldens/phase4/treasury__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [treasury__dark__800x1280__employee.png](../../test/goldens/phase4/treasury__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [treasury__light__360x640__guest.png](../../test/goldens/phase4/treasury__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [treasury__light__412x915__guest.png](../../test/goldens/phase4/treasury__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [treasury__light__800x1280__guest.png](../../test/goldens/phase4/treasury__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [treasury__dark__360x640__guest.png](../../test/goldens/phase4/treasury__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [treasury__dark__412x915__guest.png](../../test/goldens/phase4/treasury__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [treasury__dark__800x1280__guest.png](../../test/goldens/phase4/treasury__dark__800x1280__guest.png) |

### التقارير الذكية (`reports`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [reports__light__360x640__admin.png](../../test/goldens/phase4/reports__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [reports__light__412x915__admin.png](../../test/goldens/phase4/reports__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [reports__light__800x1280__admin.png](../../test/goldens/phase4/reports__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [reports__dark__360x640__admin.png](../../test/goldens/phase4/reports__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [reports__dark__412x915__admin.png](../../test/goldens/phase4/reports__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [reports__dark__800x1280__admin.png](../../test/goldens/phase4/reports__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [reports__light__360x640__limited.admin.png](../../test/goldens/phase4/reports__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [reports__light__412x915__limited.admin.png](../../test/goldens/phase4/reports__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [reports__light__800x1280__limited.admin.png](../../test/goldens/phase4/reports__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [reports__dark__360x640__limited.admin.png](../../test/goldens/phase4/reports__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [reports__dark__412x915__limited.admin.png](../../test/goldens/phase4/reports__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [reports__dark__800x1280__limited.admin.png](../../test/goldens/phase4/reports__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [reports__light__360x640__employee.png](../../test/goldens/phase4/reports__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [reports__light__412x915__employee.png](../../test/goldens/phase4/reports__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [reports__light__800x1280__employee.png](../../test/goldens/phase4/reports__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [reports__dark__360x640__employee.png](../../test/goldens/phase4/reports__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [reports__dark__412x915__employee.png](../../test/goldens/phase4/reports__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [reports__dark__800x1280__employee.png](../../test/goldens/phase4/reports__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [reports__light__360x640__guest.png](../../test/goldens/phase4/reports__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [reports__light__412x915__guest.png](../../test/goldens/phase4/reports__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [reports__light__800x1280__guest.png](../../test/goldens/phase4/reports__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [reports__dark__360x640__guest.png](../../test/goldens/phase4/reports__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [reports__dark__412x915__guest.png](../../test/goldens/phase4/reports__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [reports__dark__800x1280__guest.png](../../test/goldens/phase4/reports__dark__800x1280__guest.png) |

### الإعدادات الإدارية (`settings`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [settings__light__360x640__admin.png](../../test/goldens/phase4/settings__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [settings__light__412x915__admin.png](../../test/goldens/phase4/settings__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [settings__light__800x1280__admin.png](../../test/goldens/phase4/settings__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [settings__dark__360x640__admin.png](../../test/goldens/phase4/settings__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [settings__dark__412x915__admin.png](../../test/goldens/phase4/settings__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [settings__dark__800x1280__admin.png](../../test/goldens/phase4/settings__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [settings__light__360x640__limited.admin.png](../../test/goldens/phase4/settings__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [settings__light__412x915__limited.admin.png](../../test/goldens/phase4/settings__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [settings__light__800x1280__limited.admin.png](../../test/goldens/phase4/settings__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [settings__dark__360x640__limited.admin.png](../../test/goldens/phase4/settings__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [settings__dark__412x915__limited.admin.png](../../test/goldens/phase4/settings__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [settings__dark__800x1280__limited.admin.png](../../test/goldens/phase4/settings__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [settings__light__360x640__employee.png](../../test/goldens/phase4/settings__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [settings__light__412x915__employee.png](../../test/goldens/phase4/settings__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [settings__light__800x1280__employee.png](../../test/goldens/phase4/settings__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [settings__dark__360x640__employee.png](../../test/goldens/phase4/settings__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [settings__dark__412x915__employee.png](../../test/goldens/phase4/settings__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [settings__dark__800x1280__employee.png](../../test/goldens/phase4/settings__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [settings__light__360x640__guest.png](../../test/goldens/phase4/settings__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [settings__light__412x915__guest.png](../../test/goldens/phase4/settings__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [settings__light__800x1280__guest.png](../../test/goldens/phase4/settings__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [settings__dark__360x640__guest.png](../../test/goldens/phase4/settings__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [settings__dark__412x915__guest.png](../../test/goldens/phase4/settings__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [settings__dark__800x1280__guest.png](../../test/goldens/phase4/settings__dark__800x1280__guest.png) |

### إعدادات المستخدم (`account`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [account__light__360x640__admin.png](../../test/goldens/phase4/account__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [account__light__412x915__admin.png](../../test/goldens/phase4/account__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [account__light__800x1280__admin.png](../../test/goldens/phase4/account__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [account__dark__360x640__admin.png](../../test/goldens/phase4/account__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [account__dark__412x915__admin.png](../../test/goldens/phase4/account__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [account__dark__800x1280__admin.png](../../test/goldens/phase4/account__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [account__light__360x640__limited.admin.png](../../test/goldens/phase4/account__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [account__light__412x915__limited.admin.png](../../test/goldens/phase4/account__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [account__light__800x1280__limited.admin.png](../../test/goldens/phase4/account__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [account__dark__360x640__limited.admin.png](../../test/goldens/phase4/account__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [account__dark__412x915__limited.admin.png](../../test/goldens/phase4/account__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [account__dark__800x1280__limited.admin.png](../../test/goldens/phase4/account__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [account__light__360x640__employee.png](../../test/goldens/phase4/account__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [account__light__412x915__employee.png](../../test/goldens/phase4/account__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [account__light__800x1280__employee.png](../../test/goldens/phase4/account__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [account__dark__360x640__employee.png](../../test/goldens/phase4/account__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [account__dark__412x915__employee.png](../../test/goldens/phase4/account__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [account__dark__800x1280__employee.png](../../test/goldens/phase4/account__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [account__light__360x640__guest.png](../../test/goldens/phase4/account__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [account__light__412x915__guest.png](../../test/goldens/phase4/account__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [account__light__800x1280__guest.png](../../test/goldens/phase4/account__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [account__dark__360x640__guest.png](../../test/goldens/phase4/account__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [account__dark__412x915__guest.png](../../test/goldens/phase4/account__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [account__dark__800x1280__guest.png](../../test/goldens/phase4/account__dark__800x1280__guest.png) |

### الإشعارات (`notifications`)

| الدور | السمة | المقاس | اللقطة |
|---|---|---|---|
| `admin` | `light` | `360x640` | [notifications__light__360x640__admin.png](../../test/goldens/phase4/notifications__light__360x640__admin.png) |
| `admin` | `light` | `412x915` | [notifications__light__412x915__admin.png](../../test/goldens/phase4/notifications__light__412x915__admin.png) |
| `admin` | `light` | `800x1280` | [notifications__light__800x1280__admin.png](../../test/goldens/phase4/notifications__light__800x1280__admin.png) |
| `admin` | `dark` | `360x640` | [notifications__dark__360x640__admin.png](../../test/goldens/phase4/notifications__dark__360x640__admin.png) |
| `admin` | `dark` | `412x915` | [notifications__dark__412x915__admin.png](../../test/goldens/phase4/notifications__dark__412x915__admin.png) |
| `admin` | `dark` | `800x1280` | [notifications__dark__800x1280__admin.png](../../test/goldens/phase4/notifications__dark__800x1280__admin.png) |
| `limited.admin` | `light` | `360x640` | [notifications__light__360x640__limited.admin.png](../../test/goldens/phase4/notifications__light__360x640__limited.admin.png) |
| `limited.admin` | `light` | `412x915` | [notifications__light__412x915__limited.admin.png](../../test/goldens/phase4/notifications__light__412x915__limited.admin.png) |
| `limited.admin` | `light` | `800x1280` | [notifications__light__800x1280__limited.admin.png](../../test/goldens/phase4/notifications__light__800x1280__limited.admin.png) |
| `limited.admin` | `dark` | `360x640` | [notifications__dark__360x640__limited.admin.png](../../test/goldens/phase4/notifications__dark__360x640__limited.admin.png) |
| `limited.admin` | `dark` | `412x915` | [notifications__dark__412x915__limited.admin.png](../../test/goldens/phase4/notifications__dark__412x915__limited.admin.png) |
| `limited.admin` | `dark` | `800x1280` | [notifications__dark__800x1280__limited.admin.png](../../test/goldens/phase4/notifications__dark__800x1280__limited.admin.png) |
| `employee` | `light` | `360x640` | [notifications__light__360x640__employee.png](../../test/goldens/phase4/notifications__light__360x640__employee.png) |
| `employee` | `light` | `412x915` | [notifications__light__412x915__employee.png](../../test/goldens/phase4/notifications__light__412x915__employee.png) |
| `employee` | `light` | `800x1280` | [notifications__light__800x1280__employee.png](../../test/goldens/phase4/notifications__light__800x1280__employee.png) |
| `employee` | `dark` | `360x640` | [notifications__dark__360x640__employee.png](../../test/goldens/phase4/notifications__dark__360x640__employee.png) |
| `employee` | `dark` | `412x915` | [notifications__dark__412x915__employee.png](../../test/goldens/phase4/notifications__dark__412x915__employee.png) |
| `employee` | `dark` | `800x1280` | [notifications__dark__800x1280__employee.png](../../test/goldens/phase4/notifications__dark__800x1280__employee.png) |
| `guest` | `light` | `360x640` | [notifications__light__360x640__guest.png](../../test/goldens/phase4/notifications__light__360x640__guest.png) |
| `guest` | `light` | `412x915` | [notifications__light__412x915__guest.png](../../test/goldens/phase4/notifications__light__412x915__guest.png) |
| `guest` | `light` | `800x1280` | [notifications__light__800x1280__guest.png](../../test/goldens/phase4/notifications__light__800x1280__guest.png) |
| `guest` | `dark` | `360x640` | [notifications__dark__360x640__guest.png](../../test/goldens/phase4/notifications__dark__360x640__guest.png) |
| `guest` | `dark` | `412x915` | [notifications__dark__412x915__guest.png](../../test/goldens/phase4/notifications__dark__412x915__guest.png) |
| `guest` | `dark` | `800x1280` | [notifications__dark__800x1280__guest.png](../../test/goldens/phase4/notifications__dark__800x1280__guest.png) |
