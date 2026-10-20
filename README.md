# vib-abdo-company-mobile

Android client for a debt, trust, and collection system. Two currencies are shown: the Libyan dinar (LYD, د.ل) and the Egyptian pound (EGP, ج.م). This repository is the mobile app only. It does not contain a database or a server.

The home shell lists the sections the server says the signed-in person may open, and hides every row or control they cannot use. A write control is disabled, with a progress indicator, only while that send is in progress.

Customer debts, company debts, Libyan deposits, and Egyptian deposits are the same two screens. `AccountListScreen` renders the card list for all four, and `LedgerScreen` renders one card's movements. The `AccountSection` argument chooses the repository path, the currency, and the Arabic labels. Collections, purchases, treasury, reports, settings, and notifications each have their own screen.

A form creates one `requestId` when it opens. A retry of the same inputs reuses that id. Changing an input, opening a new form, or a successful send starts a new id.

## Rules

1. **No financial calculations.** Totals, balances, remaining amounts, debt age, and converted amounts are shown exactly as the server sends them. Fields named `*Units` are raw integers. The only transformation is `MoneyFormatter`, which turns one integer into text and appends that value's own currency symbol. The app does not add, subtract, convert, or mix LYD and EGP.
2. **No secrets in the repo.** There are no passwords, API keys, tokens, real base URLs, real usernames, or real customer records. The API origin and similar settings come from `--dart-define`. The default origin is the placeholder `https://staging.example.invalid`. Fixtures are obviously fake (`example.invalid`, "تجريبي").
3. **The server decides permissions.** `PermissionService` is the only place that matches the server `role` string (`admin` or `employee`, exact). An unknown or missing role grants nothing. If the server sends `fullAccess`, that flag wins. Otherwise an explicit permission list applies even for an admin, and an admin with only `sectionAccess` does not become unrestricted. An admin with both lists empty and no `fullAccess` flag is unrestricted. Section keys in `sectionAccess` are the server keys (`customerDebts`, `companyDebts`, `libyanDeposits`, and the rest). Values are `none`, `read`, or `manage`. Opening a section needs the read code and a level other than `none`; writing needs the write code and `manage`. Collections has no `sectionAccess` entry and is gated by its permission codes only. Management actions (approve, reject, cash receive, and the rest) use those action codes through `can` / `canDo`. Hiding a control is not enforcement.
4. **Unread count comes from the server.** The badge shows `unreadCount` from the notifications response. The app does not increment or decrement it. A realtime event or a push message, when one exists, is only a signal to fetch that count again.

## State management

The app uses [Riverpod](https://riverpod.dev).

The API package was built as one composition root (`ApiLayer`) plus a `SessionManager` listenable for the router. `main` builds that object and injects it with `apiLayerProvider.overrideWithValue`. The provider does not construct a client. The rest of the app watches narrow providers (session, login, unread count). `Notifier` and `FutureProvider` make loading and failure explicit, which is the path the central error handler reads. Tests inject their own fake `ApiLayer` the same way. One library is enough for this app; a second pattern such as Bloc would split the same job across two styles.

`go_router` reads `SessionManager.listenable` and sends the user to the splash, login, or home route. It does not decide permissions.

## Layout

```
lib/
  api/                 Injected ApiLayer provider (built in main, not here)
  authentication/      Route gate and local sign-in checks
  models/              Types the UI may read (server models + home summary)
  state/               Riverpod: session, login, unread count, router
  features/
    splash/            Session restore
    login/             Sign-in screen
    home/              Home shell: server summary plus permission-gated sections
    accounts/          Shared list and ledger for customers, companies, and both deposit sections
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
- a username that starts with `admin` is an unrestricted admin (empty permission lists)
- `limited.admin` is an admin limited to an explicit list
- `flag.admin` is an admin with `fullAccess` false
- `guest` is an unknown role and sees nothing
- any other username is a collections employee

Point a build at a real host without committing the host:

```bash
flutter run --dart-define=USE_FAKE_API=false --dart-define=API_BASE=https://your-host.example
```

Other defines are listed in `packages/api_layer/README.md`.

## Android

The application id is the placeholder `com.example.vib_abdo_company_mobile` on every build type. Leave it until the store id is chosen. `docs/RELEASE.md` lists every file that rename touches, and how release signing works.

Debug and profile builds use the debug keystore. A release build uses the upload key when `android/key.properties` or the `ANDROID_KEYSTORE_*` variables are complete. When that material is absent, release signing falls back to the debug keystore so local and pull-request builds still run. Keep a debug-signed release build off Play. Partial signing material fails the build.

`.github/workflows/ci.yml` has one job, `Analyze, test, and debug APK` (`analyze-test-apk`): analyze, test, and a debug APK. `.github/workflows/android-release.yml` builds a signed AAB and APK when the repository secrets are present. Branch protection for `main` is described in `docs/BRANCH_PROTECTION.md` and is not enabled from this repository.
