# المرحلة 8 — مطابقة الأرقام المالية (جرد، الخطوة أ)

التاريخ 2026-10-22. الشجرة `main` `54884d7e103102b1b9c3bb5bbedff1a2006666ff`. لا اختبارات في هذه الخطوة. لا توقيع. لم يُمس `lib/` ولا مصدر `packages/` ولا `tool/` ولا `android/`.

**قاعدة علي:** التطبيق غير مقبول إذا اختلف أي رقم معروض عن الموقع. التسامح = فرق صفر. عمود الموقع فارغ في هذه الخطوة لأن لا قيمة موقع مُدخلة، ولا تُخترع قيمة. كل رقم تطبيق أدناه من `FakeApiClient` وموسوم `Fake`. النتيجة لكل صف: **لم تُتحقّق**.

## الجدول

| الحالة | قيمة الموقع | قيمة التطبيق | النتيجة |
|---|---|---|---|
| 1 إجمالي ديون العملاء | | `10,635 د.ل` (Fake، `summary.totalDebt` = 10635). الصافي على الشاشة نفسها `10,635 د.ل` (Fake، `netBalance` = 10635) | لم تُتحقّق |
| 2 إجمالي ديون الشركات | | `1,035 د.ل` (Fake، `summary.totalDebt` = 1035). الصافي نفس العدد | لم تُتحقّق |
| 3 رصيد عميل | | بطاقة العينة `c_55` / «عميل تجريبي»: `320 د.ل` (Fake، `balanceUnits` = 320). ليست بطاقة موقع | لم تُتحقّق |
| 4 سداد جزئي (الرصيد بعده) | | على `c_55` بعد إدخال `100`: الرأس `220 د.ل` (Fake). 100 مبلغ سيناريو الاختبار لا مبلغ موقع. انظر DEF-028 | لم تُتحقّق |
| 5 سداد كلي (الرصيد بعده = 0) | | على `c_55` بعد «سداد كلي»: الرأس `0 د.ل` (Fake، `balanceUnits` = 0) | لم تُتحقّق |
| 6 الأمانات الليبية | | `695 د.ل` (Fake). الصافي والإجمالي كلاهما 695 | لم تُتحقّق |
| 7 الأمانات المصرية | | `23,750 ج.م` (Fake). الصافي والإجمالي كلاهما 23750 | لم تُتحقّق |
| 8 المشتريات | | دفتر «البيان»، المتبقي الدائم `2,553 د.ل` (Fake، `lifetimeTotals.remainingUnits` = 2553). حقول أخرى في التفاصيل | لم تُتحقّق |
| 9 الخزينة | | صافي الخزينة الشامل `51,000 د.ل` (Fake، `totals.netUnits` = 51000). بقية البطاقات في التفاصيل | لم تُتحقّق |
| 10 استلامات الديون | | ثلاثة مبالغ على الشاشة، كلها Fake: إجمالي المعتمد `0 د.ل`، إجمالي اليوم `100 د.ل`، النقد غير المسلَّم `250 د.ل` | لم تُتحقّق |

## سياسة التقريب والعملة

- المال على السلك عدد صحيح في حقول `*Units`، أو `netBalance` / `totalDebt` بلا لاحقة `Units`. `unitsOrNull` يقبل `int` فقط. النص أو الكسر يرمي `InvalidServerResponseException` ولا يُقصّ (`packages/api_layer/lib/data/models/common.dart:31`).
- العرض الوحيد هو `MoneyFormatter` (`packages/api_layer/lib/core/money/money_formatter.dart:32`). الافتراض `moneyUnitScale` = 0 (`packages/api_layer/lib/core/config/api_config.dart:56` و`:97`). عند الصفر تُدرج فواصل الآلاف `,` ثم مسافة ثم الرمز. لا قسمة ولا `round` ولا `intl` `NumberFormat`.
- `LYD` → `د.ل`. `EGP` → `ج.م`. لا تحويل بين العملتين في التطبيق. المصري في الخزينة المعروض بالدينار هو `egyptianConvertedUnits` كما أرسله الخادم.
- `parseUnits` يرفض العلامة العشرية (`lib/ui/widgets/common.dart:435`). لا يُقرّب إدخالاً إلى أقرب عدد.
- لم يُرصد مسار عرض يغيّر العدد الصحيح قبل رسمه. لا عيب تقريب. `MONEY_UNIT_SCALE` ما زال موسومًا 🔶 في `api_config.dart:73`. إن ثبت أن الموقع يرسم كسورًا، يُعاد فتح السؤال. لا تُخترع قيمة موقع هنا.

## 1 — إجمالي ديون العملاء

- **الشاشة:** `AccountListScreen` على `/customers`، المفتاح `screen-customers`. الشريط `_SummaryStrip` يرسم «إجمالي الديون» من `summary.totalDebtUnits` و«صافي إجمالي الديون» من `summary.netBalanceUnits` (`lib/features/accounts/account_list_screen.dart:108` و`:604`).
- **المزوّد:** `accountsProvider(AccountSection.customers)` (`lib/state/section_providers.dart:169`).
- **المسار:** `GET /api/customers`. الحقل `data.summary.totalDebt` (والصافي `data.summary.netBalance`). التحليل في `AccountsSummaryDto.fromJson` (`packages/api_layer/lib/data/models/account_models.dart:165`).
- **المصدر:** حقل خادم كما هو. القائمة لا تجمع أرصدة الكروت (`account_models.dart:149`).
- **التنسيق:** `MoneyFormatter.formatOrDash(..., Currency.lyd)` → `10,635 د.ل`.
- **Fake:** `FakeFixtures._customers` يضع `totalDebt: 10635` و`netBalance: 10635` كقيم ثابتة (`packages/api_layer/lib/data/fake/fake_fixtures.dart:256`).
- **الرئيسية:** `GET /api/home` يعرض بطاقة `customers.netBalance` بعنوان «صافي ديون العملاء» من `valueUnits`، وليس بطاقة `totalDebt` (`fake_fixtures.dart:660`). بعد فشل `/api/home` يبني `home_fallback.dart:48` البطاقتين من نفس ملخص القسم بلا جمع.

## 2 — إجمالي ديون الشركات

- **الشاشة:** نفس `AccountListScreen` على `/companies`، المفتاح `screen-companies`، نفس الشريط.
- **المزوّد:** `accountsProvider(AccountSection.companies)`.
- **المسار:** `GET /api/companies`. الحقل `data.summary.totalDebt`. العملة ثابتة `LYD` (`account_models.dart:7`).
- **المصدر:** حقل خادم. لا جمع محلي.
- **التنسيق:** `1,035 د.ل`.
- **Fake:** `totalDebt: 1035` و`netBalance: 1035` (`fake_fixtures.dart:344`). حمولة `GET /api/home` لا تضم بطاقة شركات.

## 3 — رصيد عميل

- **الشاشة:** صف الكارت في القائمة (`account_list_screen.dart:757`) ورأس الدفتر `ledger-header-balance` (`lib/features/accounts/ledger_screen.dart:548`) على `/customers/c_55`، المفتاح `screen-ledger-customers`.
- **المزوّد:** القائمة من `accountsProvider`. الرأس من `accountCardProvider` (`section_providers.dart:191`) عبر `GET /api/customers/{id}`.
- **المسار والحقل:** `balanceUnits` على عنصر القائمة وعلى جسم الكارت (`account_models.dart:79`).
- **المصدر:** الحقل كما هو. المقارنة `units > remaining` في حوار السداد تقرأ الرصيد المخزَّن ولا تحسب رصيدًا جديدًا (`ledger_screen.dart:417`).
- **التنسيق:** `320 د.ل` لـ `c_55`.
- **Fake:** `balanceUnits: 320` على `c_55` في العملاء (`fake_fixtures.dart:177`).

## 4 — سداد جزئي (الرصيد بعده)

- **الشاشة:** بعد حفظ «سداد» يُبطَل `accountCardProvider` و`ledgerProvider` و`accountsProvider` (`ledger_screen.dart:226`). الرأس يعرض `balanceUnits` الجديد. سطر الدفتر يعرض `balanceAfterUnits` إن وُجد (`ledger_screen.dart:1096`).
- **المزوّد:** `accountCardProvider` و`ledgerProvider`.
- **المسار:** `POST /api/customers/{id}/transactions` بجسم `paymentMode: partial` و`inputValue`. ثم `GET /api/customers/{id}` الحقل `balanceUnits`، و`GET /api/customers/{id}/ledger` الحقل `balanceAfterUnits`.
- **المصدر على التطبيق:** إعادة جلب. الواجهة لا تطرح المبلغ من الرصيد (`lib/ui/strings.dart:93`).
- **Fake:** `_applyMovement` يخزّن `previous - entered` في `balanceUnits` و`balanceAfterUnits` (`packages/api_layer/lib/data/fake/fake_api_client.dart:1559`). هذا حساب محلي. DEF-028. سيناريو الاختبار `P7-10` على `c_55` بإدخال `100` يرسم الرأس `220 د.ل` (`test/phase7_payments_test.dart:58`). 220 ليست قيمة موقع.
- **التنسيق:** `220 د.ل` في ذلك السيناريو فقط.

## 5 — سداد كلي (الرصيد بعده = 0)

- **الشاشة:** زر `full-payment` على دفتر العملاء والشركات. الزر غائب عن الأمانات الليبية والمصرية (`ledger_screen.dart:98`).
- **المزوّد:** بعد النجاح تُبطَل المزوّدات نفسها في `_full` (`ledger_screen.dart:255`). الرأس من `accountCardProvider`.
- **المسار:** `POST /api/customers/{id}/transactions` عبر `AccountTransactionRequest.fullPayment()`. ثم `GET` الحقل `balanceUnits`.
- **المصدر:** إعادة جلب. الزر لا يرسل مبلغًا ولا يحسب صفرًا.
- **Fake:** `_applyFullPayment` يخزّن `balanceUnits: 0` بلا طرح (`fake_api_client.dart:1525`). على `c_55` بعد الزر يظهر `0 د.ل` (`test/phase7_payments_test.dart:63`).
- **التنسيق:** `0 د.ل`.

## 6 — الأمانات الليبية

- **الشاشة:** `AccountListScreen` على `/libyan-deposits`، المفتاح `screen-libyan-deposits`. الشريط يعرض الصافي والإجمالي.
- **المزوّد:** `accountsProvider(AccountSection.libyanDeposits)`.
- **المسار:** `GET /api/libyan-deposits`. الحقلان `summary.netBalance` و`summary.totalDebt`. العملة `LYD`.
- **المصدر:** حقل خادم. لا جمع.
- **التنسيق:** `695 د.ل` للحقلين.
- **Fake:** كلاهما 695 (`fake_fixtures.dart:432`). غير موجودين في بطاقات `GET /api/home`.

## 7 — الأمانات المصرية

- **الشاشة:** `/egyptian-deposits`، المفتاح `screen-egyptian-deposits`. وبطاقة الرئيسية `summary-egyptianDeposits.netBalance` بعنوان «صافي الأمانات المصرية» عندما ينجح `GET /api/home`.
- **المزوّد:** `accountsProvider(AccountSection.egyptianDeposits)`. بطاقة الرئيسية من `homeDashboardProvider` (`lib/state/session_providers.dart:62`).
- **المسار:** `GET /api/egyptian-deposits` الحقل `summary.netBalance` / `summary.totalDebt`. على الرئيسية `GET /api/home` ثم `summaries[].valueUnits` للمفتاح `egyptianDeposits.netBalance` والعملة `EGP`.
- **المصدر:** حقل خادم. لا تحويل في التطبيق.
- **التنسيق:** `23,750 ج.م`.
- **Fake:** 23750 للحقلين (`fake_fixtures.dart:520`) و`valueUnits` نفسها على بطاقة الرئيسية (`fake_fixtures.dart:679`). رصيد `c_55` في هذا القسم 15000 ج.م، وهو كارت آخر غير رصيد العملاء 320 د.ل.

## 8 — المشتريات

- **الشاشة:** `PurchasesScreen`، المفتاح `screen-purchases`. الإجمالي الدائم في `purchases-lifetime`: الناتج من الخادم، والمدفوع، والمتبقي (`lib/features/purchases/purchases_screen.dart:116`). يوم `12` يعرض `totals.totalDebtUnits` تحت «إجمالي الديون» (`purchases_screen.dart:240`).
- **المزوّد:** `purchasesProvider` مع `purchaseBookProvider` وافتراضه `PurchaseBook.alBayan` (`section_providers.dart:205`).
- **المسار:** `GET /api/purchases/al_bayan` و`GET /api/purchases/simsim`. الحقول `lifetimeTotals.remainingUnits` و`lifetimeTotals.resultUnits` و`lifetimeTotals.paidUnits`، ويومًا `days[].totals.totalDebtUnits`. الناتج بالدينار. `vodafoneRemainingUnits` يُرسم `ج.م` بافتراض `vodafoneCurrencyAssumption` (`purchase_models.dart:14`). الافتراض موسوم 🔶. لا قيمة موقع تُثبته أو تنفيه، فلم يُفتح له معرّف.
- **المصدر:** الحقول كما وصلت. الشاشة لا تطرح `resultUnits - paidUnits`.
- **التنسيق:** المتبقي الدائم `2,553 د.ل`. الناتج الدائم `50,000 د.ل`. المدفوع الدائم `47,447 د.ل`. إجمالي دين اليوم `2,553 د.ل`. متبقي بند فودافون في اليوم `553 د.ل`.
- **Fake:** `lifetimeTotals` في `fake_fixtures.dart:983` ويوم `12` `totalDebtUnits: 2553` (`fake_fixtures.dart:977`). `_purchasesView` ينسخ الحمولة نفسها لكل دفتر (`fake_api_client.dart:1803`). لا إعادة حساب للناتج من سعر `9.5`.

## 9 — الخزينة

- **الشاشة:** `TreasuryScreen`، المفتاح `screen-treasury`. البطاقات في `_Cards` (`lib/features/treasury/treasury_screen.dart:248`).
- **المزوّد:** `treasuryProvider` (`section_providers.dart:232`).
- **المسار:** `GET /api/treasury`. الجسم `totals`: `netUnits`، `receivablesUnits`، `liabilitiesUnits`، `activeCashUnits`، `egyptianSourceUnits`، `egyptianConvertedUnits`، و`egyptianRate` نصًا (`treasury_models.dart:36`).
- **المصدر:** كل بطاقة حقلها. التعليق في `treasury_models.dart:4` يقول إن التطبيق لا يجمع ولا يحوّل. جملة «ديون لنا + النشط + المصري − ديون علينا» نص ثابت بجانب الصافي (`strings.dart:125`) وليست ناتج حساب.
- **التنسيق والعملة:** الصافي والديون لنا وعلينا والنقد النشط والمصري بالليبي `د.ل`. مصدر المصري `ج.م`. السعر `formatDecimal` لنص `9.5` بلا تقريب.
- **Fake** (`fake_fixtures.dart:991`):

| الحقل | العدد | العرض |
|---|---|---|
| `netUnits` | 51000 | `51,000 د.ل` |
| `receivablesUnits` | 45000 | `45,000 د.ل` |
| `liabilitiesUnits` | 12000 | `12,000 د.ل` |
| `activeCashUnits` | 8000 | `8,000 د.ل` |
| `egyptianSourceUnits` | 95000 | `95,000 ج.م` |
| `egyptianConvertedUnits` | 10000 | `10,000 د.ل` |
| `egyptianRate` | النص `9.5` | `9.5` |

الرئيسية تعرض من هذه المجموعة «الفلوس النشطة» فقط (`fake_fixtures.dart:688`).

## 10 — استلامات الديون

- **الشاشة:** `CollectionsScreen`، المفتاح `screen-collections`. `_Metrics` (`lib/features/collections/collections_screen.dart:198`).
- **المزوّد:** `collectionsProvider` (`section_providers.dart:215`).
- **المسار:** `GET /api/collections`. المبالغ من `metrics.collectedUnits` و`metrics.dayTotalUnits` و`metrics.cashOutstandingUnits` (`collection_models.dart:200`). التعليق على `dayTotalUnits` يقول إن إجمالي اليوم لا يُجمع على الجهاز (`collection_models.dart:173`).
- **المصدر:** الحقول كما وصلت. لا جمع لصفوف التعيين.
- **التنسيق:** الثلاثة `د.ل`.
- **Fake** (`fake_fixtures.dart:825`): `collectedUnits` 0، `dayTotalUnits` 100، `cashOutstandingUnits` 250. العرض `0 د.ل` و`100 د.ل` و`250 د.ل`.
- بطاقة الرئيسية «الاستلامات المعتمدة اليوم» تقرأ `collectedUnits` نفسه (0). سؤال العنوان مفتوح من قبل ولم يُحوَّل إلى عيب في هذه الجولة.

## العيوب

الحالات العشر لها شاشة ومسار. لم يُفتح عيب «لا شاشة» ولا عيب «لا مسار». لم يُفتح عيب تقريب.

### DEF-028 — Fake يحسب رصيد السداد الجزئي ويزيح ملخص القسم

**الحالة:** Open على جرد `main` `54884d7`. غير مانع لمسار القراءة من الخادم الحقيقي. التالي الحر DEF-029.

| الحقل | القيمة |
|---|---|
| المرحلة | 8 |
| الشدة | منخفضة |
| التصنيف | Non-blocking |
| المالك المقترح | مهندس API (Fake). شاشة Flutter تعرض الحقل بعد إعادة الجلب |
| الحالة | Open |

**الدليل:**

1. حوار السداد يرسل `inputValue` ثم يعيد جلب الكارت. لا طرح في `lib/` (`ledger_screen.dart:417` و`lib/ui/strings.dart:93`).
2. `FakeApiClient._applyMovement` يخزّن `previous - entered` في `balanceUnits` و`balanceAfterUnits` عندما يكون السداد جزئيًا ومباشرًا (`fake_api_client.dart:1559`).
3. `_accountsView` يجمع فرق الرصيد في `delta` (`fake_api_client.dart:1471`) ثم يضيفه إلى `summary.netBalance` و`summary.totalDebt` (`fake_api_client.dart:1478`). التعليق في `account_models.dart:148` يقول إن `totalDebt` مجموع الأرصدة الموجبة فقط و`netBalance` صافي القسم. إزاحة الحقلين معًا قد تخالف خادمًا يفرّق بينهما.
4. السداد الكلي يخزّن 0 بلا طرح (`fake_api_client.dart:1525`). هذا الصف ليس الحساب محل العيب. العيب هو أن رقم «بعد السداد الجزئي» وأرقام الملخص بعد الكتابة، على Fake، ليسا قيمة مخزَّنة جاهزة.
5. إلغاء حركة ينسخ آخر `balanceAfterUnits` مرحَّل إلى الكارت (`fake_api_client.dart:1581`). نفس الصنف: الرصيد على Fake يُشتق محليًا.

مقارنة Fake بالموقع لا تُغلق صفًا. إغلاق الصفوف على الخادم الحقيقي ما زال الخطوة ب، والتسامح صفر.

## فجوات ليست عيوبًا

- عمود الموقع فارغ للحالات العشر. لا رقم موقع في هذا المستودع.
- الرئيسية لا تعرض إجمالي الشركات ولا الأمانات الليبية ولا المشتريات ولا `totalDebt` للعملاء. الشاشات الخاصة تعرضها، فالمسار موجود.
- الخزينة والاستلامات والمشتريات تعرض أكثر من عدد. الصف في الجدول يسمّي العدد الأبرز ويُبقي الباقي في التفاصيل حتى يحدّد علي حقل الموقع.
- دفترا المشتريات يعيدان حمولة Fake واحدة.
- عملة حقول فودافون مفترضة `EGP` وموسومة 🔶.
- `MONEY_UNIT_SCALE` افتراضه 0 وموسوم 🔶. التنسيق الحالي لا يقرّب.
- بطاقة «الاستلامات المعتمدة اليوم» تبقى سؤال العنوان السابق.

## ما لم يُكتب

لا اختبار مطابقة في هذه الخطوة. لا تشغيل ضد موقع. التوقيع عند علي.
