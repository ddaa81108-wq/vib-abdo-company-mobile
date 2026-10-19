# API layer

Client package used by the mobile app. Screens depend on repositories exposed by `ApiLayer`. They do not talk to the HTTP stack directly.

## Modes

- **Fake (default).** In-memory client, no network. `USE_FAKE_API` defaults to true.
- **Real host.** Supply the origin at build time. Do not commit it.

```bash
flutter run --dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://your-host.example
```

The placeholder origin is `https://staging.example.invalid`.

Optional defines:

| Define | Default | Meaning |
| --- | --- | --- |
| `API_BASE` | `https://staging.example.invalid` | API origin, no path |
| `USE_FAKE_API` | `true` | In-memory client |
| `AUTH_BEARER` | `false` | Use the bearer-token stub instead of the cookie session |
| `API_DEBUG_LOG` | `false` | Log method, path, status, correlation id, and timing only |
| `MONEY_UNIT_SCALE` | `0` | Fractional digits encoded in `*Units` integers |

## Rules

- Values named `*Units` are raw integers. Turn one value into text with `MoneyFormatter` and that value's own currency. Do not add, subtract, convert, or mix currencies.
- Session cookies and bearer tokens, when a real host is used, go through `flutter_secure_storage`. The fake client does not write them.
- Permissions used to hide or disable controls are decided only in `PermissionService` from the server profile. The server still enforces every request.
- A realtime event or push message is a signal to refetch. Do not display numbers from the event.

## Fake sign-in

Not an account. Any password other than `wrong` is accepted. The username picks a canned profile:

- starts with `admin` — role `admin`, empty permission list (unrestricted)
- starts with `limited.admin` — role `admin` with an explicit permission list
- starts with `readonly` — employee, one read permission, no write control
- starts with `nosection` — employee missing `sectionAccess` for one permitted section
- starts with `unknown` — unrecognized role, no access
- anything else — employee with the canned collection and customer access
