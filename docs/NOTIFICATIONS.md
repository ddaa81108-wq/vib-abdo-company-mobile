# Android notifications

Local alerts for this Android app. The in-app notification list and the push-token boundary (`AppPushService`) are unchanged. This document is the platform setup: permission, channel, icon, badge, and optional Firebase.

There is no `docs/RELEASE.md`. Release builds that must reject the fake API are described in [TESTING.md](TESTING.md). That page links here for the optional Firebase file.

## Permission

`android.permission.POST_NOTIFICATIONS` is declared in the manifest. This change does not request it at runtime, does not add `permission_handler`, and does not ship a permission-request service or dialog.

A separate change adds `permission_handler` and the runtime request behind `NotificationPermissionService`. That change should leave the manifest permission alone so the two edits do not conflict.

On API 32 and older, including Android 10 (API 29), `POST_NOTIFICATIONS` does not exist. Notifications are allowed unless the user turned them off in system settings. On API 33 and newer the permission stays denied until something else grants it.

Alerts are not scheduled. `RECEIVE_BOOT_COMPLETED`, exact-alarm permissions, and the boot receivers are not added.

## Channel

| | |
| --- | --- |
| Id | `vib_collections_alerts` |
| Name | `تنبيهات VIB` |
| Description | `تنبيهات عامة وتنبيهات التحصيل` |
| Importance | high |
| Badge | `setShowBadge(true)` |

The name uses the manifest display name `VIB` (`android:label`). The id is the same in Dart, `res/values/strings.xml`, and the FCM default-channel meta-data. Do not rename it after a release; Android keeps the old channel.

The small icon is `res/drawable/ic_stat_notification.xml`, a white-on-transparent vector. It is the default icon for local notifications and the FCM meta-data `com.google.firebase.messaging.default_notification_icon`.

Launcher badges use the channel flag and, when a count is passed, `NotificationCompat.setNumber`. Launchers that do not show numbers ignore that value. There is no ShortcutBadger-style plugin; those crash on some launchers.

## SDK

Flutter 3.47.7 sets `minSdk` 24, `compileSdk` 36, and `targetSdk` 36. The app keeps the Flutter compile and target SDK (36 is the current value for this toolchain, above the 34/35 floor). `minSdk` is `minOf(flutter.minSdkVersion, 29)`, which stays 24 and cannot rise above Android 10.

| | This app |
| --- | --- |
| Android Gradle Plugin | 9.1.0 |
| Gradle | 9.3.1 |
| Kotlin | 2.4.0 |
| compileSdk | 36 |
| targetSdk | 36 |
| minSdk | 24 |

The application id is still `com.example.vib_abdo_company_mobile`. This work does not change it.

### `permission_handler` 13.0.2 (not added here)

Checked against the current release (published 2026-09-04), which depends on `permission_handler_android` 14.1.0. That Android plugin sets `minSdk` 24, `compileSdk` 37, buildscript AGP 9.0.1, and Kotlin 2.3.20. Its example app uses Gradle 9.1.0, AGP 9.0.1, Kotlin 2.3.20, `compileSdk` 37, and `targetSdk` 35. Version 14.0.0 of the Android plugin is a breaking change that requires the app `compileSdk` to be 37.

| Check | Result |
| --- | --- |
| minSdk 24 | Matches the plugin. Compatible. |
| targetSdk 36 | The plugin does not constrain the app target. Its example uses 35. Compatible. |
| AGP 9.1.0 | Newer than the plugin buildscript 9.0.1. Compatible. |
| Gradle 9.3.1 | Newer than the plugin example 9.1.0. Compatible. |
| Kotlin 2.4.0 | Newer than the plugin 2.3.20. Compatible. |
| compileSdk 36 | Not compatible. The plugin compiles against SDK 37, and its changelog tells the app to set `compileSdk` to 37. Flutter logs that mismatch from `ValidateCompileSdkVersionTask` and prints the fix; the task itself does not fail the build. The plugin module still needs the Android 37 platform installed. This PR leaves compileSdk at Flutter's 36. The change that adds `permission_handler` needs `compileSdk` 37. |

## Firebase is optional

The Google Services Gradle plugin is on the classpath, and it is **applied only when** `android/app/google-services.json` exists, or when `enableGoogleServices=true` (`-P` or `gradle.properties`) or `ENABLE_GOOGLE_SERVICES=true` is set. If the flag is set and the file is missing, the build fails. Fake mode and CI do not set the flag and do not commit the file, so they build without Firebase.

`google-services.json` is in `.gitignore`. Do not commit one.

The Firebase Messaging SDK is **not** a dependency. The manifest meta-data is there for the day that SDK is added. Until then it is unused.

`tool/decode_google_services_json.sh` writes `android/app/google-services.json` from the environment variable below. An empty variable is a no-op. The script prints the Android package name and does not print the file. The release job `Release build rejects fake API` runs it only after the fake-API rejection check, and only when the secret is present.

### Secret names

Names only. No values belong in git, in logs, or in this file.

| Name | Where it is read |
| --- | --- |
| `GOOGLE_SERVICES_JSON_BASE64` | Release job in `.github/workflows/ci.yml`, via `tool/decode_google_services_json.sh` |
| `GOOGLE_SERVICES_JSON_STAGING_BASE64` | Not read by CI. Use it if staging and production files are stored separately, and copy the one you are shipping into `GOOGLE_SERVICES_JSON_BASE64` for that release. |
| `GOOGLE_SERVICES_JSON_PROD_BASE64` | Not read by CI. Same as the staging name. |

`GOOGLE_SERVICES_JSON_BASE64` is base64 of one `google-services.json`. The decoded `package_name` must be `com.example.vib_abdo_company_mobile` until the application id changes. A mismatch deletes the file and fails the step.

## What this app does not hold

- **APNs.** There is no iOS target. Apple push keys are not used.
- **FCM server key or service account.** Those belong to the backend that sends messages. They do not go in the app repo, the APK, or GitHub Actions for this client.
- **A Firebase project.** Nobody has created one in this repo.

The API contract still says the server speaks web push, not FCM. `AppPushService` stays a no-op until that changes.

## Emulator workflow

`.github/workflows/android-notifications-emulator.yml` (`Android notification emulator`) runs on `workflow_dispatch` and nightly at 03:00 UTC. It does not run on pull requests.

`workflow_dispatch` becomes available once this file is on `main`. Until then GitHub rejects a dispatch of a workflow that exists only on a branch. The nightly schedule is 03:00 UTC.

Matrix: API 29, 33, and 34, `google_apis` / `x86_64`, KVM, AVD cache. Debug builds pass `USE_FAKE_API=true`.

The integration test does not call a permission API and does not use `NotificationPermissionService`. `tool/android_notification_emulator_test.sh` installs the debug APK, then drives the case with adb before `flutter test`:

- API 29: `NOTIF_CASE=implicit`. No grant. `areNotificationsEnabled` is true, the collections channel is present (Arabic name, high importance, badge on), and a probe alert is posted.
- API 33 and 34: `adb shell pm revoke` plus `appops set … POST_NOTIFICATION deny`, then `NOTIF_CASE=denied` (`areNotificationsEnabled` is false and nothing is posted). Then `pm grant` plus `appops set … POST_NOTIFICATION allow`, then `NOTIF_CASE=granted` (enabled is true, the same channel is still high importance with the badge flag, and a probe alert is posted).

After the file is on `main`, dispatch it against a branch:

```bash
gh workflow run android-notifications-emulator.yml --ref <branch>
```

## Decisions Ali still has to make

1. **Who owns the Firebase project** (create it, billing, who has IAM). This repo does not.
2. **Staging and production Firebase apps.** Separate `google-services.json` files, or one shared project. The secret names above are the split; CI reads only `GOOGLE_SERVICES_JSON_BASE64`.
3. **Final application id.** `google-services.json` is bound to `package_name`. It must match `com.example.vib_abdo_company_mobile` until Ali changes the id. A new id needs a new Firebase Android app and a new file. This change does not pick the id.
4. **Whether FCM is in scope.** The server contract is still web push. Turning FCM on means adding the Messaging SDK and a backend sender. The Gradle hook and the manifest meta-data are the only client pieces in place.
5. **Where the service account lives.** On the backend. Not in this app.
6. **Channel importance and extra channels.** One high-importance channel covers general and collections alerts. A quieter channel is a product choice.
7. **Scheduled local reminders.** Not built. Boot and exact-alarm permissions stay off until someone asks for them.
8. **Numeric badges on vendor launchers.** The channel badge is on. A badge-count plugin is not, because unsupported launchers crash.
9. **When to show the permission prompt.** Not this change. `NotificationPermissionService` owns the request. Whether that runs on the first frame, after sign-in, or later is still a product choice.
