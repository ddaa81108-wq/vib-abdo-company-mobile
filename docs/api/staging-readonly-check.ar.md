# فحص staging للقراءة فقط — 2026-10-23

- **الوقت:** 01:17 بتوقيت طرابلس (UTC+2).
- **الهدف:** `https://staging.vip2100.com`، والـ API على الأصل `/api`.
- **النسخة:** commit `537f073`، apiVersion `1`، schema `50`. أكدها `GET /api/health`.

## القواعد المتّبعة

- **لا قيم في هذا الملف.** سجّلنا البنية فقط: أسماء المفاتيح والأنواع ورموز الحالة والأعداد. لا أسماء مستخدمين، ولا كلمات مرور، ولا كوكيز، ولا رموز CSRF، ولا معرّفات، ولا أسماء عملاء، ولا هواتف، ولا مبالغ.
- **بيانات الدخول** حُمّلت في ذاكرة العملية فقط من ملف خارج المستودع، ولم تُطبع ولم تُكتب. الكوكيز في CookieJar داخل الذاكرة، ولم يُكتب ملف jar.
- **تسجيل دخول واحد لكل دور.** المحاولة الأولى لم تصل الخادم: Cloudflare أعاد 403 لـ User-Agent `Python-urllib`، ورابط الأساس كان يتضمن `/erp`. أُعيدت المحاولة مرة واحدة بالأصل الصحيح وUA `Dart/3.13 (dart:io)`، ونجحت للأدوار الثلاثة.
- **لا كتابة.** الطرق المستخدمة: `POST /api/auth/login`، ثم `GET` فقط، ثم `POST /api/auth/logout`. لم يُمس أي من الحركات أو الاستلامات أو تعليم القراءة أو تسجيل الجهاز.
- **بعد الخروج** أعاد `GET /api/me` القيمة 401 للأدوار الثلاثة، فالجلسات أُغلقت.

## 1. الدخول و`/api/me`

| | admin | limited | collector |
|---|---|---|---|
| `POST /api/auth/login` | 200 | 200 | 200 |
| مفاتيح `data` | `apiVersion`, `csrfToken`, `expiresAt`, `user` | نفسها | نفسها |
| `csrfToken` موجود | نعم | نعم | نعم |
| `apiVersion` | `"1"` (نص) | `"1"` | `"1"` |
| `Set-Cookie` `abdo_session` | HttpOnly, Secure, SameSite=Strict, Path, Expires | نفسها | نفسها |
| `Set-Cookie` `abdo_mfa` | HttpOnly, Secure, SameSite=Lax, Path, Max-Age (مسح غالبًا) | نفسها | نفسها |
| MFA مطلوب | لا | لا | لا |
| `GET /api/me` | 200 | 200 | 200 |
| مفاتيح `data` / `user` | `apiVersion`, `schemaVersion`, `user` / `id`, `username`, `displayName`, `role`, `isOwner`, `permissions`, `mustChangePassword` | نفسها | نفسها |
| `role` / `isOwner` | `admin` / `true` | `employee` / `false` | `employee` / `false` |
| `permissions` | `[]` (المدير يتجاوز) | `debts.read`, `companies.read`, `libyan_deposits.read`, `egyptian_deposits.read`, `purchases.read`, `treasury.read`, `reports.read`, `collections.read` | `collections.read`, `collections.write` |
| `sectionAccess` | **غائب** | **غائب** | **غائب** |
| `mustChangePassword` | `false` | `false` | `false` |
| `GET /api/me` بلا `X-Client-Api-Version` | 200 (القراءة لا تفحص الرأس) | لم يُفحص | لم يُفحص |
| `POST /api/auth/logout` ثم `GET /api/me` | 200 ثم 401 | 200 ثم 401 | 200 ثم 401 |

## 2. مصفوفة الحالة (GET فقط)

| المسار | admin | limited | collector |
|---|---|---|---|
| `/api/customers?limit=20` | 200 | 200 | 403 `PERMISSION_DENIED` |
| `/api/customers/{id}` (أول كارت) | 200 | 200 | لم يُفحص (لا وصول للقائمة) |
| `/api/customers/{id}/ledger?limit=20` | 200 | 200 | لم يُفحص |
| `/api/companies?limit=20` | 200 | 200 | 403 |
| `/api/libyan-deposits?limit=20` | 200 | 200 | 403 |
| `/api/egyptian-deposits?limit=20` | 200 | 200 | 403 |
| `/api/egyptian-deposits/exchange-rate` | 200 | 200 | 403 |
| `/api/purchases/al_bayan?limit=20` | 200 | 200 | 403 |
| `/api/purchases/simsim?limit=20` | 200 | 200 | 403 |
| `/api/treasury` | 200 | 200 | 403 |
| `/api/treasury/cash-ledger` | 200 | 200 | 403 |
| `/api/collections` | 200 (مع `employeeTotals`) | 200 (بلا `employeeTotals`، وقوائم فارغة) | 200 (بلا `employeeTotals`، صفوفه فقط) |
| `/api/collections/payroll` | 200 | 200 | 200 |
| `/api/notifications` | 200 | 200 | 200 |
| `/api/reports?limit=30` | 200 | 200 | 403 |
| `/api/financial-ledger` | 200 | 403 | 403 |
| `/api/event-changes?after=0` | 200 | 200 | 200 |
| `/api/notifications/unread-count` (مقترح في التطبيق) | **404 `ROUTE_NOT_FOUND`** | 404 | 404 |
| `/api/home` (مقترح) | **404** | 404 | 404 |
| `/api/admin/employee-totals` (مقترح) | **404** | 404 | 404 |

كل 403 يحمل `error.details.permission`.

## 3. البنية مقابل تحليل الفجوة

| البند | ما وُجد على staging | مقارنة بالتطبيق |
|---|---|---|
| قائمة الحسابات | `items[]`, `nextCursor` (null), `totalItems` (int), `summary{netBalance,totalDebt,activeCards,pendingReviewCount}` كلها int | يطابق `AccountsPage` |
| البحث بلا نتيجة (`q`) | `items` فارغة، `totalItems` int، و`summary` حاضر | يطابق: الملخص لا يعتمد على الصفحة (DEF-030) |
| الكارت | مسطّح في `data`: `balanceUnits`, `openingBalanceUnits`, `version`, `currency`, `isPinned`, `zeroReview{pending,financialVersion,...}`, ... | يطابق |
| كشف الحساب | `customer{...}`, `items[]{amountUnits,inputValue,factorMicros,paymentMode,...}`, `pageOpeningBalanceUnits`, `totalItems`, `nextCursor` | يطابق |
| الخزينة | مسطّح: `receivablesUnits`, `liabilitiesUnits`, `activeCashUnits`, `egyptianSourceUnits`, `egyptianConvertedUnits`, `egyptianRate` (int), `netUnits`, **`cashVersion`**, `sources{customers,companies,purchases,libyanDeposits,egyptianDeposits}`, `currency` | **G-04:** لا `totals` ولا `version` |
| سجل النقدية | `items[]{amountUnits,balanceBeforeUnits,balanceAfterUnits,direction,...}`, `nextBefore` | يطابق. `actorName` بدل `createdByName` |
| المشتريات | `merchant`, `day{version,previousDebtUnits,todayResultUnits,todayPaidUnits,totalDebtUnits,vodafoneRemainingUnits,...}`, `entries[]{version,dayVersion,...}`, `nextBefore`, `registerTotals{resultUnits,paidUnits,remainingUnits,vodafoneConsumedUnits,vodafoneRemainingUnits}` | **G-02:** لا `days` ولا `lifetimeTotals`/`totals` |
| الاستلامات | `assignments[]`, `submissions[]`, `unlinkedReceipts[]`, `metrics{collectedUnits,pendingCount,executedCount,cashOutstandingUnits,unlinkedPendingCount}`, `assignedCount`, `openBatches[]`, `outstandingCancelledSubmissions`، و`employeeTotals[]` للمدير | **G-01:** لا `version` في `submissions[]` ولا `unlinkedReceipts[]`. لا `dayTotalUnits` ولا `batchId` |
| مفاتيح `submissions[]` | `id`, `assignmentId`, `customerId`, `collectorUserId`, `mode`, `amountUnits`, `status`, `submittedAt`, `businessDate`, `batchId`, `decidedAt`, `decisionNote`, `cashReceivedAt`, `customerName`, `collectorName`, `phone` | — |
| الإشعارات | `items[]{id,action,entityType,entityId,sectionKey,details,actor*,createdAt,readAt}`, `unreadCount` (int), `nextBefore` | يطابق. `unreadCount` هو البديل عن `/unread-count` |
| دفتر المالية | `items[]{sectionKey,sourceStatus,occurredAt,entryKind,effectUnits,...}`, `pageTotals{LYD,EGP}`, `nextBefore` | **G-12:** التطبيق يقرأ `section`/`status`/`createdAt` |
| التقارير | `current`, `items[]{...,daily,reasons,fiveAmClosing,summary}`, `methodology` | G-12: `current` و`daily` لا تُقرأ |
| الأحداث | `events[]`, `latest` (int), `fullResync` | يطابق |
| سعر الصرف | `egpPerLyd` (int في هذه البيانات), `sourceCurrency`, `targetCurrency`, `updatedAt`, `activeForTreasury` | يطابق `RateWireFormat.number`. قد يكون كسريًا حتى 6 منازل |
| العملات المرصودة | العملاء والشركات والليبية والخزينة والتقارير: `LYD`. المصرية: `EGP`. دفتر المالية: `LYD` و`EGP`. الاستلامات: لا حقل `currency` | يطابق DEF-035 |
| **أنواع المال** | **كل حقول المال int**: 149 قيمة للمدير و111 للمحدود و13 للمحصّل. لا float ولا نص | يطابق `moneyUnitScale=0` وDEF-029 |
| الترقيم | الحسابات والكشف `nextCursor`. المشتريات والخزينة والإشعارات ودفتر المالية `nextBefore` | يطابق §4 |

## 4. فجوات جديدة كشفها الفحص

1. **G-15:** `/api/me` لا يعيد `sectionAccess`. `PermissionService` يعدّ غيابه `none` للموظف، فيُحجب كل قسم عن المحدود في الواجهة مع أن الخادم يعيد 200.
2. **إعداد:** `STAGING_API_BASE` يجب أن يكون `https://staging.vip2100.com` بلا `/erp`. الـ API تحت `/erp/api/*` يعيد HTML.
3. **أدوات CI:** Cloudflare يحجب UA `Python-urllib`. Dart وokhttp مقبولان.
4. `employeeTotals` للمدير فقط. للموظف يجب أن تختفي البطاقة بلا خطأ.

## إعادة التشغيل

يمكن إعادة الفحص بالأسرار في CI (`STAGING_API_BASE` و`STAGING_ADMIN_USERNAME` و`STAGING_ADMIN_PASSWORD`، ومثلها للدورين الآخرين)، أو عبر `staging_smoke_test.dart` بعد إصلاح G-05. انظر `integration-plan.ar.md`.
