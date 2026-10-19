# vib-abdo-company-mobile

Android client for a debt, trust, and collection system. Two currencies are shown: the Libyan dinar (LYD, د.ل) and the Egyptian pound (EGP, ج.م). This repository is the mobile app only. It does not contain a database or a server.

Feature screens beyond sign-in and an empty home shell are not built yet. The home shell lists the sections the server says the signed-in person may see, and each row is disabled.

## Rules

1. **No financial calculations.** Totals, balances, remaining amounts, debt age, and converted amounts are shown exactly as the server sends them. Fields named `*Units` are raw integers. The only transformation is `MoneyFormatter`, which turns one integer into text and appends that value's own currency symbol. The app does not add, subtract, convert, or mix LYD and EGP.
2. **No secrets in the repo.** There are no passwords, API keys, tokens, real base URLs, real usernames, or real customer records. The API origin and similar settings come from `--dart-define`. The default origin is the placeholder `https://staging.example.invalid`. Fixtures are obviously fake (`example.invalid`, "تجريبي").
3. **The server decides permissions.** The app only hides or disables controls from the role and permission codes the server returns. The two roles are `admin` and `employee`. Hiding a button is not enforcement; the server still rejects a request the person cannot make.
4. **Unread count comes from the server.** The badge shows `unreadCount` from the notifications response. The app does not increment or decrement it. A realtime event or a push message, when one exists, is only a signal to fetch that count again.

## State management

The app uses [Riverpod](https://riverpod.dev).

The API package was built as one composition root (`ApiLayer`) plus a `SessionManager` listenable for the router. Riverpod maps that shape directly: `apiLayerProvider` creates the root, and the rest of the app watches narrow providers (session, login, unread count) instead of passing the root through widget constructors. `Notifier` and `FutureProvider` make loading and failure explicit, which is the path the central error handler reads. Tests replace `apiConfigProvider` in a `ProviderScope` and get the in-memory client without a service locator. One library is enough for this app; a second pattern such as Bloc would split the same job across two styles.

`go_router` reads `SessionManager.listenable` and sends the user to the splash, login, or home route. It does not decide permissions.

## Layout

```
lib/
  api/                 App wiring of the API package (config + ApiLayer)
  authentication/      Route gate and local sign-in checks
  models/              Types the UI may read (server models + home summary)
  state/               Riverpod: session, login, unread count, router
  features/
    splash/            Session restore
    login/             Sign-in screen
    home/              Empty shell, permission-gated section list
  ui/                  Theme, Arabic copy, section labels
  notifications/       Unread badge, no-op push, realtime start/stop
  secure_storage/      Cookie jar and token store (flutter_secure_storage)
  error_handling/      Maps failures to a message; logs code + correlation id only
packages/api_layer/    HTTP client, repositories, models, fake client, auth strategies
```

`packages/api_layer` is the client package this app started from. Screens call its repositories. They do not import the HTTP client.

Secure storage is injected into that package. The real cookie-session path and the bearer-token stub write only through `flutter_secure_storage`. The default fake client keeps its session in memory and does not write the stores.

Errors thrown by the client are `ApiException` values. `ErrorHandler` is the only place that turns one into text for the UI. It shows the server message when there is one. Logs contain the error code and correlation id, never `details`, passwords, or cookies.

## Run

Requires Flutter 3.47 (the package was checked on 3.47.7 / Dart 3.13.5).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The same analyze and test commands should also pass in `packages/api_layer`. `tool/check.sh` runs both.

Default launch uses the fake client and does not open a network connection:

```bash
flutter run
```

Fake sign-in is not an account:

- any password other than `wrong` is accepted
- a username that starts with `admin` is the admin role
- any other username is an employee

Point a build at a real host without committing the host:

```bash
flutter run --dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://your-host.example
```

Other defines are listed in `packages/api_layer/README.md`.

## Android

The debug application id is `com.example.vib_abdo_company_mobile`. Replace it before any store listing. Debug builds are signed with the debug key only.
