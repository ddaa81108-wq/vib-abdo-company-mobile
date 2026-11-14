# FIX 093 — proposed server change (not applied)

Ali applies this himself in `ddaa81108-wq/wep-erp-support`. This file is the proposal only. Nothing here was pushed, merged, or deployed.

## What production sends today

`src/server/domain/mobilePush.ts`

- `notification.title` is the literal `VIB` (around the outbox send).
- `notification.body` is `mobilePushBody`: the Arabic head from `browserPushMessage` (`actor — action label`), then every `details_json` entry as `key: value`.
- `data` is only `notificationId`, `recipientUserId`, and `operationType`.
- The phone cannot restyle that system notification when the process is in the background, because the `notification` block is shown by Android before app code runs.

`details_json` already has the real fields (copied from the audit row), for example `subjectName`, `subjectSection`, `amountUnits`, `paidUnits`, `remainingUnits`, `vodafoneConsumedUnits`, `paymentMode`, `currency`, `payrollKind`, `employeeName`, `reason`. `actor_name` and `created_at` are columns on the notification row. Do not add fields that are not already stored.

## Proposed edit

In `createMobilePushDispatcher`, when building `message`:

1. Keep building `body` with `mobilePushBody` so an old client still has text.
2. Add the stored fields to `data` as strings (FCM data values must be strings). Skip null, empty, and any key matching `/password|token|secret|hash|csrf/i`.
3. Remove the `notification` block from `fcmMessageBody` so the message is data-only. The phone then posts one expanded notification. Leaving the block in place shows a second, clipped system notification.

```ts
const shadeKeys = [
  'subjectName', 'subjectSection', 'amountUnits', 'paidUnits', 'remainingUnits',
  'vodafoneConsumedUnits', 'paymentMode', 'mode', 'currency', 'payrollKind',
  'employeeName', 'reason',
] as const;

function shadeData(
  details: Record<string, unknown>,
  actorName: string,
  actorRole: string | null,
  createdAt: string,
) {
  const data: Record<string, string> = {
    actorName,
    createdAt,
  };
  if (actorRole) data.actorRole = actorRole;
  for (const key of shadeKeys) {
    const value = details[key];
    if (value === null || value === undefined || value === '') continue;
    if (typeof value === 'string' || typeof value === 'number') {
      data[key] = String(value);
    }
  }
  return data;
}
```

The outbox query needs `n.created_at` (it is not selected today). Pass `String(row.created_at)` into `shadeData`.

```ts
data: {
  notificationId: String(row.notification_id),
  recipientUserId: String(row.recipient_user_id),
  operationType: String(row.action),
  ...shadeData(details, String(row.actor_name ?? 'النظام'), row.actor_role, String(row.created_at)),
},
```

And in `fcmMessageBody`, delete the top-level `notification` object. Keep `android.priority: 'HIGH'`. The phone's background handler posts the expanded shade from `data`.
