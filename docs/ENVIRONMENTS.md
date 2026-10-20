# Environments

This app reads compile-time settings only through `--dart-define`, in `ApiConfig.fromEnvironment()` (`packages/api_layer/lib/core/config/api_config.dart`). A bare `flutter run` or `flutter build` passes no defines, so the app uses the fake client and does not open a network connection.

Named environments are JSON files passed with Flutter's `--dart-define-from-file` (Flutter 3.7 or newer; this repo is checked on Flutter 3.47). `tool/flutter_env.sh` picks the file and checks it before Flutter starts. Nothing in these files changes the application id or the Android signing config.

Real origins, tokens, passwords, and account names do not belong in the repository. The committed JSON files contain only the same placeholders the code already defaults to.

## Environments

| Name | What it runs | Define file the script uses | Network |
|---|---|---|---|
| `fake` | In-memory fake client. This is the default. | `config/dart_defines/fake.json` if you created that gitignored file, otherwise the committed `config/dart_defines/fake.example.json` | No |
| `staging` | Real HTTP client, aimed at a staging or test copy of the server | Gitignored `config/dart_defines/staging.json` | Yes |
| `prod` | Not a target | None. `config/dart_defines/prod.example.json` is a shape placeholder only | The script refuses to run or build it |

`prod` is reserved so a future production file has an obvious name. The app must be pointed at a staging or test copy, not production (`ApiConfig` does not default the origin to production). `tool/flutter_env.sh prod …` exits with an error. Do not replace `https://prod.example.invalid` with a real production origin, and do not pass `prod.example.json` to Flutter.

Android product flavors are not used. Flavors are the usual way an application id changes per environment, and this setup leaves `com.example.vib_abdo_company_mobile` and the debug signing config as they are.

## Every define

`ApiConfig.fromEnvironment()` reads exactly these keys. Any other key is ignored by the app. The script rejects unknown keys so a typo cannot silently do nothing.

Values are compile-time constants. Changing a file has no effect until the next `flutter run` or `flutter build`.

| Define | Type | Code default when the define is absent | Example files | What it does |
|---|---|---|---|---|
| `USE_FAKE_API` | bool | `true` | `true` for fake, `false` for staging | `true` builds `FakeApiClient` and does not create a Dio client. `false` builds the real client. Dart accepts only the strings `true` and `false`. Any other value is treated as if the define were absent, so the default stays `true`. |
| `API_BASE` | string | `https://staging.example.invalid` | That placeholder in the fake and staging examples. `https://prod.example.invalid` in the prod placeholder | Origin only, for example `https://host` or `https://host:8443`. No path, query, user, or fragment. Repository paths already start with `/api`. Unused while `USE_FAKE_API` is true, because the fake client never reads it. The default host is not a server. |
| `API_DEBUG_LOG` | bool | `false` | `false` | When `true` **and** the real client is in use, `SafeLoggingInterceptor` logs method, path, status, correlation id, retry, and duration. It does not log headers, cookies, bodies, amounts, or names. Unused in fake mode (no interceptor is attached). Absent or `false` leaves logging off on the `fromEnvironment()` path. |
| `AUTH_BEARER` | bool | `false` | `false` | `false` selects cookie session plus `X-CSRF-Token`, which is the real server today. `true` selects the bearer-token stub (`BearerTokenAuthStrategy`), which is not a confirmed mobile login. Unused in fake mode. This define does not carry a token. Tokens, if a scheme is ever confirmed, stay in secure storage at runtime. |
| `MONEY_UNIT_SCALE` | int | `0` | `0` | How many fractional digits are encoded in `*Units` integers. `0` means whole dinars and pounds. **Still to confirm with the server owner.** `MoneyFormatter` uses it only to place a decimal point when displaying one integer. The app does not add, scale, or convert money. This value applies in fake mode and in real mode, because the formatter is always built from the config. |
| `RATE_WIRE_FORMAT` | string | empty, which selects `number` | `number` | Wire encoding of rate and factor values only. `string` sends a JSON string such as `"9.5"`. Any other value, including `number` and empty, sends a JSON number literal such as `9.5`. Inside the app the value stays decimal text. The current server accepts numbers; the contract's target form is a string. **Still to confirm.** The fake client records bodies with this format too. |

These `ApiConfig` fields are not defines. They always use the constructor defaults:

| Field | Default | Meaning |
|---|---|---|
| `connectTimeout` | 15 seconds | Real-client connect timeout |
| `receiveTimeout` | 30 seconds | Real-client receive timeout |
| `pollingInterval` | 4 seconds | Fallback poll of `/api/event-changes` when SSE is down. Fake mode does not start realtime |

JSON booleans and numbers are the form used in the example files. Flutter stringifies them (`true`, `false`, `0`) before Dart reads them. A JSON string `"false"` or `"0"` is also accepted by the script and by Dart.

## Files

| Path | In git? | Role |
|---|---|---|
| `config/dart_defines/fake.example.json` | Yes | Safe fake config. Same values as the code defaults. The script uses it when `fake.json` is absent. |
| `config/dart_defines/staging.example.json` | Yes | Template. `API_BASE` is the placeholder `https://staging.example.invalid`. Copy it; do not point Flutter at it. |
| `config/dart_defines/prod.example.json` | Yes | Placeholder for a future file. Not a supported environment. |
| `config/dart_defines/fake.json` | No (gitignored) | Optional local fake overrides, for example `API_DEBUG_LOG`. Must keep `USE_FAKE_API` true. |
| `config/dart_defines/staging.json` | No (gitignored) | The only staging file the script will load. |
| `config/dart_defines/prod.json` | No (gitignored) | Unused. The script refuses `prod` even if this file exists. |

`.gitignore` ignores every `config/dart_defines/*.json` except `*.example.json`.

## Run and build

From the repository root, with Flutter on `PATH`.

### Fake (default)

No file and no flags. This is the build `tool/check.sh` matches: fake client, placeholder origin ignored.

```bash
flutter pub get
flutter run
flutter build apk --debug
```

The same defines, written out:

```bash
tool/flutter_env.sh fake run
tool/flutter_env.sh fake build apk --debug
```

Equivalent, without the script:

```bash
flutter run --dart-define-from-file=config/dart_defines/fake.example.json
flutter build apk --debug --dart-define-from-file=config/dart_defines/fake.example.json
```

Fake sign-in is not an account. Any password other than `wrong` is accepted. A username that starts with `admin` is an unrestricted admin. `limited.admin`, `flag.admin`, and `guest` are the other fixtures. Any other username is a collections employee. Details are in the root `README.md`.

### Staging

The staging origin comes from the server owner. It is not in this repo.

```bash
cp config/dart_defines/staging.example.json config/dart_defines/staging.json
chmod 600 config/dart_defines/staging.json
```

Edit `API_BASE` in `staging.json` so it is the staging or test origin (`https://host`, no `/api` suffix). Leave `USE_FAKE_API` set to `false`. Keep `MONEY_UNIT_SCALE` and `RATE_WIRE_FORMAT` at the example values until the server owner confirms them. Do not commit the file (`git status` must not list it).

```bash
tool/flutter_env.sh staging run
tool/flutter_env.sh staging build apk --debug
```

The script will not start Flutter until `staging.json` exists, is JSON, has only the keys in the table above, sets `USE_FAKE_API` to `false`, and sets `API_BASE` to an origin that is not a placeholder (`*.invalid`, `*.example`, `example.com`, or a value containing `placeholder`, `changeme`, or `replace`). It prints the environment name and the file path. It does not print `API_BASE`.

On Windows, the same flags work from a terminal where `flutter` is on `PATH`. Git Bash can run `tool/flutter_env.sh`. From `cmd` or PowerShell, pass the file yourself:

```bash
flutter run --dart-define-from-file=config/dart_defines/staging.json
```

A release APK is still signed with the debug keystore. That is the existing `android/app/build.gradle.kts` setting. These environment files do not change it.

### Prod

```bash
tool/flutter_env.sh prod run
```

This exits with status 1 and does not call Flutter.

### Extra defines

Arguments after the environment name are passed through:

```bash
tool/flutter_env.sh fake run -d emulator-5554
tool/flutter_env.sh staging build apk --debug
```

A command-line `--dart-define` overrides the same key from `--dart-define-from-file`. Flutter applies that precedence itself. The script appends the file flag after the arguments you pass, because Flutter 3.47 accepts `--dart-define-from-file` on the subcommand (`run`, `test`, `build apk`) and not in front of it. Prefer editing the gitignored JSON when you want a value to stick. Do not rely on a command-line override to point fake mode at a real server: the script rejects a fake file whose `USE_FAKE_API` is false, but an extra `--dart-define=USE_FAKE_API=false` is ordinary Flutter and will be compiled in. Use `staging` for that.

`flutter analyze`, `flutter test`, and `tool/check.sh` must be run **without** a define file. `packages/api_layer/test/api_config_test.dart` asserts the compile-time defaults (fake client, placeholder origin, scale 0, rate wire format `number`). Loading `staging.json` into that test run would fail the test on purpose.

## Where real values come from

| Value | Local | CI | Repository |
|---|---|---|---|
| Staging origin (`API_BASE`) | `config/dart_defines/staging.json`, mode `600`, from the server owner | Secret `STAGING_API_BASE`, written into a job-local file | Placeholder only |
| `MONEY_UNIT_SCALE`, `RATE_WIRE_FORMAT`, `AUTH_BEARER` | The example values, until the server owner says otherwise | Optional secrets, only if they must differ from the examples | The unconfirmed defaults |
| Tokens, passwords, usernames | Not in define files. Cookie and CSRF state stay in `flutter_secure_storage` at runtime | Not compile-time defines | Never |

There is no CI workflow in this repo yet. When one is added, the job should create the gitignored file from secrets and then call the script. Do not echo the secret.

```bash
umask 077
python3 - <<'PY'
import json, os
from pathlib import Path
Path("config/dart_defines/staging.json").write_text(
    json.dumps(
        {
            "USE_FAKE_API": False,
            "API_BASE": os.environ["STAGING_API_BASE"].strip(),
            "API_DEBUG_LOG": False,
            "AUTH_BEARER": os.environ.get("AUTH_BEARER", "false").strip() == "true",
            "MONEY_UNIT_SCALE": int(os.environ.get("MONEY_UNIT_SCALE", "0").strip()),
            "RATE_WIRE_FORMAT": os.environ.get("RATE_WIRE_FORMAT", "number").strip(),
        },
        indent=2,
    )
    + "\n",
    encoding="utf-8",
)
PY
tool/flutter_env.sh staging build apk --debug
```

`STAGING_API_BASE` is the origin only. `API_DEBUG_LOG` stays false in CI. Leave `AUTH_BEARER` unset until the server owner confirms a mobile token scheme.

A fake CI build needs no secrets:

```bash
tool/flutter_env.sh fake build apk --debug
```

## Open points

These are not decided in the repo. The example files keep the code defaults until someone who owns the server answers them.

1. The real staging (or test) origin, and test accounts per role, have to be delivered outside the repo.
2. `MONEY_UNIT_SCALE`: are `*Units` whole currency units (`0`), or is there a fractional scale?
3. `RATE_WIRE_FORMAT`: the server today is described as accepting JSON numbers; the contract target is a JSON string.
4. `AUTH_BEARER`: cookie plus CSRF is the live scheme. The bearer strategy is a stub.
5. A production origin is out of scope. `prod` stays a placeholder until the app and the server owner both allow one.
